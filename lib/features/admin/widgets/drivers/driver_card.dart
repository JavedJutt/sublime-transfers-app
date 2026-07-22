import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../data/repositories/driver_repository.dart';
import '../../../../shared/widgets/display/app_avatar.dart';
import '../../../../shared/widgets/display/app_card.dart';
import '../../../../shared/widgets/display/status_chip.dart';

/// A driver row for the drivers list. Shows identity, vehicle, approval status,
/// and an on-duty indicator.
class DriverCard extends StatelessWidget {
  const DriverCard({super.key, required this.driver, this.onTap, this.trailing});

  final DriverListItem driver;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          AppAvatar(
            name: driver.fullName,
            imageUrl: driver.avatarUrl,
            size: AppAvatarSize.lg,
            badge: driver.isApproved && driver.isOnDuty
                ? Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driver.fullName, style: AppTypography.h3),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(AppIcons.vehicle, size: 13, color: AppColors.inkMuted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        [
                          if (driver.vehicleType != null) driver.vehicleType!.label,
                          if (driver.vehiclePlate != null) driver.vehiclePlate!,
                        ].join(' · ').isEmpty
                            ? 'No vehicle on file'
                            : [
                                if (driver.vehicleType != null) driver.vehicleType!.label,
                                if (driver.vehiclePlate != null) driver.vehiclePlate!,
                              ].join(' · '),
                        style: AppTypography.bodySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          trailing ??
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusChip(
                    label: driver.approvalStatus.label,
                    tone: driver.approvalStatus.tone,
                    dense: true,
                  ),
                  if (driver.isApproved) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(driver.isOnDuty ? 'On duty' : 'Off duty',
                        style: AppTypography.caption.copyWith(
                          color: driver.isOnDuty ? AppColors.success : AppColors.inkFaint,
                        )),
                  ],
                ],
              ),
        ],
      ),
    );
  }
}
