import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/error_mapper.dart';
import '../models/app_notification.dart';

/// The in-app notification centre's data source. Reads the caller's own
/// notifications (RLS scopes them to `user_id = auth.uid()`) and streams live
/// inserts so a new offer or a declined ride surfaces without a refresh.
class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  Future<List<AppNotification>> fetch({int limit = 50}) =>
      ErrorMapper.guard(() async {
        final rows = await _client
            .from('notifications')
            .select()
            .order('created_at', ascending: false)
            .limit(limit);
        return rows.map(AppNotification.fromMap).toList();
      });

  /// Live list: an initial fetch, then Supabase realtime pushes the ordered
  /// set. `stream()` handles inserts, updates (read receipts), and deletes.
  Stream<List<AppNotification>> watch({int limit = 50}) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .limit(limit)
        .map((rows) {
          final list = rows.map(AppNotification.fromMap).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<void> markRead(String id) => ErrorMapper.guard(() async {
        await _client
            .from('notifications')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', id);
      });

  Future<void> markAllRead() => ErrorMapper.guard(() async {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) return;
        await _client
            .from('notifications')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .eq('user_id', userId)
            .isFilter('read_at', null);
      });
}
