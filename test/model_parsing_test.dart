import 'package:flutter_test/flutter_test.dart';
import 'package:sublime_transfers/data/models/app_user.dart';
import 'package:sublime_transfers/data/models/enums.dart';
import 'package:sublime_transfers/data/models/ride.dart';
import 'package:sublime_transfers/data/models/ride_status.dart';
import 'package:sublime_transfers/data/models/user_role.dart';

/// These fixtures are the exact column sets the live `admin_rides` and
/// `driver_rides` views return (captured from the running project). Parsing
/// them here locks the Dart models to the database schema: if a migration
/// renames a column, this test fails rather than the app silently reading null.

// A real admin_rides row shape.
final _adminRideRow = <String, dynamic>{
  'id': '11111111-1111-1111-1111-111111111111',
  'reference': 'ST-SEED05',
  'pickup_at': '2026-07-21T15:00:00+00:00',
  'customer_name': 'Amelia Hart',
  'customer_phone': '+44 7700 900205',
  'pickup_address': 'The Shard, 32 London Bridge St',
  'pickup_lat': 51.5045,
  'pickup_lng': -0.0865,
  'dropoff_address': 'Heathrow Terminal 2',
  'dropoff_lat': 51.47,
  'dropoff_lng': -0.4543,
  'passengers': 2,
  'luggage': 2,
  'fare_amount': 120.00,
  'fare_currency': 'GBP',
  'vehicle_type': 'executive',
  'flight_number': 'LH0907',
  'notes': 'Flight departs 18:00.',
  'status': 'assigned',
  'source_admin_id': 'aaaa1111-1111-1111-1111-111111111111',
  'source_email_id': null,
  'assigned_driver_id': 'dddd1111-1111-1111-1111-111111111111',
  'assigning_admin_id': 'aaaa1111-1111-1111-1111-111111111111',
  'assignment_method': 'direct',
  'assigned_at': '2026-07-21T12:00:00+00:00',
  'broadcast_open': false,
  'broadcast_started_at': null,
  'claimed_at': null,
  'cancelled_reason': null,
  'created_by': 'aaaa1111-1111-1111-1111-111111111111',
  'created_at': '2026-07-21T09:00:00+00:00',
  'updated_at': '2026-07-21T12:00:00+00:00',
  'source_admin_name': 'Ava Whitfield',
  'assigning_admin_name': 'Ava Whitfield',
  'driver_name': 'Marcus Bell',
  'driver_phone': '+44 7700 900101',
  'driver_vehicle_type': 'executive',
  'driver_on_duty': true,
  'driver_last_lat': 51.5,
  'driver_last_lng': -0.1,
  'driver_last_location_at': '2026-07-21T14:30:00+00:00',
};

// A real driver_rides row shape — note the admin-only columns are ABSENT, not
// null. The parser must tolerate their total absence.
final _driverRideRow = <String, dynamic>{
  'id': '22222222-2222-2222-2222-222222222222',
  'reference': 'ST-SEED04',
  'pickup_at': '2026-07-21T13:30:00+00:00',
  'customer_name': 'James Okonkwo',
  'customer_phone': '+44 7700 900204',
  'pickup_address': 'Mayfair, Berkeley Square',
  'pickup_lat': 51.51,
  'pickup_lng': -0.1465,
  'dropoff_address': 'London City Airport',
  'dropoff_lat': 51.5048,
  'dropoff_lng': 0.0495,
  'passengers': 1,
  'luggage': 1,
  'fare_amount': 80.0,
  'fare_currency': 'GBP',
  'vehicle_type': 'sedan',
  'flight_number': null,
  'notes': null,
  'status': 'offered',
  'assigned_driver_id': null,
  'assignment_method': 'direct',
  'broadcast_open': false,
  'assigned_at': null,
  'created_at': '2026-07-21T09:00:00+00:00',
  'updated_at': '2026-07-21T09:00:00+00:00',
};

