import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import 'notification_service.dart';

/// The current [NotificationService]: in-app alerts over Supabase realtime.
///
/// No OS-level push — a driver sees new offers while the app is foregrounded.
/// The FCM implementation (background delivery) slots in behind the same
/// interface in the push phase.
class RealtimeNotificationService implements NotificationService {
  RealtimeNotificationService(this._repository);

  final NotificationRepository _repository;

  @override
  Future<void> initialize() async {
    // Nothing to prepare — realtime needs no permission and no device token.
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
