import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/gmail_account.dart';
import '../../../providers/review_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_card.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/display/status_chip.dart';
import '../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/layout/max_width_body.dart';

/// Connect and monitor the Gmail mailboxes bookings arrive in. Each admin can
/// link their own inbox; a failed sync surfaces here (and on the dashboard) so
/// it never goes unnoticed.
class GmailSettingsScreen extends ConsumerWidget {
  const GmailSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(gmailAccountsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(gmailAccountsProvider);
          await ref.read(gmailAccountsProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: MaxWidthBody(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'Gmail ingestion',
                  subtitle: 'Bookings emailed to a connected mailbox are parsed '
                      'into rides automatically.',
                  action: AppButton.primary(
                    label: 'Connect mailbox',
                    icon: AppIcons.add,
                    onPressed: () => _connect(context, ref),
                  ),
                ),
                AsyncCollectionView<GmailAccount>(
                  value: accounts,
                  onRetry: () => ref.invalidate(gmailAccountsProvider),
                  empty: () => EmptyState(
                    icon: AppIcons.mailbox,
                    title: 'No mailbox connected',
                    message: 'Connect a Gmail account and its booking emails '
                        'will start flowing into the review queue and calendar.',
                    tone: EmptyStateTone.accent,
                    action: AppButton.primary(
                      label: 'Connect mailbox',
                      icon: AppIcons.add,
                      onPressed: () => _connect(context, ref),
                    ),
                  ),
                  data: (items) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final a in items) ...[
                        _MailboxCard(
                          account: a,
                          onDisconnect: () => _disconnect(context, ref, a),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _connect(BuildContext context, WidgetRef ref) async {
    try {
      final url = await ref.read(gmailRepositoryProvider).startOAuth();
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (!context.mounted) return;
      // The OAuth function isn't live until the Gmail client is configured.
      AppSnackbar.show(
        context,
        message: 'Mailbox connection isn\'t available yet — the Gmail OAuth '
            'client still needs to be configured.',
        tone: SnackTone.warning,
      );
    }
  }

  Future<void> _disconnect(
    BuildContext context,
    WidgetRef ref,
    GmailAccount account,
  ) async {
    try {
      await ref.read(gmailRepositoryProvider).disconnect(account.id);
      ref.invalidate(gmailAccountsProvider);
      if (!context.mounted) return;
      AppSnackbar.success(context, 'Mailbox disconnected');
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.show(context,
          message: 'Couldn\'t disconnect right now', tone: SnackTone.warning);
    }
  }
}

class _MailboxCard extends StatelessWidget {
  const _MailboxCard({required this.account, required this.onDisconnect});

  final GmailAccount account;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.mailbox, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(account.emailAddress, style: AppTypography.bodyStrong),
              ),
              _healthChip(),
            ],
          ),
          if (account.adminName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Linked by ${account.adminName}',
                style: AppTypography.caption.copyWith(color: AppColors.inkFaint)),
          ],
          if (account.hasError) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(AppIcons.syncFailed, size: 15, color: AppColors.danger),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(account.lastError!,
                        style: AppTypography.bodySm
                            .copyWith(color: AppColors.danger)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  account.lastSyncAt == null
                      ? 'No sync yet'
                      : 'Last sync ${Dates.relativeTime(account.lastSyncAt!)}',
                  style: AppTypography.caption.copyWith(color: AppColors.inkFaint),
                ),
              ),
              AppButton(
                label: 'Disconnect',
                size: AppButtonSize.sm,
                onPressed: onDisconnect,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _healthChip() {
    if (!account.isActive) {
      return const StatusChip(label: 'Inactive', tone: StatusTone.dormant, dense: true);
    }
    if (account.hasError) {
      return const StatusChip(label: 'Sync failed', tone: StatusTone.urgent, dense: true);
    }
    if (account.isWatching) {
      return const StatusChip(label: 'Active', tone: StatusTone.complete, dense: true);
    }
    return const StatusChip(label: 'Connecting', tone: StatusTone.pending, dense: true);
  }
}
