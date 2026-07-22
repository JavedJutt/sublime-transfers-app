import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_notification.dart';
import '../data/repositories/notification_repository.dart';
import '../data/sources/supabase_client_provider.dart';
import '../services/notifications/notification_service.dart';
import '../services/notifications/realtime_notification_service.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseClientProvider));
});

/// The active notification delivery service. Swap this override for the FCM
/// implementation in the push phase — nothing else changes.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return RealtimeNotificationService(ref.watch(notificationRepositoryProvider));
});

/// Live notifications for the current user, newest first.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationServiceProvider).watch();
});

/// Unread count for the bell badge.
final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).value ?? const [];
  return list.where((n) => n.isUnread).length;
});