void main() {
  group('Ride.fromMap', () {
    test('parses a full admin_rides row', () {
      final ride = Ride.fromMap(_adminRideRow);
      expect(ride.reference, 'ST-SEED05');
      expect(ride.status, RideStatus.assigned);
      expect(ride.vehicleType, VehicleType.executive);
      expect(ride.assignmentMethod, AssignmentMethod.direct);
      expect(ride.passengers, 2);
      expect(ride.fareAmount, 120.0);
      expect(ride.isAirportPickup, isTrue);
      expect(ride.hasPickupCoords, isTrue);
      // Admin-only projection present.
      expect(ride.sourceAdminName, 'Ava Whitfield');
      expect(ride.driverName, 'Marcus Bell');
      expect(ride.hasDriverLocation, isTrue);
      // pickup_at parsed and localised.
      expect(ride.pickupAt.toUtc(),
          DateTime.parse('2026-07-21T15:00:00Z').toUtc());
    });

    test('parses a driver_rides row with admin columns absent', () {
      final ride = Ride.fromMap(_driverRideRow);
      expect(ride.reference, 'ST-SEED04');
      expect(ride.status, RideStatus.offered);
      // The admin-only fields simply come through null — no crash on absence.
      expect(ride.sourceAdminId, isNull);
      expect(ride.sourceAdminName, isNull);
      expect(ride.assigningAdminId, isNull);
      expect(ride.driverName, isNull);
      expect(ride.hasDriverLocation, isFalse);
    });
  });

  group('AppUser.fromProfile', () {
    test('parses an admin profile without a driver profile', () {
      final user = AppUser.fromProfile({
        'id': 'aaaa1111-1111-1111-1111-111111111111',
        'role': 'admin',
        'full_name': 'Ava Whitfield',
        'email': 'ava.admin@sublimetransfers.test',
        'phone': '+44 20 7946 0011',
        'avatar_url': null,
        'is_active': true,
      });
      expect(user.role, UserRole.admin);
      expect(user.isAdmin, isTrue);
      expect(user.isApproved, isTrue, reason: 'admins are always approved');
      expect(user.driver, isNull);
    });

    test('parses an approved driver profile', () {
      final user = AppUser.fromProfile(
        {
          'id': 'dddd1111-1111-1111-1111-111111111111',
          'role': 'driver',
          'full_name': 'Marcus Bell',
          'email': 'marcus.driver@sublimetransfers.test',
          'phone': '+44 7700 900101',
          'avatar_url': null,
          'is_active': true,
        },
        driverProfile: {
          'id': 'dddd1111-1111-1111-1111-111111111111',
          'approval_status': 'approved',
          'vehicle_type': 'executive',
          'vehicle_make': 'Mercedes E-Class',
          'vehicle_plate': 'LX21 ATE',
          'is_on_duty': true,
          'last_lat': null,
          'last_lng': null,
          'last_location_at': null,
        },
      );
      expect(user.isDriver, isTrue);
      expect(user.isApproved, isTrue);
      expect(user.isPendingApproval, isFalse);
      expect(user.driver!.vehicleType, VehicleType.executive);
      expect(user.driver!.isOnDuty, isTrue);
    });

    test('a pending driver is not approved and is flagged pending', () {
      final user = AppUser.fromProfile(
        {
          'id': 'dddd2222-2222-2222-2222-222222222222',
          'role': 'driver',
          'full_name': 'Sam Okafor',
          'email': 'sam.driver@sublimetransfers.test',
          'phone': null,
          'avatar_url': null,
          'is_active': true,
        },
        driverProfile: {
          'id': 'dddd2222-2222-2222-2222-222222222222',
          'approval_status': 'pending',
          'vehicle_type': 'sedan',
          'is_on_duty': false,
        },
      );
      expect(user.isApproved, isFalse);
      expect(user.isPendingApproval, isTrue);
    });
  });

  group('RideStatus transitions mirror the database', () {
    test('driverNext follows the confirmed flow', () {
      expect(RideStatus.assigned.driverNext, RideStatus.enRoute);
      expect(RideStatus.enRoute.driverNext, RideStatus.arrived);
      expect(RideStatus.arrived.driverNext, RideStatus.inProgress);
      expect(RideStatus.inProgress.driverNext, RideStatus.completed);
      expect(RideStatus.completed.driverNext, isNull);
      expect(RideStatus.unassigned.driverNext, isNull);
    });

    test('wire round-trips for every status', () {
      for (final s in RideStatus.values) {
        expect(RideStatus.fromWire(s.wire), s);
      }
    });
  });
}
