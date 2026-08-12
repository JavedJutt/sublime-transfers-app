import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/env/app_env.dart';
import '../../../core/router/routes.dart';
import '../../../data/models/ride.dart';
import '../../../providers/map_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../widgets/map/active_ride_list.dart';
import '../widgets/map/fleet_map.dart';

/// The admin live map: where every in-flight ride is, right now.
///
/// Two hard rules from the spec shape this screen. First, **a missing or
/// invalid Maps key never shows a blank grey rectangle** — it falls back to the
/// same active-ride list that flanks the map, so the feature still works
/// headless. Second, the map and the list read from one provider, so a driver
/// advancing a status moves their marker *and* re-sorts the list in one beat.
class LiveMapScreen extends ConsumerWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(activeRidesProvider);
    final isWide = !AppBreakpoints.of(context).isMobile;

    void openRide(Ride ride) => context.push(R.adminRide(ride.id));

    return Scaffold(
      body: Column(
        children: [
          _MapHeader(count: rides.value?.length ?? 0),
          const Divider(height: 1),
          Expanded(
            child: AsyncCollectionView<Ride>(
              value: rides,
              onRetry: () => ref.invalidate(activeRidesProvider),
              empty: () => const EmptyState(
                icon: AppIcons.liveMap,
                title: 'No rides in progress',
                message: 'Assigned and in-flight rides appear here with their '
                    "driver's live position.",
              ),
              data: (list) => AppEnv.hasMapsKey
                  ? _MapLayout(rides: list, isWide: isWide, onOpenRide: openRide)
                  : _ListFallback(rides: list, onOpenRide: openRide),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends ConsumerWidget {
  const _MapHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Live map', style: AppTypography.h2),
              Text(
                count == 1 ? '1 ride in progress' : '$count rides in progress',
                style: AppTypography.bodySm.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(AppIcons.refresh),
            onPressed: () => ref.invalidate(activeRidesProvider),
          ),
        ],
      ),
    );
  }
}

/// Map + list, side by side on a wide window and stacked on a phone.
class _MapLayout extends StatelessWidget {
  const _MapLayout({
    required this.rides,
    required this.isWide,
    required this.onOpenRide,
  });

  final List<Ride> rides;
  final bool isWide;
  final ValueChanged<Ride> onOpenRide;

  @override
  Widget build(BuildContext context) {
    final map = FleetMap(rides: rides);
    final list = ActiveRideList(rides: rides, onOpenRide: onOpenRide);

    if (isWide) {
      return Row(
        children: [
          Expanded(child: map),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 380,
            child: Container(color: AppColors.canvas, child: list),
          ),
        ],
      );
    }

    // Phone: map on top, a shorter scrollable list beneath it.
    return Column(
      children: [
        Expanded(flex: 3, child: map),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: Container(color: AppColors.canvas, child: list),
        ),
      ],
    );
  }
}

/// Shown when there is no Maps key: the active-ride list stands in for the map,
/// with a quiet banner explaining why. Never a blank grey rectangle.
class _ListFallback extends StatelessWidget {
  const _ListFallback({required this.rides, required this.onOpenRide});

  final List<Ride> rides;
  final ValueChanged<Ride> onOpenRide;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.infoTint,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              const Icon(AppIcons.info, size: 18, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Map view is unavailable — showing active rides as a list. '
                  'Add a Maps API key to enable the map.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ActiveRideList(rides: rides, onOpenRide: onOpenRide),
        ),
      ],
    );
  }
}
