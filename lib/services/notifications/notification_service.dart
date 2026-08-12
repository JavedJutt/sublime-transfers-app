import '../../data/models/app_notification.dart';

/// Abstraction over how a driver/admin is *delivered* alerts.
///
/// Two concerns sit behind this interface:
///   * the in-app centre (a live stream + read state) — implemented now over
///     Supabase realtime;
///   * OS-level push (waking a backgrounded app) — the FCM implementation,
///     stubbed until the push phase.
///
/// Feature code depends only on this interface, so swapping in FCM later is a
/// provider override, not a rewrite.
abstract interface class NotificationService {
  /// Prepare the service (request OS permission, register a device token).
  /// The realtime implementation is a no-op; the FCM one does real work.
  Future<void> initialize();

  /// Live, newest-first list of the current user's notifications.
  Stream<List<AppNotification>> watch();

  Future<void> markRead(String id);
  Future<void> markAllRead();

  /// Release resources (unsubscribe channels, cancel token refresh).
  Future<void> dispose();
}
