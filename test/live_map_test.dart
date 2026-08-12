import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sublime_transfers/core/design/app_theme.dart';
import 'package:sublime_transfers/data/models/ride.dart';
import 'package:sublime_transfers/data/models/ride_status.dart';
import 'package:sublime_transfers/features/admin/presentation/live_map_screen.dart';
import 'package:sublime_transfers/features/admin/widgets/map/active_ride_list.dart';
import 'package:sublime_transfers/providers/map_providers.dart';
import 'package:sublime_transfers/services/location/driver_tracking_service.dart';
import 'package:sublime_transfers/services/location/location_capture.dart';
import 'package:sublime_transfers/services/location/location_service.dart';
import 'package:sublime_transfers/shared/widgets/feedback/empty_state.dart';

Ride _ride({
  String id = 'r1',
  RideStatus status = RideStatus.inProgress,
  String? driverName = 'Marcus Bell',
  double? driverLat = 51.5,
  double? driverLng = -0.12,
  DateTime? lastLocationAt,
}) =>
    Ride(
      id: id,
      reference: 'ST-100',
      pickupAt: DateTime(2026, 8, 1, 14),
      customerName: 'Ava Turner',
      pickupAddress: 'Heathrow T5',
      dropoffAddress: 'The Savoy',
      passengers: 2,
      luggage: 1,
      status: status,
      driverName: driverName,
      driverLastLat: driverLat,
      driverLastLng: driverLng,
      driverLastLocationAt: lastLocationAt,
    );

Widget _host(List<Ride> rides, {Widget? child}) => ProviderScope(
      overrides: [
        activeRidesProvider.overrideWith(() => _StubActiveRides(rides)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          initialLocation: '/admin/live',
          routes: [
            GoRoute(
              path: '/admin/live',
              builder: (_, _) => child ?? const LiveMapScreen(),
            ),
            GoRoute(
              path: '/admin/rides/:id',
              builder: (_, _) => const Scaffold(),
            ),
          ],
        ),
      ),
    );

class _StubActiveRides extends ActiveRides {
  _StubActiveRides(this.rides);
  final List<Ride> rides;
  @override
  Future<List<Ride>> build() async => rides;
}

/// A LocationService whose position stream we drive by hand.
class _FakeLocationService implements LocationService {
  final _controller = StreamController<LocationFix>.broadcast();

  void emit(LocationFix fix) => _controller.add(fix);

  @override
  Stream<LocationFix> positionStream() => _controller.stream;

  @override
  Future<LocationCapture> captureForStatusChange() async =>
      const LocationUnavailable(LocationUnavailableReason.unknown);
  @override
  Future<LocationPermissionState> checkPermission() async =>
      LocationPermissionState.granted;
  @override
  Future<LocationPermissionState> requestPermission() async =>
      LocationPermissionState.granted;
  @override
  Future<bool> openSettings() async => true;
}

LocationFix _fix(double lat, double lng) => LocationFix(
      lat: lat,
      lng: lng,
      capturedAt: DateTime.now(),
    );

void main() {
  // No MAPS_API_KEY is set in the test environment, so LiveMapScreen renders
  // its list fallback — which is exactly the no-key path we want to prove works.

  group('LiveMapScreen (no maps key → list fallback)', () {
    testWidgets('renders the active rides as a list, never a blank map',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host([
        _ride(id: 'a', lastLocationAt: DateTime.now()),
        _ride(id: 'b', driverName: 'Priya Shah'),
      ]));
      await tester.pumpAndSettle();

      expect(find.byType(ActiveRideList), findsOneWidget);
      expect(find.text('Marcus Bell'), findsOneWidget);
      expect(find.text('Priya Shah'), findsOneWidget);
      // The fallback notice is present.
      expect(find.textContaining('Map view is unavailable'), findsOneWidget);
    });

    testWidgets('an empty fleet is an empty state, not an error',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host([]));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(ActiveRideList), findsNothing);
    });
  });

  group('ActiveRideList freshness', () {
    Widget listHost(List<Ride> rides) => _host(
          rides,
          child: Scaffold(
            body: ActiveRideList(rides: rides, onOpenRide: (_) {}),
          ),
        );

    testWidgets('a recent fix reads as Live', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(listHost([
        _ride(lastLocationAt: DateTime.now()),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('an old fix reads as "Last seen …"', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(listHost([
        _ride(
          lastLocationAt: DateTime.now().subtract(const Duration(minutes: 20)),
        ),
      ]));
      await tester.pumpAndSettle();
      expect(find.textContaining('Last seen'), findsOneWidget);
    });

    testWidgets('no fix at all reads as "No location yet"', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(listHost([
        _ride(driverLat: null, driverLng: null, lastLocationAt: null),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('No location yet'), findsOneWidget);
    });
  });

  group('DriverTrackingService throttling', () {
    test('rapid fixes collapse to one send within the interval', () async {
      final location = _FakeLocationService();
      final sent = <String>[];
      final service = DriverTrackingService(
        location,
        sender: (rideId, fix) async => sent.add(rideId),
      );

      await service.start('ride-x');
      // Three fixes in quick succession — the first is sent, the rest are
      // throttled (interval is 30s, far longer than this test runs).
      location
        ..emit(_fix(51.50, -0.12))
        ..emit(_fix(51.51, -0.12))
        ..emit(_fix(51.52, -0.12));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(sent.length, 1);
      expect(sent.single, 'ride-x');
      await service.stop();
    });

    test('stop halts tracking and clears the ride', () async {
      final location = _FakeLocationService();
      final service = DriverTrackingService(
        location,
        sender: (_, _) async {},
      );
      await service.start('ride-y');
      expect(service.isTracking, isTrue);
      expect(service.trackingRideId, 'ride-y');
      await service.stop();
      expect(service.isTracking, isFalse);
      expect(service.trackingRideId, isNull);
    });

    test('starting the same ride twice is a no-op', () async {
      final location = _FakeLocationService();
      final service = DriverTrackingService(location, sender: (_, _) async {});
      await service.start('ride-z');
      final first = service.isTracking;
      await service.start('ride-z');
      expect(first && service.isTracking, isTrue);
      expect(service.trackingRideId, 'ride-z');
      await service.stop();
    });
  });
}
