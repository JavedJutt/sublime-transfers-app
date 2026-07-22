import 'enums.dart';
import 'ride_status.dart';

/// A ride. Parsed from the `admin_rides` or `driver_rides` view depending on
/// role — the admin-only fields ([sourceAdminId], [sourceAdminName],
/// [assigningAdminId], …) are simply null when the row came from the driver
/// view, because that view does not project them. The app never has to remember
/// to hide them; they aren't there.
class Ride {
  const Ride({
    required this.id,
    required this.reference,
    required this.pickupAt,
    required this.customerName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.passengers,
    required this.luggage,
    required this.status,
    this.customerPhone,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.fareAmount,
    this.fareCurrency = 'GBP',
    this.vehicleType,
    this.flightNumber,
    this.notes,
    this.assignedDriverId,
    this.assignmentMethod,
    this.assignedAt,
    this.broadcastOpen = false,
    this.createdAt,
    this.updatedAt,
    // Admin-only — null on driver-sourced rows.
    this.sourceAdminId,
    this.sourceAdminName,
    this.assigningAdminId,
    this.assigningAdminName,
    this.driverName,
    this.driverPhone,
    this.driverVehicleType,
    this.driverOnDuty,
    this.driverLastLat,
    this.driverLastLng,
    this.driverLastLocationAt,
  });

  final String id;
  final String reference;
  final DateTime pickupAt;
  final String customerName;
  final String? customerPhone;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String dropoffAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final int passengers;
  final int luggage;
  final num? fareAmount;
  final String fareCurrency;
  final VehicleType? vehicleType;
  final String? flightNumber;
  final String? notes;
  final RideStatus status;
  final String? assignedDriverId;
  final AssignmentMethod? assignmentMethod;
  final DateTime? assignedAt;
  final bool broadcastOpen;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ---- admin-only projection ----
  final String? sourceAdminId;
  final String? sourceAdminName;
  final String? assigningAdminId;
  final String? assigningAdminName;
  final String? driverName;
  final String? driverPhone;
  final VehicleType? driverVehicleType;
  final bool? driverOnDuty;
  final double? driverLastLat;
  final double? driverLastLng;
  final DateTime? driverLastLocationAt;

  bool get isAssigned => assignedDriverId != null;
  bool get isAirportPickup => flightNumber != null && flightNumber!.isNotEmpty;
  bool get hasPickupCoords => pickupLat != null && pickupLng != null;
  bool get hasDropoffCoords => dropoffLat != null && dropoffLng != null;
  bool get hasDriverLocation =>
      driverLastLat != null && driverLastLng != null;

  static double? _d(dynamic v) => (v as num?)?.toDouble();
  static DateTime? _t(dynamic v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  factory Ride.fromMap(Map<String, dynamic> m) => Ride(
        id: m['id'] as String,
        reference: m['reference'] as String,
        pickupAt: DateTime.parse(m['pickup_at'] as String).toLocal(),
        customerName: m['customer_name'] as String,
        customerPhone: m['customer_phone'] as String?,
        pickupAddress: m['pickup_address'] as String,
        pickupLat: _d(m['pickup_lat']),
        pickupLng: _d(m['pickup_lng']),
        dropoffAddress: m['dropoff_address'] as String,
        dropoffLat: _d(m['dropoff_lat']),
        dropoffLng: _d(m['dropoff_lng']),
        passengers: (m['passengers'] as num?)?.toInt() ?? 1,
        luggage: (m['luggage'] as num?)?.toInt() ?? 0,
        fareAmount: m['fare_amount'] as num?,
        fareCurrency: m['fare_currency'] as String? ?? 'GBP',
        vehicleType: VehicleType.fromWire(m['vehicle_type'] as String?),
        flightNumber: m['flight_number'] as String?,
        notes: m['notes'] as String?,
        status: RideStatus.fromWire(m['status'] as String),
        assignedDriverId: m['assigned_driver_id'] as String?,
        assignmentMethod:
            AssignmentMethod.fromWire(m['assignment_method'] as String?),
        assignedAt: _t(m['assigned_at']),
        broadcastOpen: m['broadcast_open'] as bool? ?? false,
        createdAt: _t(m['created_at']),
        updatedAt: _t(m['updated_at']),
        sourceAdminId: m['source_admin_id'] as String?,
        sourceAdminName: m['source_admin_name'] as String?,
        assigningAdminId: m['assigning_admin_id'] as String?,
        assigningAdminName: m['assigning_admin_name'] as String?,
        driverName: m['driver_name'] as String?,
        driverPhone: m['driver_phone'] as String?,
        driverVehicleType:
            VehicleType.fromWire(m['driver_vehicle_type'] as String?),
        driverOnDuty: m['driver_on_duty'] as bool?,
        driverLastLat: _d(m['driver_last_lat']),
        driverLastLng: _d(m['driver_last_lng']),
        driverLastLocationAt: _t(m['driver_last_location_at']),
      );
}
