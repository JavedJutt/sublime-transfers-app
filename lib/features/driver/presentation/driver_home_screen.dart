import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/ride.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/driver_app_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/display/status_chip.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/ride_card_skeleton.dart';
import '../../shared/notification_center.dart';
import '../widgets/day_strip_selector.dart';
import '../widgets/driver_ride_card.dart';

/// The driver's home: a day strip, a hero card for any ride in progress, and
/// the day's assigned rides. Offline, this shows the last-synced rides behind
/// the shell's banner rather than an error — a driver in a tunnel still needs
/// their schedule.
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(driverSelectedDayProvider);
    final ridesAsync = ref.watch(driverDayRidesProvider);
    final activeAsync = ref.watch(driverActiveRideProvider);
    final fullName = ref.watch(currentUserProvider).value?.fullName;
    final firstName =
        (fullName == null || fullName.trim().isEmpty) ? null : fullName.trim().split(' ').first;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              firstName == null ? 'Your day' : 'Hello, $firstName',
              style: AppTypography.h3,
            ),
            Text(
              Dates.fullDate.format(DateTime.now()),
              style: AppTypography.caption.copyWith(color: AppColors.inkFaint),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.history),
            tooltip: 'Ride history',
            onPressed: () => context.push(R.driverHistory),
          ),
          const NotificationBell(),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(driverDayRidesProvider);
          ref.invalidate(driverActiveRideProvider);
          await ref.read(driverDayRidesProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.x5),
          children: [
            DayStripSelector(
              selected: day,
              onSelect: (d) =>
                  ref.read(driverSelectedDayProvider.notifier).set(d),
            ),
            // The active-ride hero sits above the day list regardless of which
            // day is selected — a ride in progress is always the priority.
            activeAsync.maybeWhen(
              data: (active) => active == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.xs,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: _ActiveRideHero(ride: active),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: AsyncCollectionView<Ride>(
                value: ridesAsync,
                onRetry: () => ref.invalidate(driverDayRidesProvider),
                loading: () => const Column(
                  children: [
                    RideCardSkeleton(),
                    SizedBox(height: AppSpacing.sm),
                    RideCardSkeleton(),
                  ],
                ),
                empty: () => EmptyState(
                  icon: AppIcons.calendar,
                  title: day.isToday
                      ? 'No rides today'
                      : 'No rides on ${Dates.dayMonth.format(day)}',
                  message: 'Assigned rides will show up here. '
                      'Check Offers for rides you can pick up.',
                  compact: true,
                ),
                data: (rides) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final ride in rides) ...[
                      DriverRideCard(
                        ride: ride,
                        onTap: () => context.push(R.driverRide(ride.id)),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A prominent card for the ride the driver is currently running, with a
/// one-tap route to the active-ride controls.
class _ActiveRideHero extends StatelessWidget {
  const _ActiveRideHero({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(R.driverActive(ride.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'IN PROGRESS',
                    style: AppTypography.eyebrow
                        .copyWith(color: AppColors.brassLine),
                  ),
                  const Spacer(),
                  StatusChip(
                    label: ride.status.label,
                    tone: StatusTone.active,
                    dense: true,
                    pulse: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ride.customerName,
                style: AppTypography.h2.copyWith(color: AppColors.inkInverse),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(AppIcons.pickup,
                      size: 14, color: AppColors.brassLine),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      ride.status.driverNext == null
                          ? ride.dropoffAddress
                          : ride.pickupAddress,
                      style: AppTypography.bodySm
                          .copyWith(color: AppColors.canvas.withValues(alpha: 0.85)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    ride.status.advanceLabel ?? 'Open ride',
                    style: AppTypography.button
                        .copyWith(color: AppColors.brassLine),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(AppIcons.arrowRight,
                      size: 16, color: AppColors.brassLine),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
