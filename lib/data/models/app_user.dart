import 'enums.dart';
import 'user_role.dart';

/// The signed-in user: profile identity plus, for drivers, their driver
/// profile. This is the single source of truth for role and approval status
/// that the router guard reads.
class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.isActive = true,
    this.driver,
  });

  final String id;
  final UserRole role;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final bool isActive;

  /// Present only for drivers.
  final DriverProfile? driver;

  bool get isAdmin => role.isAdmin;
  bool get isDriver => role.isDriver;

  /// A driver may receive rides only once approved. Admins are always "approved"
  /// in the sense the guard cares about.
  bool get isApproved =>
      isAdmin || (driver?.approvalStatus.isApproved ?? false);

  bool get isPendingApproval =>
      isDriver && (driver?.approvalStatus == DriverApprovalStatus.pending);

  factory AppUser.fromProfile(
    Map<String, dynamic> profile, {
    Map<String, dynamic>? driverProfile,
  }) {
    final role = UserRole.fromWire(profile['role'] as String);
    return AppUser(
      id: profile['id'] as String,
      role: role,
      fullName: profile['full_name'] as String,
      email: profile['email'] as String,
      phone: profile['phone'] as String?,
      avatarUrl: profile['avatar_url'] as String?,
      isActive: profile['is_active'] as bool? ?? true,
      driver: driverProfile == null
          ? null
          : DriverProfile.fromMap(driverProfile),
    );
  }

  AppUser copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    DriverProfile? driver,
  }) =>
      AppUser(
        id: id,
        role: role,
        fullName: fullName ?? this.fullName,
        email: email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isActive: isActive,
        driver: driver ?? this.driver,
      );
}

/// Driver-specific detail. Mirrors `driver_profiles`.
class DriverProfile {
  const DriverProfile({
    required this.id,
    required this.approvalStatus,
    this.vehicleType,
    this.vehicleMake,
    this.vehiclePlate,
    this.licenceNumber,
    this.isOnDuty = false,
    this.lastLat,
    this.lastLng,
    this.lastLocationAt,
    this.rejectionReason,
  });

  final String id;
  final DriverApprovalStatus approvalStatus;
  final VehicleType? vehicleType;
  final String? vehicleMake;
  final String? vehiclePlate;
  final String? licenceNumber;
  final bool isOnDuty;
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastLocationAt;
  final String? rejectionReason;

  factory DriverProfile.fromMap(Map<String, dynamic> m) => DriverProfile(
        id: m['id'] as String,
        approvalStatus:
            DriverApprovalStatus.fromWire(m['approval_status'] as String),
        vehicleType: VehicleType.fromWire(m['vehicle_type'] as String?),
        vehicleMake: m['vehicle_make'] as String?,
        vehiclePlate: m['vehicle_plate'] as String?,
        licenceNumber: m['licence_number'] as String?,
        isOnDuty: m['is_on_duty'] as bool? ?? false,
        lastLat: (m['last_lat'] as num?)?.toDouble(),
        lastLng: (m['last_lng'] as num?)?.toDouble(),
        lastLocationAt: m['last_location_at'] == null
            ? null
            : DateTime.parse(m['last_location_at'] as String),
        rejectionReason: m['rejection_reason'] as String?,
      );
}
