import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sublime_transfers/core/design/app_theme.dart';
import 'package:sublime_transfers/data/models/enums.dart';
import 'package:sublime_transfers/data/models/inbound_email.dart';
import 'package:sublime_transfers/features/admin/presentation/review_queue_screen.dart';
import 'package:sublime_transfers/features/admin/widgets/review/review_email_card.dart';
import 'package:sublime_transfers/providers/review_providers.dart';
import 'package:sublime_transfers/shared/widgets/feedback/empty_state.dart';

InboundEmail _email({
  String id = 'e1',
  ParseStatus status = ParseStatus.needsReview,
  String? parseError = 'missing_required_fields',
  Map<String, dynamic>? payload,
}) =>
    InboundEmail(
      id: id,
      parseStatus: status,
      createdAt: DateTime(2026, 7, 20, 9),
      subject: 'Airport transfer',
      fromAddress: 'guest@example.com',
      mailboxAddress: 'ops@sublimetransfers.test',
      parseError: parseError,
      confidence: 0.7,
      parsedPayload: payload,
    );

void main() {
  group('InboundEmail parsing', () {
    test('a ride-shaped payload yields a ParsedBooking', () {
      final e = _email(payload: {
        'pickup_at': '2026-08-01T13:30:00Z',
        'customer_name': 'Ava Turner',
        'pickup_address': 'Heathrow T5',
        'dropoff_address': 'The Savoy',
        'passengers': 2,
        'luggage': 3,
        'vehicle_type': 'executive',
      });
      final b = e.booking;
      expect(b, isNotNull);
      expect(b!.customerName, 'Ava Turner');
      expect(b.passengers, 2);
      expect(b.vehicleType, VehicleType.executive);
      expect(b.pickupAt, isNotNull);
    });

    test('a flag_for_review payload is not treated as a booking', () {
      final e = _email(payload: {
        'reason': 'not_a_booking',
        'summary': 'Marketing email',
        'partial': {'customer_name': null},
      });
      expect(e.booking, isNull);
    });

    test('toPayload round-trips the edited fields to snake_case', () {
      final booking = ParsedBooking(
        pickupAt: DateTime.utc(2026, 8, 1, 13, 30),
        customerName: 'Ava',
        pickupAddress: 'A',
        dropoffAddress: 'B',
        passengers: 3,
        luggage: 1,
        vehicleType: VehicleType.mpv,
      );
      final p = booking.toPayload();
      expect(p['customer_name'], 'Ava');
      expect(p['passengers'], 3);
      expect(p['vehicle_type'], 'mpv');
      expect(p['pickup_at'], '2026-08-01T13:30:00.000Z');
    });
  });

  group('reviewReasonLabel', () {
    test('humanises known reason codes', () {
      expect(reviewReasonLabel('not_a_booking'), 'Not a booking');
      expect(reviewReasonLabel('missing_required_fields'), 'Missing details');
      expect(reviewReasonLabel('parser_unconfigured'), 'Parser not configured');
      expect(reviewReasonLabel('parse_failed: openai 500'), 'Parser error');
      expect(reviewReasonLabel(null), 'Needs a look');
    });
  });

  group('ReviewQueueScreen', () {
    Widget host(List<InboundEmail> pending) => ProviderScope(
          overrides: [
            reviewQueueProvider.overrideWith((ref) async => pending),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: GoRouter(
              initialLocation: '/admin/review',
              routes: [
                GoRoute(
                  path: '/admin/review',
                  builder: (_, _) => const ReviewQueueScreen(),
                ),
                GoRoute(
                  path: '/admin/review/:id',
                  builder: (_, _) => const Scaffold(),
                ),
              ],
            ),
          ),
        );

    testWidgets('lists emails awaiting review', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host([
        _email(id: 'a'),
        _email(id: 'b', parseError: 'ambiguous'),
      ]));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewEmailCard), findsNWidgets(2));
    });

    testWidgets('an empty queue is good news, not an error', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host([]));
      await tester.pumpAndSettle();
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(ReviewEmailCard), findsNothing);
    });
  });
}
