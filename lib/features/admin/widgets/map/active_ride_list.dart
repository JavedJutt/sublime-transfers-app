import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../data/models/ride.dart';
import '../../../../providers/map_providers.dart';
import '../../../../shared/widgets/display/status_chip.dart';
import 'fleet_map.dart';

/// The list of in-flight rides shown beside the map — and, when there is no
/// Maps key, *instead* of it. Each row is a compact, tappable summary with a
/// live freshness read on the driver's last fix. Selecting a row focuses the
/// map (via [selectedMapRideProvider]) and, on a second tap, opens the ride.
class ActiveRideList extends ConsumerWidget {
  const ActiveRideList({
    super.key,
    required this.rides,
    required this.onOpenRide,
    this.scrollable = true,
  });

  final List<Ride> rides;
  final ValueChanged<Ride> onOpenRide;

  /// The side panel scrolls itself; the mobile bottom sheet is already inside a
  /// scroll view, so it opts out to avoid a nested-scroll conflict.
  final bool scrollable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMapRideProvider);

    return ListView.separated(
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: rides.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final ride = rides[i];
        return _ActiveRideTile(
          ride: ride,
          selected: ride.id == selected,
          onTap: () {
            final notifier = ref.read(selectedMapRideProvider.notifier);
            if (ride.id == selected) {
              onOpenRide(ride);
            } else {
              notifier.select(ride.id);
            }
          },
        );
      },
    );
  }
}

class _ActiveRideTile extends StatelessWidget {
  const _ActiveRideTile({
    required this.ride,
    required this.selected,
    required this.onTap,
  });

  final Ride ride;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brassTint : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.brassLine : AppColors.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ride.driverName ?? 'Unassigned driver',
                      style: AppTypography.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusChip(
                    label: ride.status.label,
                    tone: ride.status.tone,
                    dense: true,
                    pulse: ride.status.isLive,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${ride.reference} · ${ride.customerName}',
                style: AppTypography.bodySm.copyWith(color: AppColors.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  const Icon(AppIcons.location, size: 13, color: AppColors.inkFaint),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ride.dropoffAddress,
                      style: AppTypography.caption.copyWith(color: AppColors.inkFaint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _Freshness(ride: ride),
            ],
          ),
        ),
      ),
    );
  }
}

/// A one-line read on how current the driver's position is: live (green dot),
/// stale ("last seen 12m ago", amber), or never located ("no location yet").
class _Freshness extends StatelessWidget {
  const _Freshness({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    if (!ride.hasDriverLocation || ride.driverLastLocationAt == null) {
      return _dot(AppColors.inkFaint, 'No location yet');
    }
    final age = DateTime.now().difference(ride.driverLastLocationAt!);
    if (age <= staleAfter) {
      return _dot(AppColors.success, 'Live');
    }
    return _dot(
      AppColors.warning,
      'Last seen ${Dates.relativeTime(ride.driverLastLocationAt!)}',
    );
  }

  Widget _dot(Color color, String label) => Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: AppTypography.caption.copyWith(color: color)),
        ],
      );
}
