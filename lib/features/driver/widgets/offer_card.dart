import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/ride.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_card.dart';
import 'offer_ride_summary.dart';

/// A direct offer sent to this driver: accept it and it becomes theirs, or
/// decline (with an optional reason) and it returns to the dispatcher. Both
/// actions are prominent — an offer is a decision, not a passive notification.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.ride,
    required this.onAccept,
    required this.onDecline,
    required this.onTap,
    this.busy = false,
  });

  final Ride ride;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      accentEdge: AppColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.assignDirect,
                  size: 16, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Offered to you',
                style: AppTypography.eyebrow.copyWith(color: AppColors.info),
              ),
              const Spacer(),
              Text(
                Dates.relativeDay(ride.pickupAt),
                style: AppTypography.bodySm.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OfferRideSummary(ride: ride),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Decline',
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  onPressed: busy ? null : onDecline,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton.primary(
                  label: 'Accept',
                  icon: AppIcons.check,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  isLoading: busy,
                  onPressed: busy ? null : onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
