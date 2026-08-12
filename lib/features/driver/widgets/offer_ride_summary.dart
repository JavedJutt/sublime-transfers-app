import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/ride.dart';

/// The shared body of an offer or broadcast card: the time, the route, and the
/// facts a driver weighs before accepting — passengers, luggage, and the fare.
class OfferRideSummary extends StatelessWidget {
  const OfferRideSummary({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(Dates.time.format(ride.pickupAt), style: AppTypography.h2),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                ride.customerName,
                style: AppTypography.body.copyWith(color: AppColors.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _meta(AppIcons.passengers, '${ride.passengers}'),
            _meta(AppIcons.luggage, '${ride.luggage}'),
            if (ride.isAirportPickup) _meta(AppIcons.flight, ride.flightNumber!),
            if (ride.fareAmount != null)
              Text(
                Money.format(ride.fareAmount, currency: ride.fareCurrency),
                style: AppTypography.bodyStrong.copyWith(color: AppColors.brass),
              ),
          ],
        ),
      ],
    );
  }

  Widget _meta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.inkFaint),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.bodySm),
      ],
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
