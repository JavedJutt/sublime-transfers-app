import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/error_mapper.dart';
import '../models/gmail_account.dart';

/// Connected Gmail mailboxes and the actions to link/unlink them. Reads go
/// through the token-free `admin_gmail_accounts` view; connecting kicks off the
/// OAuth flow via an Edge Function that returns a Google consent URL.
class GmailRepository {
  GmailRepository(this._client);

  final SupabaseClient _client;

  Future<List<GmailAccount>> accounts() => ErrorMapper.guard(() async {
        final rows = await _client
            .from('admin_gmail_accounts')
            .select()
            .order('created_at', ascending: true);
        return rows.map(GmailAccount.fromMap).toList();
      });

  /// Whether any connected mailbox is reporting a sync error — drives the
  /// persistent dashboard/settings banner.
  Future<bool> hasSyncError() => ErrorMapper.guard(() async {
        final rows = await _client
            .from('admin_gmail_accounts')
            .select('id')
            .not('last_error', 'is', null)
            .eq('is_active', true)
            .limit(1);
        return rows.isNotEmpty;
      });

  /// Begin linking a mailbox: the Edge Function returns a Google consent URL to
  /// open in a browser. Available once the Gmail OAuth client is configured.
  Future<String> startOAuth() => ErrorMapper.guard(() async {
        final res = await _client.functions.invoke('gmail-oauth-start');
        final data = res.data;
        final url = data is Map ? data['url'] as String? : null;
        if (url == null || url.isEmpty) {
          throw StateError('No consent URL returned');
        }
        return url;
      });

  /// Stop ingesting from a mailbox. Deactivates it and (server-side) drops the
  /// Gmail watch.
  Future<void> disconnect(String accountId) => ErrorMapper.guard(() async {
        await _client.functions.invoke(
          'gmail-disconnect',
          body: {'account_id': accountId},
        );
      });
}
