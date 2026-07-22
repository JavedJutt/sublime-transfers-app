import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/date_x.dart';
import '../data/models/ride.dart';
import '../data/models/ride_filter.dart';
import '../data/models/ride_status.dart';
import '../data/models/ride_status_event.dart';
import '../data/repositories/ride_repository.dart';
import '../data/sources/supabase_client_provider.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository(ref.watch(supabaseClientProvider));
});

// ------------------------------------------------------------- calendar state
/// Day / Week / Month.
enum CalendarViewMode {
  day,
  week,
  month;

  String get label => switch (this) {
        CalendarViewMode.day => 'Day',
        CalendarViewMode.week => 'Week',
        CalendarViewMode.month => 'Month',
      };
}

final calendarViewModeProvider =
    NotifierProvider<CalendarViewModeNotifier, CalendarViewMode>(
  CalendarViewModeNotifier.new,
);

class CalendarViewModeNotifier extends Notifier<CalendarViewMode> {
  @override
  CalendarViewMode build() => CalendarViewMode.day;
  void set(CalendarViewMode mode) => state = mode;
}

/// The date the calendar is focused on.
final focusedDateProvider =
    NotifierProvider<FocusedDateNotifier, DateTime>(FocusedDateNotifier.new);

class FocusedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now().dayStart;

  void set(DateTime date) => state = date.dayStart;
  void today() => state = DateTime.now().dayStart;

  /// Step forward/back by one unit of the current view mode.
  void step(int direction) {
    final mode = ref.read(calendarViewModeProvider);
    state = switch (mode) {
      CalendarViewMode.day => state.addDays(direction),
      CalendarViewMode.week => state.addDays(7 * direction),
      CalendarViewMode.month =>
        DateTime(state.year, state.month + direction, 1),
    };
  }
}

/// The visible date range, derived from view mode + focused date.
final visibleRangeProvider = Provider<DateRange>((ref) {
  final mode = ref.watch(calendarViewModeProvider);
  final focused = ref.watch(focusedDateProvider);
  return switch (mode) {
    CalendarViewMode.day =>
      DateRange(focused.dayStart, focused.addDays(1).dayStart),
    CalendarViewMode.week =>
      DateRange(focused.weekStart, focused.weekStart.addDays(7)),
    CalendarViewMode.month => DateRange(
        focused.monthStart,
        DateTime(focused.year, focused.month + 1, 1),
      ),
  };
});

// -------------------------------------------------------------------- filters
final driverFilterProvider =
    NotifierProvider<DriverFilterNotifier, String?>(DriverFilterNotifier.new);

class DriverFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? driverId) => state = driverId;
}

final statusFilterProvider =
    NotifierProvider<StatusFilterNotifier, Set<RideStatus>>(
  StatusFilterNotifier.new,
);

class StatusFilterNotifier extends Notifier<Set<RideStatus>> {
  @override
  Set<RideStatus> build() => {};

  void toggle(RideStatus status) {
    state = state.contains(status)
        ? (state.toSet()..remove(status))
        : (state.toSet()..add(status));
  }

  void clear() => state = {};
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q;
}

/// Whether any non-range filter is active — drives the "filtered empty" state
/// and the Clear filters affordance.
final hasActiveFiltersProvider = Provider<bool>((ref) {
  return ref.watch(driverFilterProvider) != null ||
      ref.watch(statusFilterProvider).isNotEmpty ||
      ref.watch(searchQueryProvider).trim().isNotEmpty;
});

/// The composed filter the repository consumes.
final rideFilterProvider = Provider<RideFilter>((ref) {
  return RideFilter(
    range: ref.watch(visibleRangeProvider),
    driverId: ref.watch(driverFilterProvider),
    statuses: ref.watch(statusFilterProvider),
    search: ref.watch(searchQueryProvider),
  );
});

// --------------------------------------------------------------------- rides
/// The rides in the current filter window. Re-fetches on any realtime ride
/// change so the shared pool stays live across admins.
final calendarRidesProvider =
    AsyncNotifierProvider<CalendarRides, List<Ride>>(CalendarRides.new);

