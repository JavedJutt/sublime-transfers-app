import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sublime_transfers/core/design/app_theme.dart';
import 'package:sublime_transfers/data/models/enums.dart';
import 'package:sublime_transfers/data/models/ride.dart';
import 'package:sublime_transfers/data/models/ride_status.dart';
import 'package:sublime_transfers/data/models/ride_status_event.dart';
import 'package:sublime_transfers/data/repositories/driver_repository.dart';
import 'package:sublime_transfers/data/repositories/ride_repository.dart';
import 'package:sublime_transfers/features/admin/presentation/dashboard_screen.dart';
import 'package:sublime_transfers/features/admin/presentation/ride_detail_screen.dart';
import 'package:sublime_transfers/features/admin/presentation/ride_list_screen.dart';
import 'package:sublime_transfers/features/admin/widgets/ride/ride_card.dart';
import 'package:sublime_transfers/providers/driver_providers.dart';
import 'package:sublime_transfers/providers/ride_providers.dart';
import 'package:sublime_transfers/shared/widgets/display/stat_callout.dart';
import 'package:sublime_transfers/shared/widgets/feedback/empty_state.dart';

Ride _ride({
  String id = 'r1',
  String reference = 'ST-TEST01',
  RideStatus status = RideStatus.unassigned,
  String customer = 'Amelia Hart',
  String? driverName,
  DateTime? pickupAt,
}) =>
    Ride(
      id: id,
      reference: reference,
      pickupAt: pickupAt ?? DateTime.now().add(const Duration(hours: 2)),
      customerName: customer,
      pickupAddress: 'Heathrow T5',
      dropoffAddress: 'Mayfair',
      passengers: 2,
      luggage: 3,
      status: status,
      fareAmount: 120,
      vehicleType: VehicleType.executive,
      flightNumber: 'BA2551',
      driverName: driverName,
      assignedDriverId: driverName == null ? null : 'd1',
      sourceAdminName: 'Ava Whitfield',
    );

const _stats = DashboardStats(
  ridesToday: 12,
  unassignedToday: 3,
  unassignedTotal: 5,
  inProgress: 2,
  driversOnDuty: 4,
);

/// Wraps a screen in a router + themed MaterialApp. Callers wrap the result in
/// a ProviderScope with their overrides (Riverpod 3 doesn't export the
/// `Override` type name, so the overrides list is built at the call site).
Widget _appFor(Widget screen) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, _) => screen)],
  );
  return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
}

Future<void> _pump(
  WidgetTester tester,
  Widget scope, {
  double width = 1440,
  double height = 1600,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(scope);
  // Several pumps: screens whose providers chain (detail resolves, which then
  // builds a child that starts a second future) need more than one frame.
  // pumpAndSettle can't be used because the loading skeletons shimmer forever.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  group('DashboardScreen', () {
    testWidgets('renders stats and today\'s rides', (tester) async {
      await _pump(
        tester,
        ProviderScope(
          overrides: [
            dashboardStatsProvider.overrideWith((ref) async => _stats),
            todayRidesProvider.overrideWith((ref) async => [
                  _ride(status: RideStatus.assigned, driverName: 'Marcus Bell'),
                  _ride(id: 'r2', reference: 'ST-TEST02'),
                ]),
          ],
          child: _appFor(const DashboardScreen()),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(StatCallout), findsNWidgets(4));
      expect(find.text('12'), findsOneWidget); // rides today
      expect(find.byType(RideCard), findsNWidgets(2));
    });

    testWidgets('shows the empty state when there are no rides today',
        (tester) async {
      await _pump(
        tester,
        ProviderScope(
          overrides: [
            dashboardStatsProvider.overrideWith((ref) async => _stats),
            todayRidesProvider.overrideWith((ref) async => <Ride>[]),
          ],
          child: _appFor(const DashboardScreen()),
        ),
      );
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No rides scheduled today'), findsOneWidget);
    });

    testWidgets('renders on a phone width without overflow', (tester) async {
      await _pump(
        tester,
        ProviderScope(
          overrides: [
            dashboardStatsProvider.overrideWith((ref) async => _stats),
            todayRidesProvider.overrideWith((ref) async => [_ride()]),
          ],
          child: _appFor(const DashboardScreen()),
        ),
        width: 390,
        height: 1800,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('RideListScreen', () {
    testWidgets('groups rides by day and renders cards', (tester) async {
      await _pump(
        tester,
        ProviderScope(
          overrides: [
            approvedDriversProvider
                .overrideWith((ref) async => <DriverListItem>[]),
            rideListProvider.overrideWith((ref) async => [
                  _ride(),
                  _ride(
                      id: 'r2',
                      status: RideStatus.completed,
                      driverName: 'Priya Raman'),
                ]),
          ],
          child: _appFor(const RideListScreen()),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(RideCard), findsNWidgets(2));
    });
  });

  group('RideDetailScreen', () {
    testWidgets('renders every field, admin source, and the timeline',
        (tester) async {
      final ride = _ride(status: RideStatus.assigned, driverName: 'Marcus Bell');
      final events = [
        RideStatusEvent(
          id: 2,
          rideId: 'r1',
          toStatus: RideStatus.assigned,
          action: 'assigned',
          createdAt: DateTime.now(),
          actorRole: null,
          metadata: const {'rpc': true},
        ),
        RideStatusEvent(
          id: 1,
          rideId: 'r1',
          toStatus: RideStatus.unassigned,
          action: 'created',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          metadata: const {'trigger': true},
        ),
      ];

      await _pump(
        tester,
        ProviderScope(
          overrides: [
            rideDetailProvider('r1').overrideWith((ref) async => ride),
            rideTimelineProvider('r1').overrideWith((ref) async => events),
          ],
          child: _appFor(const RideDetailScreen(rideId: 'r1')),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Amelia Hart'), findsOneWidget);
      // Admin-only source metadata is shown in the admin app.
      expect(find.text('Ava Whitfield'), findsOneWidget);
      // Driver + flight + fare are present.
      expect(find.text('Marcus Bell'), findsWidgets);
      expect(find.text('BA2551'), findsOneWidget);
      // Timeline rendered.
      expect(find.text('Ride created'), findsOneWidget);
    });
  });
}
