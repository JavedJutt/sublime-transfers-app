import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/app_exception.dart';
import '../../core/error/error_mapper.dart';
import '../../core/utils/date_x.dart';
import '../../services/location/location_capture.dart';
import '../models/ride.dart';
import '../models/ride_status.dart';
import '../sources/local/outbox.dart';

/// The driver's own data + actions. Reads go through the `driver_rides` view
/// (which omits admin-only columns); writes go through the outbox then the
/// security-definer RPCs, so an action survives being offline and a replay is a
/// server-side no-op.
class DriverRideRepository {
  DriverRideRepository(this._client, this._outbox);

  final SupabaseClient _client;
  final Outbox _outbox;
  static const _uuid = Uuid();

  String? get _driverId => _client.auth.currentUser?.id;

  // ------------------------------------------------------------------ reads
  /// The driver's assigned rides for a given day.
  Future<List<Ride>> ridesForDay(DateTime day) => ErrorMapper.guard(() async {
        final id = _driverId;
        if (id == null) return [];
        final rows = await _client
            .from('driver_rides')
            .select()
            .eq('assigned_driver_id', id)
            .gte('pickup_at', day.dayStart.toUtc().toIso8601String())
            .lte('pickup_at', day.dayEnd.toUtc().toIso8601String())
            .order('pickup_at');
        return rows.map(Ride.fromMap).toList();
      });

  /// A single ride by id, from the driver view. Null if it isn't visible to
  /// this driver (not theirs and not an open broadcast).
  Future<Ride?> rideById(String id) => ErrorMapper.guard(() async {
        final rows =
            await _client.from('driver_rides').select().eq('id', id).limit(1);
        return rows.isEmpty ? null : Ride.fromMap(rows.first);
      });

  /// The driver's active ride, if any (the one currently in a live status).
  Future<Ride?> activeRide() => ErrorMapper.guard(() async {
        final id = _driverId;
        if (id == null) return null;
        final rows = await _client
            .from('driver_rides')
            .select()
            .eq('assigned_driver_id', id)
            .inFilter('status', ['assigned', 'en_route', 'arrived', 'in_progress'])
            .order('pickup_at')
            .limit(1);
        return rows.isEmpty ? null : Ride.fromMap(rows.first);
      });

  /// Closed rides the driver has finished — completed, cancelled, no-show —
  /// most recent first. The record of their work.
  Future<List<Ride>> history({int limit = 50}) => ErrorMapper.guard(() async {
        final id = _driverId;
        if (id == null) return [];
        final rows = await _client
            .from('driver_rides')
            .select()
            .eq('assigned_driver_id', id)
            .inFilter('status', ['completed', 'cancelled', 'no_show'])
            .order('pickup_at', ascending: false)
            .limit(limit);
        return rows.map(Ride.fromMap).toList();
      });

  /// Direct offers awaiting this driver's response, plus open broadcasts.
  Future<DriverOffers> offers() => ErrorMapper.guard(() async {
        final id = _driverId;
        if (id == null) return const DriverOffers(direct: [], broadcast: []);

        // Direct: rides offered to me, currently 'offered'.
        final directOfferRows = await _client
            .from('ride_offers')
            .select('ride_id')
            .eq('driver_id', id)
            .eq('status', 'pending')
            .eq('method', 'direct');
        final directIds =
            directOfferRows.map((r) => r['ride_id'] as String).toList();

        final direct = directIds.isEmpty
            ? <Ride>[]
            : (await _client
                    .from('driver_rides')
                    .select()
                    .inFilter('id', directIds)
                    .order('pickup_at'))
                .map(Ride.fromMap)
                .toList();

        // Broadcast: open to all, not yet assigned to me.
        final broadcast = (await _client
                .from('driver_rides')
                .select()
                .eq('broadcast_open', true)
                .order('pickup_at'))
            .map(Ride.fromMap)
            .toList();

        return DriverOffers(direct: direct, broadcast: broadcast);
      });

  Stream<List<Ride>> watchDay(DateTime day) {
    final id = _driverId;
    if (id == null) return const Stream.empty();
    return _client
        .from('driver_rides')
        .stream(primaryKey: ['id'])
        .eq('assigned_driver_id', id)
        .order('pickup_at')
        .map((rows) => rows
            .map(Ride.fromMap)
            .where((r) => r.pickupAt.isSameDay(day))
            .toList());
  }

