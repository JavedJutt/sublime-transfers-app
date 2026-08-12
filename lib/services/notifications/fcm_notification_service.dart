import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import 'notification_service.dart';

/// Firebase Cloud Messaging implementation — the OS-level push path.
///
/// STUBBED. The in-app stream and read-state still work (delegated to the
/// realtime repository), but [initialize] does not yet request notification
/// permission or register a device token. Wiring this up is the push phase:
///   1. `firebase_messaging` requestPermission + getToken
///   2. upsert the token into `device_tokens`
///   3. a Supabase edge function sends via FCM on assign/broadcast
///
/// It is deliberately not thrown-on so the app can select this implementation
/// early without breaking; only the background-delivery surface is inert.
class FcmNotificationService implements NotificationService {
  FcmNotificationService(this._repository);

  final NotificationRepository _repository;

  @override
  Future<void> initialize() async {
    // TODO(push-phase): request FCM permission, register device token in
    // device_tokens, and wire foreground message presentation via
    // flutter_local_notifications. Until then, in-app realtime alerts carry the
    // experience and this is a no-op rather than a failure.
  }

  @override
  Stream<List<AppNotification>> watch() => _repository.watch();

  @override
  Future<void> markRead(String id) => _repository.markRead(id);

  @override
  Future<void> markAllRead() => _repository.markAllRead();

  @override
  Future<void> dispose() async {}
}
