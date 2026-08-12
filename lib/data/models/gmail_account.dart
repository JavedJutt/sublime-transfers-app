/// A connected Gmail mailbox, as read through the `admin_gmail_accounts` view.
/// The OAuth token ciphertext is never projected here — only the status a human
/// needs to see whether ingestion is healthy.
class GmailAccount {
  const GmailAccount({
    required this.id,
    required this.emailAddress,
    required this.isActive,
    required this.isWatching,
    required this.createdAt,
    this.adminId,
    this.adminName,
    this.watchExpiration,
    this.lastSyncAt,
    this.lastError,
  });

  final String id;
  final String emailAddress;
  final bool isActive;
  final bool isWatching;
  final DateTime createdAt;
  final String? adminId;
  final String? adminName;
  final DateTime? watchExpiration;
  final DateTime? lastSyncAt;
  final String? lastError;

  bool get hasError => lastError != null && lastError!.isNotEmpty;

  /// Healthy = active, watching, and no recorded error.
  bool get isHealthy => isActive && isWatching && !hasError;

  static DateTime? _t(dynamic v) =>
      v == null ? null : DateTime.parse(v as String).toLocal();

  factory GmailAccount.fromMap(Map<String, dynamic> m) => GmailAccount(
        id: m['id'] as String,
        emailAddress: m['email_address'] as String,
        isActive: m['is_active'] as bool? ?? true,
        isWatching: m['is_watching'] as bool? ?? false,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        adminId: m['admin_id'] as String?,
        adminName: m['admin_name'] as String?,
        watchExpiration: _t(m['watch_expiration']),
        lastSyncAt: _t(m['last_sync_at']),
        lastError: m['last_error'] as String?,
      );
}
