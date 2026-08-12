import '../../shared/widgets/display/status_chip.dart';

/// Ride lifecycle. Mirrors the `ride_status` Postgres enum, in lifecycle order.
enum RideStatus {
  draft,
  unassigned,
  offered,
  assigned,
  enRoute,
  arrived,
  inProgress,
  completed,
  cancelled,
  noShow;

  static RideStatus fromWire(String value) => switch (value) {
        'draft' => RideStatus.draft,
        'unassigned' => RideStatus.unassigned,
        'offered' => RideStatus.offered,
        'assigned' => RideStatus.assigned,
        'en_route' => RideStatus.enRoute,
        'arrived' => RideStatus.arrived,
        'in_progress' => RideStatus.inProgress,
        'completed' => RideStatus.completed,
        'cancelled' => RideStatus.cancelled,
        'no_show' => RideStatus.noShow,
        _ => throw ArgumentError('Unknown ride_status: $value'),
      };

  String get wire => switch (this) {
        RideStatus.draft => 'draft',
        RideStatus.unassigned => 'unassigned',
        RideStatus.offered => 'offered',
        RideStatus.assigned => 'assigned',
        RideStatus.enRoute => 'en_route',
        RideStatus.arrived => 'arrived',
        RideStatus.inProgress => 'in_progress',
        RideStatus.completed => 'completed',
        RideStatus.cancelled => 'cancelled',
        RideStatus.noShow => 'no_show',
      };

  /// Short label for chips and headers.
  String get label => switch (this) {
        RideStatus.draft => 'Draft',
        RideStatus.unassigned => 'Unassigned',
        RideStatus.offered => 'Offered',
        RideStatus.assigned => 'Assigned',
        RideStatus.enRoute => 'En route',
        RideStatus.arrived => 'At pickup',
        RideStatus.inProgress => 'In progress',
        RideStatus.completed => 'Completed',
        RideStatus.cancelled => 'Cancelled',
        RideStatus.noShow => 'No-show',
      };

  /// The chip tone. This is the single mapping from status to semantic colour;
  /// the colours themselves live in [StatusTone].
  StatusTone get tone => switch (this) {
        RideStatus.unassigned => StatusTone.urgent,
        RideStatus.offered => StatusTone.pending,
        RideStatus.draft => StatusTone.dormant,
        RideStatus.assigned => StatusTone.scheduled,
        RideStatus.enRoute ||
        RideStatus.arrived ||
        RideStatus.inProgress =>
          StatusTone.active,
        RideStatus.completed => StatusTone.complete,
        RideStatus.cancelled || RideStatus.noShow => StatusTone.dormant,
      };

  /// True for the three states a driver actively works through — used to drive
  /// the pulsing "live" chip and continuous tracking.
  bool get isLive =>
      this == RideStatus.enRoute ||
      this == RideStatus.arrived ||
      this == RideStatus.inProgress;

  bool get isClosed =>
      this == RideStatus.completed ||
      this == RideStatus.cancelled ||
      this == RideStatus.noShow;

  bool get isActionableByDriver =>
      this == RideStatus.assigned || isLive;

  /// The next status a driver can advance to, or null at a terminal/awaiting
  /// state. Mirrors is_legal_driver_transition() in the database — the client
  /// disables the button, the server enforces the rule.
  RideStatus? get driverNext => switch (this) {
        RideStatus.assigned => RideStatus.enRoute,
        RideStatus.enRoute => RideStatus.arrived,
        RideStatus.arrived => RideStatus.inProgress,
        RideStatus.inProgress => RideStatus.completed,
        _ => null,
      };

  /// The verb on the driver's advance button for the *current* status.
  String? get advanceLabel => switch (this) {
        RideStatus.assigned => 'Start driving',
        RideStatus.enRoute => 'Arrived at pickup',
        RideStatus.arrived => 'Start ride',
        RideStatus.inProgress => 'Complete ride',
        _ => null,
      };
}
