import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../providers/driver_app_providers.dart';

/// A slim banner shown above the driver's nav whenever they're offline or have
/// actions waiting to sync. Reassuring, not alarming — a driver in a tunnel is
/// a normal state, and their queued status updates are safe.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).value ?? true;
    final pending = ref.watch(pendingSyncCountProvider).value ?? 0;

    // Nothing to say when online and fully synced.
    if (online && pending == 0) return const SizedBox.shrink();

    final (bg, fg, icon, text) = !online
        ? (
            AppColors.warningTint,
            AppColors.warning,
            AppIcons.offline,
            pending > 0
                ? 'Offline — $pending update${pending == 1 ? '' : 's'} will send when you\'re back'
                : 'Offline — showing your last synced rides',
          )
        : (
            AppColors.infoTint,
            AppColors.info,
            AppIcons.refresh,
            'Syncing $pending update${pending == 1 ? '' : 's'}…',
          );

    return Material(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.bodySm.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (online && pending > 0)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
