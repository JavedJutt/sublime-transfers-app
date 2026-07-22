import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../data/models/ride.dart';
import '../../../../shared/widgets/display/app_card.dart';
import '../../../../shared/widgets/display/status_chip.dart';

/// The ride card used in the list, calendar day view, and search results.
///
/// The status colour rides the card's left edge so a dispatcher can scan a
/// column of cards and read the mix at a glance without parsing each chip.
class RideCard extends StatelessWidget {
  const RideCard({
    super.key,
    required this.ride,
    this.onTap,
    this.dense = false,
    this.showDriver = true,
  });

  final Ride ride;
  final VoidCallback? onTap;
  final bool dense;
  final bool showDriver;

  @override
  Widget build(BuildContext context) {
    final tone = ride.status.tone;
    return AppCard(
      onTap: onTap,
      accentEdge: tone.foreground,
      padding: EdgeInsets.all(dense ? AppSpacing.md : AppSpacing.lg),
      semanticLabel:
          '${ride.reference}, ${Dates.time.format(ride.pickupAt)}, '
          '${ride.customerName}, ${ride.status.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time block — the primary scan anchor.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Dates.time.format(ride.pickupAt),
                      style: AppTypography.h3.copyWith(height: 1.1)),
                  Text(
                    ride.reference,
                    style: AppTypography.mono.copyWith(
                      fontSize: 11,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Container(width: 1, height: 34, color: AppColors.line),
              const SizedBox(width: AppSpacing.md),
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
                    const SizedBox(height: 1),
                    _RouteLine(ride: ride),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: ride.status.label,
                tone: tone,
                dense: true,
                pulse: ride.status.isLive,
              ),
            ],
          ),
          if (!dense) ...[
            const SizedBox(height: AppSpacing.md),
            _MetaRow(ride: ride, showDriver: showDriver),
          ],
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(AppIcons.pickup, size: 12, color: AppColors.inkMuted),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            ride.pickupAddress,
            style: AppTypography.bodySm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(AppIcons.arrowRight, size: 11, color: AppColors.inkFaint),
        ),
        Flexible(
          child: Text(
            ride.dropoffAddress,
            style: AppTypography.bodySm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.ride, required this.showDriver});

  final Ride ride;
  final bool showDriver;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _meta(AppIcons.passengers, '${ride.passengers}'),
      _meta(AppIcons.luggage, '${ride.luggage}'),
      if (ride.isAirportPickup) _meta(AppIcons.flight, ride.flightNumber!),
      if (ride.fareAmount != null)
        _meta(null, Money.format(ride.fareAmount, currency: ride.fareCurrency)),
    ];

    // The meta chips live in a Wrap inside an Expanded, so on a narrow card
    // they flow to a second line instead of overflowing; the driver label is
    // pinned to the trailing edge and ellipsizes.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: chips,
          ),
        ),
        if (showDriver) ...[
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  ride.isAssigned ? AppIcons.drivers : AppIcons.warning,
                  size: 13,
                  color: ride.isAssigned ? AppColors.inkMuted : AppColors.danger,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    ride.driverName ?? 'Unassigned',
                    style: AppTypography.bodySm.copyWith(
                      color:
                          ride.isAssigned ? AppColors.inkBody : AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _meta(IconData? icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: AppColors.inkFaint),
          const SizedBox(width: 3),
        ],
        Text(label, style: AppTypography.bodySm),
      ],
    );
  }
}
