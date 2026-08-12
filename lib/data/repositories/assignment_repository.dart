import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/error_mapper.dart';

/// Admin assignment actions. Each is a thin wrapper over a security-definer RPC
/// (already built and concurrency-tested in the schema), so the transition
/// rules and audit logging live in one place — the database — and can't be
/// bypassed from the client.
class AssignmentRepository {
  AssignmentRepository(this._client);

  final SupabaseClient _client;

  /// Direct offer to one driver. The ride moves to `offered`; the driver
  /// accepts or declines.
  Future<void> assignDirect({
    required String rideId,
    required String driverId,
  }) =>
      ErrorMapper.guard(() async {
        await _client.rpc('assign_ride_direct', params: {
          'p_ride_id': rideId,
          'p_driver_id': driverId,
        });
      });

  /// Open the ride to all on-duty drivers. First to claim wins.
  Future<void> broadcast(String rideId) => ErrorMapper.guard(() async {
        await _client.rpc('broadcast_ride', params: {'p_ride_id': rideId});
      });

  /// Admin override: reassign to a specific driver, unassign, or cancel — at
  /// any status.
  Future<void> reassign({
    required String rideId,
    required String driverId,
    String? reason,
  }) =>
      ErrorMapper.guard(() async {
        await _client.rpc('admin_override_assignment', params: {
          'p_ride_id': rideId,
          'p_action': 'reassign',
          'p_driver_id': driverId,
          'p_reason': reason,
        });
      });

  Future<void> unassign({required String rideId, String? reason}) =>
      ErrorMapper.guard(() async {
        await _client.rpc('admin_override_assignment', params: {
          'p_ride_id': rideId,
          'p_action': 'unassign',
          'p_reason': reason,
        });
      });

  Future<void> cancel({required String rideId, String? reason}) =>
      ErrorMapper.guard(() async {
        await _client.rpc('admin_override_assignment', params: {
          'p_ride_id': rideId,
          'p_action': 'cancel',
          'p_reason': reason,
        });
      });
}
