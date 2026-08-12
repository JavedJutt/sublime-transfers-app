import '../../core/utils/date_x.dart';
import 'ride_status.dart';

/// The query shape the calendar and ride list hand to the repository. Combines
/// a visible date range with optional driver, status, and free-text filters.
/// Immutable and value-equal so it can key a family provider without spawning
/// duplicate subscriptions.
class RideFilter {
  const RideFilter({
    required this.range,
    this.driverId,
    this.statuses = const {},
    this.search = '',
  });

  final DateRange range;
  final String? driverId;
  final Set<RideStatus> statuses;
  final String search;

  bool get hasActiveFilters =>
      driverId != null || statuses.isNotEmpty || search.trim().isNotEmpty;

  RideFilter copyWith({
    DateRange? range,
    String? driverId,
    bool clearDriver = false,
    Set<RideStatus>? statuses,
    String? search,
  }) =>
      RideFilter(
        range: range ?? this.range,
        driverId: clearDriver ? null : (driverId ?? this.driverId),
        statuses: statuses ?? this.statuses,
        search: search ?? this.search,
      );

  @override
  bool operator ==(Object other) =>
      other is RideFilter &&
      other.range.start == range.start &&
      other.range.end == range.end &&
      other.driverId == driverId &&
      other.search == search &&
      _setEq(other.statuses, statuses);

  @override
  int get hashCode => Object.hash(
        range.start,
        range.end,
        driverId,
        search,
        Object.hashAllUnordered(statuses),
      );

  static bool _setEq(Set<RideStatus> a, Set<RideStatus> b) =>
      a.length == b.length && a.containsAll(b);
}
