import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../providers/assignment_providers.dart';
import '../../../providers/driver_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_avatar.dart';
import '../../../shared/widgets/display/app_card.dart';
import '../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../shared/widgets/feedback/confirm_dialog.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/layout/max_width_body.dart';

/// Review pending driver applications. Approve makes a driver eligible for
/// rides; reject records a reason and notifies them. Both go through the
/// admin-guarded `review_driver` RPC.
class DriverApprovalsScreen extends ConsumerWidget {
  const DriverApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingDriversProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver approvals'),
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin/drivers'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pendingDriversProvider);
          await ref.read(pendingDriversProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: MaxWidthBody(
            maxWidth: 720,
            child: AsyncCollectionView<DriverListItem>(
              value: pending,
              onRetry: () => ref.invalidate(pendingDriversProvider),
              empty: () => const Padding(
                padding: EdgeInsets.only(top: AppSpacing.x5),
                child: EmptyState(
                  icon: AppIcons.approve,
                  title: 'No pending approvals',
                  message: 'Every driver who applied has been reviewed.',
                  tone: EmptyStateTone.positive,
                ),
              ),
              data: (list) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final driver in list) ...[
                    _ApprovalTile(driver: driver),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.x4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApprovalTile extends ConsumerWidget {
  const _ApprovalTile({required this.driver});

  final DriverListItem driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(approvalControllerProvider).isLoading;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: driver.fullName, size: AppAvatarSize.lg),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.fullName, style: AppTypography.h3),
                    Text(driver.email, style: AppTypography.bodySm),
                    if (driver.createdAt != null)
                      Text('Applied ${Dates.relativeTime(driver.createdAt!)}',
                          style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: [
              _detail(AppIcons.phone, driver.phone ?? 'No phone'),
              _detail(AppIcons.vehicle, driver.vehicleType?.label ?? 'No vehicle'),
              if (driver.vehiclePlate != null)
                _detail(AppIcons.ride, driver.vehiclePlate!),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Reject',
                  variant: AppButtonVariant.secondary,
                  onPressed: busy ? null : () => _reject(context, ref),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: AppButton.primary(
                  label: 'Approve',
                  icon: AppIcons.approve,
                  isLoading: busy,
                  onPressed: busy ? null : () => _approve(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.xs),
          Text(text, style: AppTypography.bodySm),
        ],
      );

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(approvalControllerProvider.notifier);
    final ok = await controller.review(driverId: driver.id, approve: true);
    if (!context.mounted) return;
    ok
        ? AppSnackbar.success(context, '${driver.fullName} approved')
        : AppSnackbar.showFailure(context, controller.errorOrNull!);
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Reject ${driver.fullName}?',
      message: 'They\'ll be notified and won\'t be able to receive rides.',
      confirmLabel: 'Reject',
      destructive: true,
      icon: AppIcons.warning,
    );
    if (confirmed != true || !context.mounted) return;
    final controller = ref.read(approvalControllerProvider.notifier);
    final ok = await controller.review(driverId: driver.id, approve: false);
    if (!context.mounted) return;
    ok
        ? AppSnackbar.success(context, 'Application rejected')
        : AppSnackbar.showFailure(context, controller.errorOrNull!);
  }
}
