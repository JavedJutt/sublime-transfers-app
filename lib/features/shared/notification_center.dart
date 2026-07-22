import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_colors.dart';
import '../../core/design/app_icons.dart';
import '../../core/design/app_spacing.dart';
import '../../core/design/app_typography.dart';
import '../../core/router/routes.dart';
import '../../core/utils/date_x.dart';
import '../../data/models/app_notification.dart';
import '../../providers/auth_providers.dart';
import '../../providers/notification_providers.dart';
import '../../shared/widgets/async/async_value_view.dart';
import '../../shared/widgets/buttons/app_button.dart';
import '../../shared/widgets/feedback/empty_state.dart';

/// A bell with an unread badge that opens the notification centre. Shared by
/// both roles' chrome.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(unread > 0 ? AppIcons.notificationUnread : AppIcons.notification),
          tooltip: 'Notifications',
          onPressed: () => NotificationCenterSheet.show(context),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: const BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              constraints: const BoxConstraints(minWidth: 15),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkInverse,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The notification centre, shown as a right-side sheet on wide screens and a
/// bottom sheet on mobile.
class NotificationCenterSheet {
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (_) => const _NotificationSheet(),
    );
  }
}

class _NotificationSheet extends ConsumerWidget {
  const _NotificationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lineStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Text('Notifications', style: AppTypography.h2),
                    const Spacer(),
                    if (unread > 0)
                      AppButton.ghost(
                        label: 'Mark all read',
                        size: AppButtonSize.sm,
                        onPressed: () =>
                            ref.read(notificationServiceProvider).markAllRead(),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: AsyncCollectionView<AppNotification>(
                  value: notifications,
                  onRetry: () => ref.invalidate(notificationsProvider),
                  empty: () => const EmptyState(
                    icon: AppIcons.notification,
                    title: 'All caught up',
                    message: 'New offers and ride updates will appear here.',
                    tone: EmptyStateTone.positive,
                  ),
                  data: (items) => ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _NotificationTile(item: items[i]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final AppNotification item;

  (IconData, Color, Color) get _visual => switch (item.type) {
        'offer' => (AppIcons.offers, AppColors.brass, AppColors.brassTint),
        'offer_declined' => (AppIcons.warning, AppColors.danger, AppColors.dangerTint),
        'driver_pending' => (AppIcons.addDriver, AppColors.info, AppColors.infoTint),
        'parse_review' => (AppIcons.reviewQueue, AppColors.warning, AppColors.warningTint),
        'gmail_sync_failed' => (AppIcons.syncFailed, AppColors.danger, AppColors.dangerTint),
        _ => (AppIcons.info, AppColors.info, AppColors.infoTint),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color, bg) = _visual;
    final role = ref.watch(roleProvider);

    return Material(
      color: item.isUnread ? AppColors.brassTint.withValues(alpha: 0.4) : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (item.isUnread) {
            ref.read(notificationServiceProvider).markRead(item.id);
          }
          if (item.rideId != null && role != null) {
            Navigator.of(context).pop();
            final path = role.isAdmin
                ? R.adminRide(item.rideId!)
                : R.driverRide(item.rideId!);
            context.push(path);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.title, style: AppTypography.bodyStrong),
                        ),
                        Text(Dates.relativeTime(item.createdAt),
                            style: AppTypography.caption),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(item.body,
                        style: AppTypography.bodySm.copyWith(color: AppColors.inkMuted)),
                  ],
                ),
              ),
              if (item.isUnread)
                Container(
                  margin: const EdgeInsets.only(left: AppSpacing.sm, top: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.brass,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
