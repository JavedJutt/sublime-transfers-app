import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../data/models/ride_status.dart';
import '../../../data/repositories/driver_ride_repository.dart';
import '../../../providers/driver_app_providers.dart';
import '../../../services/location/location_capture.dart';

/// The outcome of a driver action, for the UI to react to.
sealed class DriverActionOutcome {
  const DriverActionOutcome();
}

/// Delivered to the server.
class ActionSent extends DriverActionOutcome {
  const ActionSent();
}

/// Queued offline; the UI shows an optimistic state + "will sync" note.
class ActionQueued extends DriverActionOutcome {
  const ActionQueued();
}

/// Rejected by a business rule (e.g. a broadcast already claimed).
class ActionRejected extends DriverActionOutcome {
  const ActionRejected(this.error);
  final AppException error;
}

/// Drives the status flow, offer responses, and broadcast claims. Captures
/// location before each action and passes it into the repository so the fix and
/// the transition land together. A GPS failure never blocks the action.
class StatusController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<DriverActionOutcome> advance({
    required String rideId,
    required RideStatus to,
  }) async {
    return _run(() async {
      final location =
          await ref.read(locationServiceProvider).captureForStatusChange();
      final repo = await ref.read(driverRideRepositoryProvider.future);
      final result = await repo.advanceStatus(
        rideId: rideId,
        to: to,
        location: location,
      );
      _invalidate();
      return _outcome(result);
    });
  }

  Future<DriverActionOutcome> respond({
    required String rideId,
    required bool accept,
    String? reason,
  }) async {
    return _run(() async {
      // Accepting is a meaningful location moment; declining isn't.
      final LocationCapture? location = accept
          ? await ref.read(locationServiceProvider).captureForStatusChange()
          : null;
      final repo = await ref.read(driverRideRepositoryProvider.future);
      final result = await repo.respondToOffer(
        rideId: rideId,
        accept: accept,
        reason: reason,
        location: location,
      );
      _invalidate();
      return _outcome(result);
    });
  }

  Future<DriverActionOutcome> claim({required String rideId}) async {
    return _run(() async {
      final location =
          await ref.read(locationServiceProvider).captureForStatusChange();
      final repo = await ref.read(driverRideRepositoryProvider.future);
      final result = await repo.claimBroadcast(rideId: rideId, location: location);
      _invalidate();
      return _outcome(result);
    });
  }

  Future<DriverActionOutcome> _run(
    Future<DriverActionOutcome> Function() action,
  ) async {
    state = const AsyncLoading();
    try {
      final outcome = await action();
      state = const AsyncData(null);
      return outcome;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      rethrow;
    }
  }

  DriverActionOutcome _outcome(OutboxResult result) => switch (result) {
        OutboxSent() => const ActionSent(),
        OutboxQueued() => const ActionQueued(),
        OutboxFailed(:final error) => ActionRejected(error),
      };

  void _invalidate() {
    ref.invalidate(driverDayRidesProvider);
    ref.invalidate(driverActiveRideProvider);
    ref.invalidate(driverOffersProvider);
    ref.invalidate(driverRideProvider);
  }
}

final statusControllerProvider =
    AsyncNotifierProvider<StatusController, void>(StatusController.new);
