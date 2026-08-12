import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../core/error/error_mapper.dart';
import '../data/repositories/assignment_repository.dart';
import '../data/sources/supabase_client_provider.dart';
import 'driver_providers.dart';
import 'ride_providers.dart';

final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  return AssignmentRepository(ref.watch(supabaseClientProvider));
});

/// Drives the assignment actions from the ride detail and assignment sheet.
/// Realtime keeps the ride views current, but we also invalidate the affected
/// providers so the change is instant even if the realtime event is a beat
/// behind.
class AssignmentController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> assignDirect({
    required String rideId,
    required String driverId,
  }) =>
      _run(rideId, () => ref
          .read(assignmentRepositoryProvider)
          .assignDirect(rideId: rideId, driverId: driverId));

  Future<bool> broadcast(String rideId) => _run(
      rideId, () => ref.read(assignmentRepositoryProvider).broadcast(rideId));

  Future<bool> reassign({
    required String rideId,
    required String driverId,
    String? reason,
  }) =>
      _run(
        rideId,
        () => ref.read(assignmentRepositoryProvider).reassign(
              rideId: rideId,
              driverId: driverId,
              reason: reason,
            ),
      );

  Future<bool> unassign({required String rideId, String? reason}) => _run(
        rideId,
        () => ref
            .read(assignmentRepositoryProvider)
            .unassign(rideId: rideId, reason: reason),
      );

  Future<bool> cancel({required String rideId, String? reason}) => _run(
        rideId,
        () => ref
            .read(assignmentRepositoryProvider)
            .cancel(rideId: rideId, reason: reason),
      );

  Future<bool> _run(String rideId, Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    state = result;
    if (!result.hasError) {
      ref.invalidate(rideDetailProvider(rideId));
      ref.invalidate(calendarRidesProvider);
      ref.invalidate(rideListProvider);
      ref.invalidate(todayRidesProvider);
      ref.invalidate(dashboardStatsProvider);
    }
    return !result.hasError;
  }

  AppException? get errorOrNull {
    final e = state.error;
    return e == null ? null : ErrorMapper.map(e, state.stackTrace);
  }
}

final assignmentControllerProvider =
    AsyncNotifierProvider<AssignmentController, void>(AssignmentController.new);

/// Drives driver approval from the approvals screen.
class ApprovalController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> review({
    required String driverId,
    required bool approve,
    String? reason,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref.read(driverRepositoryProvider).reviewDriver(
            driverId: driverId,
            approve: approve,
            reason: reason,
          );
    });
    state = result;
    if (!result.hasError) {
      ref.invalidate(pendingDriversProvider);
      ref.invalidate(driverListProvider);
      ref.invalidate(approvedDriversProvider);
    }
    return !result.hasError;
  }

  AppException? get errorOrNull {
    final e = state.error;
    return e == null ? null : ErrorMapper.map(e, state.stackTrace);
  }
}

final approvalControllerProvider =
    AsyncNotifierProvider<ApprovalController, void>(ApprovalController.new);
