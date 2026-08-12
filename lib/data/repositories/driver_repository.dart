import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/error_mapper.dart';
import '../models/enums.dart';

/// A driver as an admin sees them in lists: profile joined with driver profile.
class DriverListItem {
  const DriverListItem({
    required this.id,
    required this.fullName,
    required this.email,
    required this.approvalStatus,
    this.phone,
    this.avatarUrl,
    this.vehicleType,
    this.vehiclePlate,
    this.isOnDuty = false,
    this.lastLat,
    this.lastLng,
    this.lastLocationAt,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final DriverApprovalStatus approvalStatus;
  final String? phone;
  final String? avatarUrl;
  final VehicleType? vehicleType;
  final String? vehiclePlate;
  final bool isOnDuty;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastLocationAt;
  final DateTime? createdAt;

  bool get isApproved => approvalStatus.isApproved;
  bool get isPending => approvalStatus == DriverApprovalStatus.pending;
  bool get hasLocation => lastLat != null && lastLng != null;

  factory DriverListItem.fromRow(Map<String, dynamic> m) {
    // The row is a driver_profiles record with the joined profile nested under
    // `profile`.
    final profile = (m['profile'] as Map).cast<String, dynamic>();
    return DriverListItem(
      id: m['id'] as String,
      fullName: profile['full_name'] as String,
      email: profile['email'] as String,
      phone: profile['phone'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      approvalStatus:
          DriverApprovalStatus.fromWire(m['approval_status'] as String),
      vehicleType: VehicleType.fromWire(m['vehicle_type'] as String?),
      vehiclePlate: m['vehicle_plate'] as String?,
      isOnDuty: m['is_on_duty'] as bool? ?? false,
      lastLat: (m['last_lat'] as num?)?.toDouble(),
      lastLng: (m['last_lng'] as num?)?.toDouble(),
      lastLocationAt: m['last_location_at'] == null
          ? null
          : DateTime.parse(m['last_location_at'] as String).toLocal(),
      createdAt: m['created_at'] == null
          ? null
          : DateTime.parse(m['created_at'] as String).toLocal(),
    );
  }
}

/// Driver-facing admin operations: list, approve/reject, and the current
/// driver's own duty toggle.
class DriverRepository {
  DriverRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, profile:profiles!driver_profiles_id_fkey(full_name, email, phone, avatar_url)';

  /// All drivers, newest first. Admin RLS returns every row.
  Future<List<DriverListItem>> fetchDrivers() => ErrorMapper.guard(() async {
        final rows = await _client
            .from('driver_profiles')
            .select(_select)
            .order('created_at', ascending: false);
        return rows.map(DriverListItem.fromRow).toList();
      });

  /// Approved drivers only — the pool the assignment sheet and driver filter
  /// draw from.
  Future<List<DriverListItem>> fetchApprovedDrivers() =>
      ErrorMapper.guard(() async {
        final rows = await _client
            .from('driver_profiles')
            .select(_select)
            .eq('approval_status', 'approved')
            .order('is_on_duty', ascending: false);
        return rows.map(DriverListItem.fromRow).toList();
      });

  Future<List<DriverListItem>> fetchPendingDrivers() =>
      ErrorMapper.guard(() async {
        final rows = await _client
            .from('driver_profiles')
            .select(_select)
            .eq('approval_status', 'pending')
            .order('created_at');
        return rows.map(DriverListItem.fromRow).toList();
      });

  /// Approve or reject a driver via the `review_driver` RPC (admin-guarded,
  /// audited, notifies the driver).
  Future<void> reviewDriver({
    required String driverId,
    required bool approve,
    String? reason,
  }) =>
      ErrorMapper.guard(() async {
        await _client.rpc('review_driver', params: {
          'p_driver_id': driverId,
          'p_approve': approve,
          'p_reason': reason,
        });
      });

  /// The current driver toggles their on-duty state via the RPC.
  Future<void> setDuty(bool onDuty) => ErrorMapper.guard(() async {
        await _client.rpc('set_driver_duty', params: {'p_on_duty': onDuty});
      });
}
