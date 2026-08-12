import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/routes.dart';
import '../../../data/models/ride.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../providers/assignment_providers.dart';
import '../../../providers/driver_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_avatar.dart';
import '../../../shared/widgets/display/status_chip.dart';
import '../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../shared/widgets/feedback/empty_state.dart';

/// Assign a ride: pick a driver for a direct offer, or broadcast to everyone
/// on duty. Opened from the ride detail. Reassignment reuses this same sheet
/// with [isReassign] true.
class AssignmentSheet {
  static Future<void> show(
    BuildContext context, {
    required Ride ride,
    bool isReassign = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignmentSheetBody(ride: ride, isReassign: isReassign),
    );
  }
}

class _AssignmentSheetBody extends ConsumerWidget {
  const _AssignmentSheetBody({required this.ride, required this.isReassign});

  final Ride ride;
  final bool isReassign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivers = ref.watch(approvedDriversProvider);
    final busy = ref.watch(assignmentControllerProvider).isLoading;

    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isReassign ? 'Reassign ride' : 'Assign ride',
                            style: AppTypography.h2),
                        Text(ride.reference, style: AppTypography.bodySm),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Broadcast option, unless we're reassigning a specific driver.
            if (!isReassign)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: _BroadcastCard(
                  busy: busy,
                  onBroadcast: () => _broadcast(context, ref),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(isReassign ? 'Choose a driver' : 'Or assign directly',
                      style: AppTypography.label),
                  const Spacer(),
                  Text('Green = on duty', style: AppTypography.caption),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AsyncCollectionView<DriverListItem>(
                value: drivers,
                onRetry: () => ref.invalidate(approvedDriversProvider),
                empty: () => EmptyState(
                  icon: AppIcons.drivers,
                  title: 'No approved drivers',
                  message: 'Approve a driver before assigning rides.',
                  compact: true,
                  action: AppButton.ghost(
                    label: 'Go to approvals',
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go(R.adminDriverApprovals);
                    },
                  ),
                ),
                data: (list) => ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _DriverRow(
                    driver: list[i],
                    disabled: busy || list[i].id == ride.assignedDriverId,
                    isCurrent: list[i].id == ride.assignedDriverId,
                    onSelect: () => _assign(context, ref, list[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    DriverListItem driver,
  ) async {
    final controller = ref.read(assignmentControllerProvider.notifier);
    final ok = isReassign
        ? await controller.reassign(rideId: ride.id, driverId: driver.id)
        : await controller.assignDirect(rideId: ride.id, driverId: driver.id);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      AppSnackbar.success(
        context,
        isReassign
            ? 'Reassigned to ${driver.fullName}'
            : 'Offer sent to ${driver.fullName}',
      );
    } else {
      final err = controller.errorOrNull;
      if (err != null) AppSnackbar.showFailure(context, err);
    }
  }

  Future<void> _broadcast(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(assignmentControllerProvider.notifier);
    final ok = await controller.broadcast(ride.id);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      AppSnackbar.success(context, 'Broadcasting to on-duty drivers');
    } else {
      final err = controller.errorOrNull;
      if (err != null) AppSnackbar.showFailure(context, err);
    }
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({required this.busy, required this.onBroadcast});

  final bool busy;
  final VoidCallback onBroadcast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.brassTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brassLine),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.broadcast, size: 22, color: AppColors.brass),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Broadcast to all on-duty drivers',
                    style: AppTypography.bodyStrong),
                Text('First to accept gets the ride.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton(
            label: 'Broadcast',
            variant: AppButtonVariant.accentQuiet,
            size: AppButtonSize.sm,
            onPressed: busy ? null : onBroadcast,
          ),
        ],
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({
    required this.driver,
    required this.disabled,
    required this.isCurrent,
    required this.onSelect,
  });

  final DriverListItem driver;
  final bool disabled;
  final bool isCurrent;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: disabled ? null : onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              AppAvatar(
                name: driver.fullName,
                imageUrl: driver.avatarUrl,
                badge: driver.isOnDuty
                    ? Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.fullName, style: AppTypography.bodyStrong),
                    Text(
                      [
                        if (driver.vehicleType != null) driver.vehicleType!.label,
                        if (driver.vehiclePlate != null) driver.vehiclePlate!,
                      ].join(' · '),
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                const StatusChip(label: 'Current', tone: StatusTone.scheduled, dense: true)
              else if (!driver.isOnDuty)
                const StatusChip(label: 'Off duty', tone: StatusTone.dormant, dense: true)
              else
                const Icon(AppIcons.chevronRight, size: 18, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
