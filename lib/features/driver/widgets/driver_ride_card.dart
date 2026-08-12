import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/ride.dart';
import '../../../shared/widgets/display/app_card.dart';
import '../../../shared/widgets/display/status_chip.dart';

/// A ride card in the driver's day list. Built for a phone held one-handed:
/// the pickup time leads, the route reads top to bottom, and a live ride wears
/// a brass accent edge so it stands out in a day's column.
class DriverRideCard extends StatelessWidget {
  const DriverRideCard({super.key, required this.ride, this.onTap});

  final Ride ride;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = ride.status.tone;
    final live = ride.status.isLive;

    return AppCard(
      onTap: onTap,
      accentEdge: live ? AppColors.brass : tone.foreground,
      semanticLabel: '${Dates.time.format(ride.pickupAt)} ride for '
          '${ride.customerName}, ${ride.status.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Dates.time.format(ride.pickupAt),
                    style: AppTypography.h2.copyWith(height: 1.0),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Dates.relativeTime(ride.pickupAt),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.inkFaint),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.customerName,
                      style: AppTypography.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ride.isAirportPickup) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(AppIcons.flight,
                              size: 12, color: AppColors.inkFaint),
                          const SizedBox(width: 4),
                          Text(ride.flightNumber!,
                              style: AppTypography.mono.copyWith(fontSize: 11)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: ride.status.label,
                tone: tone,
                dense: true,
                pulse: live,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _RoutePoint(
            icon: AppIcons.pickup,
            color: AppColors.brass,
            address: ride.pickupAddress,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 7),
            child: Container(width: 2, height: 12, color: AppColors.line),
          ),
          _RoutePoint(
            icon: AppIcons.dropoff,
            color: AppColors.ink,
            address: ride.dropoffAddress,
          ),
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.icon,
    required this.color,
    required this.address,
  });

  final IconData icon;
  final Color color;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            address,
            style: AppTypography.bodySm,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
