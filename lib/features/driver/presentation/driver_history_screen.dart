import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/ride.dart';
import '../../../providers/driver_app_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/ride_card_skeleton.dart';
import '../widgets/driver_ride_card.dart';

/// The driver's completed work, grouped by day. Read-only — a record they can
/// scroll back through, not something they act on.
class DriverHistoryScreen extends ConsumerWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(driverHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(R.driverHome),
        ),
        title: Text('History', style: AppTypography.h3),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(driverHistoryProvider);
          await ref.read(driverHistoryProvider.future);
        },
        child: AsyncCollectionView<Ride>(
          value: historyAsync,
          onRetry: () => ref.invalidate(driverHistoryProvider),
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [
              RideCardSkeleton(),
              SizedBox(height: AppSpacing.sm),
              RideCardSkeleton(),
            ],
          ),
          empty: () => ListView(
            children: const [
              SizedBox(height: AppSpacing.x6),
              EmptyState(
                icon: AppIcons.history,
                title: 'No finished rides yet',
                message: 'Rides you complete will be kept here.',
              ),
            ],
          ),
          data: (rides) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.x5,
            ),
            children: _buildGrouped(context, rides),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGrouped(BuildContext context, List<Ride> rides) {
    final widgets = <Widget>[];
    String? lastKey;
    for (final ride in rides) {
      final key = ride.pickupAt.dayKey;
      if (key != lastKey) {
        widgets.add(Padding(
          padding: EdgeInsets.only(
            top: lastKey == null ? 0 : AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            Dates.relativeDay(ride.pickupAt),
            style: AppTypography.eyebrow,
          ),
        ));
        lastKey = key;
      }
      widgets.add(DriverRideCard(
        ride: ride,
        onTap: () => context.push(R.driverRide(ride.id)),
      ));
      widgets.add(const SizedBox(height: AppSpacing.sm));
    }
    return widgets;
  }
}
