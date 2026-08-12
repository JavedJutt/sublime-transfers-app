import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sublime_transfers/data/models/ride_status.dart';
import 'package:sublime_transfers/data/sources/local/outbox.dart';
import 'package:sublime_transfers/services/location/location_capture.dart';

void main() {
  group('driver status transitions', () {
    test('advance the full happy path one step at a time', () {
      expect(RideStatus.assigned.driverNext, RideStatus.enRoute);
      expect(RideStatus.enRoute.driverNext, RideStatus.arrived);
      expect(RideStatus.arrived.driverNext, RideStatus.inProgress);
      expect(RideStatus.inProgress.driverNext, RideStatus.completed);
    });

    test('completed and other terminal states have no next step', () {
      expect(RideStatus.completed.driverNext, isNull);
      expect(RideStatus.cancelled.driverNext, isNull);
      expect(RideStatus.noShow.driverNext, isNull);
      // A driver never advances an offer or an unassigned ride from here.
      expect(RideStatus.offered.driverNext, isNull);
      expect(RideStatus.unassigned.driverNext, isNull);
    });

    test('each live/assigned status carries a button verb, terminals do not',
        () {
      expect(RideStatus.assigned.advanceLabel, isNotNull);
      expect(RideStatus.enRoute.advanceLabel, isNotNull);
      expect(RideStatus.arrived.advanceLabel, isNotNull);
      expect(RideStatus.inProgress.advanceLabel, isNotNull);
      expect(RideStatus.completed.advanceLabel, isNull);
    });

    test('isActionableByDriver spans assigned through in-progress only', () {
      expect(RideStatus.assigned.isActionableByDriver, isTrue);
      expect(RideStatus.enRoute.isActionableByDriver, isTrue);
      expect(RideStatus.inProgress.isActionableByDriver, isTrue);
      expect(RideStatus.completed.isActionableByDriver, isFalse);
      expect(RideStatus.offered.isActionableByDriver, isFalse);
    });
  });

  group('location capture reasons', () {
    test('permanently-denied is the only reason that needs a settings trip', () {
      expect(LocationUnavailableReason.permanentlyDenied.needsSettings, isTrue);
      expect(LocationUnavailableReason.denied.needsSettings, isFalse);
      expect(LocationUnavailableReason.timeout.needsSettings, isFalse);
      expect(LocationUnavailableReason.serviceDisabled.needsSettings, isFalse);
    });

    test('every reason has a user-facing message', () {
      for (final reason in LocationUnavailableReason.values) {
        expect(reason.message, isNotEmpty);
      }
    });
  });

  group('offline outbox', () {
    late Outbox outbox;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      outbox = await Outbox.open(path: inMemoryDatabasePath);
    });

    tearDown(() async {
      await outbox.close();
    });

    test('drains oldest-first (FIFO) so a ride cannot advance out of order',
        () async {
      await outbox.enqueue(
        clientEventId: 'e1',
        rpc: 'advance_ride_status',
        payload: {'p_to': 'en_route'},
      );
      await outbox.enqueue(
        clientEventId: 'e2',
        rpc: 'advance_ride_status',
        payload: {'p_to': 'arrived'},
      );

      final pending = await outbox.pending();
      expect(pending.map((i) => i.clientEventId), ['e1', 'e2']);
      expect(await outbox.count(), 2);
    });

    test('a delivered item is removed and stops draining', () async {
      final id = await outbox.enqueue(
        clientEventId: 'e1',
        rpc: 'respond_to_offer',
        payload: {'p_accept': true},
      );
      await outbox.remove(id);
      expect(await outbox.count(), 0);
      expect(await outbox.pending(), isEmpty);
    });

    test('a network retry bumps the attempt count and keeps the item', () async {
      final id = await outbox.enqueue(
        clientEventId: 'e1',
        rpc: 'claim_broadcast_ride',
        payload: {'p_ride_id': 'r1'},
      );
      await outbox.bumpAttempt(id, 'offline');

      final item = (await outbox.pending()).single;
      expect(item.attempts, 1);
      expect(item.lastError, 'offline');
    });

    test('the client_event_id is unique, so a replay cannot double-insert',
        () async {
      await outbox.enqueue(
        clientEventId: 'dup',
        rpc: 'advance_ride_status',
        payload: {'p_to': 'completed'},
      );
      expect(
        () => outbox.enqueue(
          clientEventId: 'dup',
          rpc: 'advance_ride_status',
          payload: {'p_to': 'completed'},
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
