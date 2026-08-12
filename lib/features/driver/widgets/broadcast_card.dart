import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../data/models/ride.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_card.dart';
import 'offer_ride_summary.dart';

/// An open broadcast in the shared pool — offered to every on-duty driver,
/// first to claim wins. The single "Claim ride" button makes the stakes clear;
/// losing the race is handled upstream as a calm informational message, so this
/// card just presents the opportunity.
class BroadcastCard extends StatelessWidget {
  const BroadcastCard({
    super.key,
    required this.ride,
    required this.onClaim,
    required this.onTap,
    this.busy = false,
  });

  final Ride ride;
  final VoidCallback? onClaim;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      accentEdge: AppColors.brass,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.broadcast, size: 16, color: AppColors.brass),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Open to all drivers',
                style: AppTypography.eyebrow.copyWith(color: AppColors.brass),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OfferRideSummary(ride: ride),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: 'Claim ride',
            icon: AppIcons.broadcast,
            size: AppButtonSize.lg,
            fullWidth: true,
            isLoading: busy,
            onPressed: busy ? null : onClaim,
          ),
        ],
      ),
    );
  }
}
