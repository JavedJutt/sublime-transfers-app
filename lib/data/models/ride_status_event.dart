import 'ride_status.dart';
import 'user_role.dart';

/// One entry in a ride's audit log. Mirrors `ride_status_events`.
///
/// The database writes two kinds of row for some changes: a rich RPC-authored
/// row (with captured location) and a safety-net trigger row. [isTriggerRow]
/// lets the timeline dedupe, preferring the RPC row.
class RideStatusEvent {
  const RideStatusEvent({
    required this.id,
    required this.rideId,
    required this.toStatus,
    required this.action,
    required this.createdAt,
    this.fromStatus,
    this.actorId,
    this.actorRole,
    this.actorName,
    this.driverId,
    this.lat,
    this.lng,
    this.accuracyM,
    this.capturedAt,
    this.note,
    this.metadata = const {},
  });

  final int id;
  final String rideId;
  final RideStatus? fromStatus;
  final RideStatus toStatus;
  final String action;
  final String? actorId;
  final UserRole? actorRole;

  /// Joined in by the repository from profiles; not a column on the table.
  final String? actorName;

  final String? driverId;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final DateTime? capturedAt;
  final String? note;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  bool get isTriggerRow => metadata['trigger'] == true;
  bool get isRpcRow => metadata['rpc'] == true;
  bool get hasLocation => lat != null && lng != null;
  bool get locationUnavailable => metadata['location_unavailable'] == true;

  factory RideStatusEvent.fromMap(Map<String, dynamic> m) => RideStatusEvent(
        id: (m['id'] as num).toInt(),
        rideId: m['ride_id'] as String,
        fromStatus: m['from_status'] == null
            ? null
            : RideStatus.fromWire(m['from_status'] as String),
        toStatus: RideStatus.fromWire(m['to_status'] as String),
        action: m['action'] as String,
        actorId: m['actor_id'] as String?,
        actorRole: m['actor_role'] == null
            ? null
            : UserRole.fromWire(m['actor_role'] as String),
        actorName: (m['actor'] as Map?)?['full_name'] as String?,
        driverId: m['driver_id'] as String?,
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        accuracyM: (m['accuracy_m'] as num?)?.toDouble(),
        capturedAt: m['captured_at'] == null
            ? null
            : DateTime.parse(m['captured_at'] as String).toLocal(),
        note: m['note'] as String?,
        metadata: (m['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );

  /// Human phrase for the timeline, e.g. "Assigned to a driver".
  String get actionLabel => switch (action) {
        'created' => 'Ride created',
        'assigned' => 'Assigned',
        'offer_accepted' => 'Offer accepted',
        'offer_declined' => 'Offer declined',
        'claimed' => 'Claimed from broadcast',
        'status_advanced' => toStatus.label,
        'reassigned' => 'Reassigned',
        'cancelled' => 'Cancelled',
        'edited' => 'Details edited',
        _ => action,
      };
}
