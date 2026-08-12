import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ride.dart';
import 'ride_providers.dart';

/// The rides shown on the admin live map: assigned + in-flight rides across the
/// fleet. Kept live two ways —
///  1. realtime `rides` changes (a status advance flips the driver's marker to
///     the new leg and adds/removes rides from the set), and
///  2. a slow poll, because continuous-tracking position updates land on
///     `driver_profiles` (not `rides`) and so don't fire the rides channel; the
///     poll is what makes the marker *glide* between transitions.
///
/// The poll is deliberately gentle — the active set is a fleet's worth of rows,
/// not the whole table — and it only re-reads, never thrashes the UI (a
/// same-value refetch is a no-op to `AsyncValue` consumers).
final activeRidesProvider =
    AsyncNotifierProvider<ActiveRides, List<Ride>>(ActiveRides.new);

class ActiveRides extends AsyncNotifier<List<Ride>> {
  Timer? _poll;

  @override
  Future<List<Ride>> build() async {
    final repo = ref.watch(rideRepositoryProvider);

    final sub = repo.ridesChanges().listen((_) => _refetch());
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refetch());
    ref.onDispose(() {
      sub.cancel();
      _poll?.cancel();
    });

    return repo.fetchActiveRides();
  }

  Future<void> _refetch() async {
    final repo = ref.read(rideRepositoryProvider);
    final next = await AsyncValue.guard(repo.fetchActiveRides);
    // Don't clobber a good list with a transient error mid-poll; keep showing
    // the last known fleet and let the next tick recover.
    if (next.hasError && state.hasValue) return;
    state = next;
  }

  Future<void> refresh() => _refetch();
}

/// The ride whose marker/list row is selected, driving the detail peek and the
/// camera focus. Null means "fit the whole fleet".
final selectedMapRideProvider =
    NotifierProvider<SelectedMapRide, String?>(SelectedMapRide.new);

class SelectedMapRide extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? rideId) => state = rideId;
  void toggle(String rideId) => state = state == rideId ? null : rideId;
}
