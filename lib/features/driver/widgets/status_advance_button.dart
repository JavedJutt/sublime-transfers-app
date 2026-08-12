import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../data/models/ride_status.dart';
import '../../../shared/widgets/buttons/app_button.dart';

/// The driver's one big action: advance the ride to its next status. Sized XL
/// because it's tapped one-handed, often in motion, and it's the single most
/// important control in the app. The label speaks the verb for the *current*
/// state ("Start driving", "Arrived at pickup", …) so there's never a question
/// of what the tap does.
class StatusAdvanceButton extends StatelessWidget {
  const StatusAdvanceButton({
    super.key,
    required this.status,
    required this.onAdvance,
    this.busy = false,
  });

  final RideStatus status;
  final VoidCallback onAdvance;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final next = status.driverNext;
    final label = status.advanceLabel;

    // Terminal / non-actionable states have nothing to advance to.
    if (next == null || label == null) {
      if (status.isClosed) {
        return _ClosedNote(status: status);
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton.primary(
          label: label,
          icon: _iconFor(next),
          size: AppButtonSize.xl,
          fullWidth: true,
          isLoading: busy,
          onPressed: busy ? null : onAdvance,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(AppIcons.location, size: 13, color: AppColors.inkFaint),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Your location is recorded with each update',
              style: AppTypography.caption.copyWith(color: AppColors.inkFaint),
            ),
          ],
        ),
      ],
    );
  }

  IconData _iconFor(RideStatus next) => switch (next) {
        RideStatus.enRoute => AppIcons.navigate,
        RideStatus.arrived => AppIcons.pickup,
        RideStatus.inProgress => AppIcons.ride,
        RideStatus.completed => AppIcons.check,
        _ => AppIcons.arrowRight,
      };
}

class _ClosedNote extends StatelessWidget {
  const _ClosedNote({required this.status});

  final RideStatus status;

  @override
  Widget build(BuildContext context) {
    final done = status == RideStatus.completed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: done ? AppColors.successTint : AppColors.surfaceSunk,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            done ? AppIcons.success : AppIcons.info,
            size: 20,
            color: done ? AppColors.success : AppColors.inkMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              done ? 'Ride completed. Nice work.' : 'This ride is ${status.label.toLowerCase()}.',
              style: AppTypography.bodyStrong.copyWith(
                color: done ? AppColors.success : AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