  // ----------------------------------------------------------------- writes
  /// Advance a ride's status. Location is captured by the caller and passed in;
  /// it lands in the same transaction as the transition. Writes to the outbox
  /// first, then attempts the RPC; on network failure the item stays queued.
  Future<OutboxResult> advanceStatus({
    required String rideId,
    required RideStatus to,
    required LocationCapture location,
  }) =>
      _queueAndSend(
        rpc: 'advance_ride_status',
        payload: {
          'p_ride_id': rideId,
          'p_to': to.wire,
          ..._locationParams(location),
        },
      );

  Future<OutboxResult> respondToOffer({
    required String rideId,
    required bool accept,
    String? reason,
    LocationCapture? location,
  }) =>
      _queueAndSend(
        rpc: 'respond_to_offer',
        payload: {
          'p_ride_id': rideId,
          'p_accept': accept,
          'p_reason': reason,
          if (location != null) ..._locationParams(location),
        },
      );

  Future<OutboxResult> claimBroadcast({
    required String rideId,
    LocationCapture? location,
  }) =>
      _queueAndSend(
        rpc: 'claim_broadcast_ride',
        payload: {
          'p_ride_id': rideId,
          if (location != null) ..._locationParams(location),
        },
      );

  /// The core of offline resilience: enqueue with a fresh client_event_id, then
  /// try to send. If the send fails on the network, the item remains for the
  /// sync service; if it fails on a business rule (already claimed, invalid
  /// transition), we surface that and drop the item — retrying won't help.
  Future<OutboxResult> _queueAndSend({
    required String rpc,
    required Map<String, dynamic> payload,
  }) async {
    final clientEventId = _uuid.v4();
    final fullPayload = {...payload, 'p_client_event_id': clientEventId};
    final rowId = await _outbox.enqueue(
      clientEventId: clientEventId,
      rpc: rpc,
      payload: fullPayload,
    );

    try {
      await _client.rpc(rpc, params: fullPayload);
      await _outbox.remove(rowId);
      return const OutboxResult.sent();
    } catch (error, stack) {
      final mapped = ErrorMapper.map(error, stack);
      if (mapped is NetworkFailure) {
        // Keep it queued for the sync service to drain later.
        await _outbox.bumpAttempt(rowId, mapped.message);
        return const OutboxResult.queued();
      }
      // A business-rule rejection won't succeed on retry — drop it and report.
      await _outbox.remove(rowId);
      return OutboxResult.failed(mapped);
    }
  }

  Map<String, dynamic> _locationParams(LocationCapture capture) {
    if (capture is LocationFix) {
      return {
        'p_lat': capture.lat,
        'p_lng': capture.lng,
        'p_accuracy_m': capture.accuracyM,
        'p_captured_at': capture.capturedAt.toUtc().toIso8601String(),
      };
    }
    // Unavailable: send nulls; the RPC records location_unavailable.
    return {
      'p_lat': null,
      'p_lng': null,
      'p_accuracy_m': null,
      'p_captured_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

/// A driver's pending work.
class DriverOffers {
  const DriverOffers({required this.direct, required this.broadcast});

  final List<Ride> direct;
  final List<Ride> broadcast;

  bool get isEmpty => direct.isEmpty && broadcast.isEmpty;
  int get total => direct.length + broadcast.length;
}

/// The result of an outboxed action.
sealed class OutboxResult {
  const OutboxResult();

  /// Delivered to the server successfully.
  const factory OutboxResult.sent() = OutboxSent;

  /// Couldn't reach the server; queued for later. The UI shows an optimistic
  /// state and a "will sync" note.
  const factory OutboxResult.queued() = OutboxQueued;

  /// The server rejected it on a business rule (won't retry).
  const factory OutboxResult.failed(AppException error) = OutboxFailed;
}

class OutboxSent extends OutboxResult {
  const OutboxSent();
}

class OutboxQueued extends OutboxResult {
  const OutboxQueued();
}

class OutboxFailed extends OutboxResult {
  const OutboxFailed(this.error);
  final AppException error;
}
