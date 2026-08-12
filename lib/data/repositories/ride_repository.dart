import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/error_mapper.dart';
import '../../core/utils/date_x.dart';
import '../models/enums.dart';
import '../models/ride.dart';
import '../models/ride_filter.dart';
import '../models/ride_status.dart';
import '../models/ride_status_event.dart';

/// Reads and writes rides for the admin side, always through the `admin_rides`
/// view (never the base table — that grant is revoked). Writes go to the base
/// `rides` table, gated by the admin RLS policies.
class RideRepository {
  RideRepository(this._client);

  final SupabaseClient _client;

  /// Fetch the rides visible in a filter window, newest pickup last (calendar
  /// order). Filtering is pushed to PostgREST so we never over-fetch the shared
  /// pool.
  Future<List<Ride>> fetchRides(RideFilter filter) =>
      ErrorMapper.guard(() async {
        var query = _client
            .from('admin_rides')
            .select()
            .gte('pickup_at', filter.range.startIso)
            .lt('pickup_at', filter.range.endIso);

        if (filter.driverId != null) {
          query = query.eq('assigned_driver_id', filter.driverId!);
        }
        if (filter.statuses.isNotEmpty) {
          query = query.inFilter(
            'status',
            filter.statuses.map((s) => s.wire).toList(),
          );
        }
        final search = filter.search.trim();
        if (search.isNotEmpty) {
          // Match customer name, reference, or addresses.
          final term = '%$search%';
          query = query.or(
            'customer_name.ilike.$term,'
            'reference.ilike.$term,'
            'pickup_address.ilike.$term,'
            'dropoff_address.ilike.$term',
          );
        }

        final rows = await query.order('pickup_at');
        return rows.map(Ride.fromMap).toList();
      });

  /// The rides currently in flight, for the live map: a driver is assigned and
  /// the ride has not closed. Ordered by pickup time so the accompanying list
  /// reads next-up first. Small by nature (a fleet's worth), so unbounded.
  Future<List<Ride>> fetchActiveRides() => ErrorMapper.guard(() async {
        final rows = await _client
            .from('admin_rides')
            .select()
            .inFilter('status', const [
              'assigned',
              'en_route',
              'arrived',
              'in_progress',
            ])
            .order('pickup_at');
        return rows.map(Ride.fromMap).toList();
      });

  /// A single ride by id.
  Future<Ride> fetchRide(String rideId) => ErrorMapper.guard(() async {
        final row = await _client
            .from('admin_rides')
            .select()
            .eq('id', rideId)
            .maybeSingle();
        if (row == null) {
          throw const _NotFound();
        }
        return Ride.fromMap(row);
      });

  /// The audit timeline for a ride, with actor names joined in, newest first.
  Future<List<RideStatusEvent>> fetchTimeline(String rideId) =>
      ErrorMapper.guard(() async {
        final rows = await _client
            .from('ride_status_events')
            .select('*, actor:profiles!ride_status_events_actor_id_fkey(full_name)')
            .eq('ride_id', rideId)
            .order('created_at', ascending: false)
            .order('id', ascending: false);
        return rows.map(RideStatusEvent.fromMap).toList();
      });

  /// Today's dashboard counts, computed in one round trip each. Kept as three
  /// small head-count queries rather than pulling rows.
  Future<DashboardStats> fetchTodayStats() => ErrorMapper.guard(() async {
        final now = DateTime.now();
        final start = now.dayStart.toUtc().toIso8601String();
        final end = now.dayEnd.toUtc().toIso8601String();

        final todayRows = await _client
            .from('admin_rides')
            .select('status')
            .gte('pickup_at', start)
            .lte('pickup_at', end);

        final onDuty = await _client
            .from('driver_profiles')
            .select('id')
            .eq('approval_status', 'approved')
            .eq('is_on_duty', true)
            .count(CountOption.exact);

        final unassignedAll = await _client
            .from('admin_rides')
            .select('id')
            .eq('status', 'unassigned')
            .count(CountOption.exact);

        var todayUnassigned = 0;
        var todayInProgress = 0;
        for (final r in todayRows) {
          final s = RideStatus.fromWire(r['status'] as String);
          if (s == RideStatus.unassigned) todayUnassigned++;
          if (s.isLive) todayInProgress++;
        }

        return DashboardStats(
          ridesToday: todayRows.length,
          unassignedToday: todayUnassigned,
          unassignedTotal: unassignedAll.count,
          inProgress: todayInProgress,
          driversOnDuty: onDuty.count,
        );
      });

