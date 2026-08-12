import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/error_mapper.dart';
import '../models/inbound_email.dart';

/// The admin's review queue: inbound emails the parser couldn't confidently
/// turn into rides. Reads go through the `admin_emails` view; the promote/reject
/// actions go through security-definer RPCs; a re-parse re-invokes the parser
/// Edge Function.
class ReviewQueueRepository {
  ReviewQueueRepository(this._client);

  final SupabaseClient _client;

  /// Emails awaiting a human decision, oldest first (work the backlog in order).
  Future<List<InboundEmail>> pending() => ErrorMapper.guard(() async {
        final rows = await _client
            .from('admin_emails')
            .select()
            .eq('parse_status', 'needs_review')
            .order('received_at', ascending: true, nullsFirst: false)
            .order('created_at', ascending: true);
        return rows.map(InboundEmail.fromMap).toList();
      });

  /// The full history (any status), most recent first — for an "all mail" tab.
  Future<List<InboundEmail>> all({int limit = 100}) => ErrorMapper.guard(() async {
        final rows = await _client
            .from('admin_emails')
            .select()
            .order('created_at', ascending: false)
            .limit(limit);
        return rows.map(InboundEmail.fromMap).toList();
      });

  Future<InboundEmail?> byId(String id) => ErrorMapper.guard(() async {
        final rows =
            await _client.from('admin_emails').select().eq('id', id).limit(1);
        return rows.isEmpty ? null : InboundEmail.fromMap(rows.first);
      });

  /// Promote a reviewed email into a ride using the (possibly corrected)
  /// payload. Returns the new ride id.
  Future<String> import(String emailId, Map<String, dynamic> payload) =>
      ErrorMapper.guard(() async {
        final row = await _client.rpc('import_reviewed_email', params: {
          'p_email_id': emailId,
          'p_payload': payload,
        });
        // The RPC returns the rides row; pull the id out.
        if (row is Map && row['id'] != null) return row['id'] as String;
        if (row is List && row.isNotEmpty) {
          return (row.first as Map)['id'] as String;
        }
        return '';
      });

  Future<void> reject(String emailId, {String? reason}) =>
      ErrorMapper.guard(() async {
        await _client.rpc('reject_inbound_email', params: {
          'p_email_id': emailId,
          'p_reason': reason,
        });
      });

  /// Re-run the parser on an email (e.g. after the OpenAI key was added, or a
  /// transient failure). Fire-and-forget from the UI's perspective; the row
  /// updates in place and the caller re-fetches.
  Future<void> reparse(String emailId) => ErrorMapper.guard(() async {
        await _client.functions.invoke(
          'parse-booking-email',
          body: {'email_id': emailId},
        );
      });
}
