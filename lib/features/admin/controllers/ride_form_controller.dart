import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../../../data/models/ride.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/ride_providers.dart';

/// Drives the create/edit ride form. On success it invalidates the calendar and
/// (for edits) the detail so the change shows immediately, and returns the
/// ride id so the screen can navigate to it.
class RideFormController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<String?> submitCreate(RideInput input) async {
    final adminId = ref.read(currentUserProvider).value?.id;
    if (adminId == null) return null;

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final ride = await ref
          .read(rideRepositoryProvider)
          .createRide(input, adminId: adminId);
      _invalidateLists();
      return ride;
    });
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    return result.value?.id;
  }

  Future<String?> submitUpdate(String rideId, RideInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final ride =
          await ref.read(rideRepositoryProvider).updateRide(rideId, input);
      _invalidateLists();
      ref.invalidate(rideDetailProvider(rideId));
      return ride;
    });
    state = result.hasError
        ? AsyncError(result.error!, result.stackTrace!)
        : const AsyncData(null);
    return result.value?.id;
  }

  void _invalidateLists() {
    ref.invalidate(calendarRidesProvider);
    ref.invalidate(rideListProvider);
    ref.invalidate(todayRidesProvider);
    ref.invalidate(dashboardStatsProvider);
  }

  AppException? get errorOrNull {
    final e = state.error;
    return e == null ? null : ErrorMapper.map(e, state.stackTrace);
  }
}

final rideFormControllerProvider =
    AsyncNotifierProvider<RideFormController, void>(RideFormController.new);

/// Builds a [RideInput] from an existing ride, for the edit form's initial
/// values.
RideInput rideToInput(Ride r) => RideInput(
      pickupAt: r.pickupAt,
      customerName: r.customerName,
      customerPhone: r.customerPhone,
      pickupAddress: r.pickupAddress,
      dropoffAddress: r.dropoffAddress,
      passengers: r.passengers,
      luggage: r.luggage,
      fareAmount: r.fareAmount,
      vehicleType: r.vehicleType,
      flightNumber: r.flightNumber,
      notes: r.notes,
      pickupLat: r.pickupLat,
      pickupLng: r.pickupLng,
      dropoffLat: r.dropoffLat,
      dropoffLng: r.dropoffLng,
    );