  /// Create a ride. Source/created admin default to the caller; the audit
  /// trigger records the creation.
  Future<Ride> createRide(RideInput input, {required String adminId}) =>
      ErrorMapper.guard(() async {
        final row = await _client
            .from('rides')
            .insert({
              ...input.toInsert(),
              'source_admin_id': adminId,
              'created_by': adminId,
            })
            .select('id')
            .single();
        return fetchRide(row['id'] as String);
      });

  /// Edit any ride's fields, before or after assignment. The audit trigger logs
  /// the field-level diff.
  Future<Ride> updateRide(String rideId, RideInput input) =>
      ErrorMapper.guard(() async {
        await _client.from('rides').update(input.toUpdate()).eq('id', rideId);
        return fetchRide(rideId);
      });

  /// Realtime signal that *some* ride changed (admin only). Emits `null` on any
  /// insert/update/delete so the caller re-fetches through the `admin_rides`
  /// view — we deliberately don't reconstruct view rows from the raw payload,
  /// because the projection has joins the change payload lacks (and, for
  /// drivers, would leak source_admin_id — which is why only admins use this).
  Stream<void> ridesChanges() {
    final controller = StreamController<void>.broadcast();
    final channel = _client.channel('admin-rides-changes');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rides',
          callback: (_) {
            if (!controller.isClosed) controller.add(null);
          },
        )
        .subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }
}

class _NotFound implements Exception {
  const _NotFound();
}

/// Aggregate counts for the dashboard's stat callouts.
class DashboardStats {
  const DashboardStats({
    required this.ridesToday,
    required this.unassignedToday,
    required this.unassignedTotal,
    required this.inProgress,
    required this.driversOnDuty,
  });

  final int ridesToday;
  final int unassignedToday;
  final int unassignedTotal;
  final int inProgress;
  final int driversOnDuty;
}

/// The write payload for a ride, shared by create and edit (same field set as
/// the requirements' §2.2). Null-safe: only set columns are sent on update.
class RideInput {
  const RideInput({
    required this.pickupAt,
    required this.customerName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.passengers,
    required this.luggage,
    this.customerPhone,
    this.fareAmount,
    this.vehicleType,
    this.flightNumber,
    this.notes,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
  });

  final DateTime pickupAt;
  final String customerName;
  final String? customerPhone;
  final String pickupAddress;
  final String dropoffAddress;
  final int passengers;
  final int luggage;
  final num? fareAmount;
  final VehicleType? vehicleType;
  final String? flightNumber;
  final String? notes;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;

  Map<String, dynamic> _common() => {
        'pickup_at': pickupAt.toUtc().toIso8601String(),
        'customer_name': customerName.trim(),
        'customer_phone': customerPhone?.trim(),
        'pickup_address': pickupAddress.trim(),
        'dropoff_address': dropoffAddress.trim(),
        'passengers': passengers,
        'luggage': luggage,
        'fare_amount': fareAmount,
        'vehicle_type': vehicleType?.wire,
        'flight_number': flightNumber?.trim().isEmpty ?? true
            ? null
            : flightNumber!.trim(),
        'notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
      };

  Map<String, dynamic> toInsert() => _common();
  Map<String, dynamic> toUpdate() => _common();
}
