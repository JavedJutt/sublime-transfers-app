import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sublime_transfers/core/design/app_theme.dart';
import 'package:sublime_transfers/data/models/ride.dart';
import 'package:sublime_transfers/data/models/ride_status.dart';
import 'package:sublime_transfers/data/repositories/driver_ride_repository.dart';
import 'package:sublime_transfers/features/driver/presentation/driver_offers_screen.dart';
import 'package:sublime_transfers/features/driver/widgets/broadcast_card.dart';
import 'package:sublime_transfers/features/driver/widgets/location_permission_banner.dart';
import 'package:sublime_transfers/features/driver/widgets/offer_card.dart';
import 'package:sublime_transfers/features/driver/widgets/status_advance_button.dart';
import 'package:sublime_transfers/providers/driver_app_providers.dart';
import 'package:sublime_transfers/providers/notification_providers.dart';
import 'package:sublime_transfers/services/location/location_service.dart';
import 'package:sublime_transfers/shared/widgets/feedback/empty_state.dart';

Ride _ride({
  String id = 'r1',
  RideStatus status = RideStatus.assigned,
  String customer = 'Ava Turner',
}) =>
    Ride(
      id: id,
      reference: 'ST-1001',
      pickupAt: DateTime.now().add(const Duration(hours: 1)),
      customerName: customer,
      pickupAddress: 'Heathrow T5',
      dropoffAddress: 'The Savoy, London',
      passengers: 2,
      luggage: 3,
      status: status,
      fareAmount: 120,
    );

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('StatusAdvanceButton', () {
    testWidgets('speaks the verb for the current status', (tester) async {
      await tester.pumpWidget(_host(
        StatusAdvanceButton(status: RideStatus.assigned, onAdvance: () {}),
      ));
      expect(find.text('Start driving'), findsOneWidget);
    });

    testWidgets('fires onAdvance when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_host(
        StatusAdvanceButton(
          status: RideStatus.arrived,
          onAdvance: () => tapped = true,
        ),
      ));
      await tester.tap(find.text('Start ride'));
      expect(tapped, isTrue);
    });

    testWidgets('a completed ride shows a done note, not a button',
        (tester) async {
      await tester.pumpWidget(_host(
        StatusAdvanceButton(status: RideStatus.completed, onAdvance: () {}),
      ));
      expect(find.textContaining('completed'), findsOneWidget);
      expect(find.text('Complete ride'), findsNothing);
    });
  });

  group('LocationPermissionBanner', () {
    testWidgets('granted permission renders nothing', (tester) async {
      await tester.pumpWidget(_host(
        LocationPermissionBanner(
          state: LocationPermissionState.granted,
          onEnable: () {},
          onOpenSettings: () {},
        ),
      ));
      expect(find.byType(SizedBox), findsWidgets); // renders an empty box only
      expect(find.textContaining('location'), findsNothing);
    });

    testWidgets('denied offers an in-app enable, not a settings trip',
        (tester) async {
      var enabled = false;
      await tester.pumpWidget(_host(
        LocationPermissionBanner(
          state: LocationPermissionState.denied,
          onEnable: () => enabled = true,
          onOpenSettings: () {},
        ),
      ));
      expect(find.text('Enable location'), findsOneWidget);
      await tester.tap(find.text('Enable location'));
      expect(enabled, isTrue);
    });

    testWidgets('permanently denied sends the driver to Settings',
        (tester) async {
      var opened = false;
      await tester.pumpWidget(_host(
        LocationPermissionBanner(
          state: LocationPermissionState.permanentlyDenied,
          onEnable: () {},
          onOpenSettings: () => opened = true,
        ),
      ));
      expect(find.text('Open Settings'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      expect(opened, isTrue);
    });
  });

  group('offer & broadcast cards', () {
    testWidgets('OfferCard accept and decline reach their callbacks',
        (tester) async {
      var accepted = false;
      var declined = false;
      await tester.pumpWidget(_host(SizedBox(
        width: 360,
        child: OfferCard(
          ride: _ride(),
          onTap: () {},
          onAccept: () => accepted = true,
          onDecline: () => declined = true,
        ),
      )));
      await tester.tap(find.text('Accept'));
      await tester.tap(find.text('Decline'));
      expect(accepted, isTrue);
      expect(declined, isTrue);
    });

    testWidgets('BroadcastCard claim reaches its callback', (tester) async {
      var claimed = false;
      await tester.pumpWidget(_host(SizedBox(
        width: 360,
        child: BroadcastCard(
          ride: _ride(status: RideStatus.unassigned),
          onTap: () {},
          onClaim: () => claimed = true,
        ),
      )));
      await tester.tap(find.text('Claim ride'));
      expect(claimed, isTrue);
    });
  });

  group('DriverOffersScreen', () {
    Widget screen(DriverOffers offers) => ProviderScope(
          overrides: [
            driverOffersProvider.overrideWith((ref) async => offers),
            notificationsProvider.overrideWith((ref) => const Stream.empty()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: GoRouter(
              initialLocation: '/driver/offers',
              routes: [
                GoRoute(
                  path: '/driver/offers',
                  builder: (_, _) => const DriverOffersScreen(),
                ),
                GoRoute(
                  path: '/driver/rides/:id',
                  builder: (_, _) => const Scaffold(),
                ),
              ],
            ),
          ),
        );

    testWidgets('shows both a direct offer and a broadcast', (tester) async {
      await tester.pumpWidget(screen(DriverOffers(
        direct: [_ride(id: 'a', customer: 'Direct Guest')],
        broadcast: [_ride(id: 'b', customer: 'Pool Guest')],
      )));
      await tester.pumpAndSettle();
      expect(find.byType(OfferCard), findsOneWidget);
      expect(find.byType(BroadcastCard), findsOneWidget);
    });

    testWidgets('no offers shows a reassuring empty state, not a blank screen',
        (tester) async {
      await tester.pumpWidget(
          screen(const DriverOffers(direct: [], broadcast: [])));
      await tester.pumpAndSettle();
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(OfferCard), findsNothing);
    });
  });
}
