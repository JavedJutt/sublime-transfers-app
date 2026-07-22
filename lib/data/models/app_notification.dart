/// An in-app notification. Mirrors the `notifications` table. Written by the
/// dispatch RPCs (offer, decline, claim, reassign) and surfaced in the
/// notification centre.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.rideId,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? rideId;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        type: m['type'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        rideId: m['ride_id'] as String?,
        readAt: m['read_at'] == null
            ? null
            : DateTime.parse(m['read_at'] as String).toLocal(),
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