class CalendarRides extends AsyncNotifier<List<Ride>> {
  @override
  Future<List<Ride>> build() async {
    final filter = ref.watch(rideFilterProvider);
    final repo = ref.watch(rideRepositoryProvider);

    // Re-fetch (debounced by Riverpod's rebuild) whenever a ride changes.
    final sub = repo.ridesChanges().listen((_) => _refetch());
    ref.onDispose(sub.cancel);

    return repo.fetchRides(filter);
  }

  Future<void> _refetch() async {
    final filter = ref.read(rideFilterProvider);
    final repo = ref.read(rideRepositoryProvider);
    state = await AsyncValue.guard(() => repo.fetchRides(filter));
  }

  Future<void> refresh() => _refetch();
}

/// Rides grouped by day, each list sorted by pickup time — the shape the
/// week/month grids consume.
final ridesByDayProvider = Provider<Map<String, List<Ride>>>((ref) {
  final rides = ref.watch(calendarRidesProvider).value ?? const [];
  final byDay = <String, List<Ride>>{};
  for (final ride in rides) {
    byDay.putIfAbsent(ride.pickupAt.dayKey, () => []).add(ride);
  }
  for (final list in byDay.values) {
    list.sort((a, b) => a.pickupAt.compareTo(b.pickupAt));
  }
  return byDay;
});

// -------------------------------------------------------------- ride list
/// The flat ride list screen. Independent of calendar navigation: a rolling
/// window (past week to two months ahead) combined with the shared driver /
/// status / search filters. Re-fetches on any ride change.
final rideListProvider = FutureProvider<List<Ride>>((ref) {
  final repo = ref.watch(rideRepositoryProvider);
  final now = DateTime.now();
  final filter = RideFilter(
    range: DateRange(now.addDays(-7).dayStart, now.addDays(60).dayStart),
    driverId: ref.watch(driverFilterProvider),
    statuses: ref.watch(statusFilterProvider),
    search: ref.watch(searchQueryProvider),
  );
  final sub = repo.ridesChanges().listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return repo.fetchRides(filter);
});

/// A driver's rides over a rolling window, for the driver detail screen.
final driverRidesProvider =
    FutureProvider.family<List<Ride>, String>((ref, driverId) {
  final repo = ref.watch(rideRepositoryProvider);
  final now = DateTime.now();
  final sub = repo.ridesChanges().listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return repo.fetchRides(
    RideFilter(
      range: DateRange(now.addDays(-14).dayStart, now.addDays(60).dayStart),
      driverId: driverId,
    ),
  );
});

// ------------------------------------------------------------- detail + audit
/// A single ride, live. Re-fetches on any ride change so an edit or assignment
/// by another admin reflects here without a manual refresh. Refresh manually
/// with `ref.invalidate(rideDetailProvider(id))`.
final rideDetailProvider =
    FutureProvider.family<Ride, String>((ref, rideId) {
  final repo = ref.watch(rideRepositoryProvider);
  final sub = repo.ridesChanges().listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return repo.fetchRide(rideId);
});

final rideTimelineProvider =
    FutureProvider.family<List<RideStatusEvent>, String>((ref, rideId) {
  // Depend on the ride detail so the timeline refreshes when the ride changes.
  ref.watch(rideDetailProvider(rideId));
  return ref.watch(rideRepositoryProvider).fetchTimeline(rideId);
});

// ----------------------------------------------------------------- dashboard
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) {
  // Refresh stats whenever a ride changes.
  final repo = ref.watch(rideRepositoryProvider);
  final sub = repo.ridesChanges().listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return repo.fetchTodayStats();
});

/// Today's rides for the dashboard's "up next" list — its own scoped fetch, so
/// it is independent of wherever the admin has navigated the calendar.
final todayRidesProvider = FutureProvider<List<Ride>>((ref) {
  final repo = ref.watch(rideRepositoryProvider);
  final sub = repo.ridesChanges().listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  final now = DateTime.now();
  return repo.fetchRides(
    RideFilter(range: DateRange(now.dayStart, now.addDays(1).dayStart)),
  );
});
