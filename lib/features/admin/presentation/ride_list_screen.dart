import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/ride.dart';
import '../../../providers/ride_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/ride_card_skeleton.dart';
import '../../../shared/widgets/layout/max_width_body.dart';
import '../widgets/calendar/calendar_filter_bar.dart';
import '../widgets/ride/ride_card.dart';

/// A flat, searchable list of rides grouped by day. The calendar is for
/// time-structured browsing; this is for "find me this ride".
class RideListScreen extends ConsumerWidget {
  const RideListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(rideListProvider);
    final filtered = ref.watch(hasActiveFiltersProvider);

    return Scaffold(
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: MaxWidthBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'All rides',
                subtitle: 'The last week and the next two months.',
                action: AppBreakpoints.of(context).isMobile
                    ? null
                    : AppButton.primary(
                        label: 'New ride',
                        icon: AppIcons.add,
                        onPressed: () => context.push(R.adminRideNew),
                      ),
              ),
              const CalendarFilterBar(),
              const SizedBox(height: AppSpacing.lg),
              AsyncCollectionView<Ride>(
                value: rides,
                onRetry: () => ref.invalidate(rideListProvider),
                loading: () => const RideCardSkeleton(count: 6),
                empty: () => filtered
                    ? _FilteredEmpty(onClear: () {
                        ref.read(statusFilterProvider.notifier).clear();
                        ref.read(driverFilterProvider.notifier).set(null);
                        ref.read(searchQueryProvider.notifier).set('');
                      })
                    : EmptyState(
                        icon: AppIcons.ride,
                        title: 'No rides yet',
                        message: 'Rides you create or import will appear here.',
                        action: AppButton.primary(
                          label: 'Create ride',
                          icon: AppIcons.add,
                          onPressed: () => context.push(R.adminRideNew),
                        ),
                      ),
                data: (list) => _GroupedList(rides: list),
              ),
              const SizedBox(height: AppSpacing.x5),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.rides});

  final List<Ride> rides;

  @override
  Widget build(BuildContext context) {
    // Group by day, preserving pickup order (the provider already sorts).
    final groups = <String, List<Ride>>{};
    for (final ride in rides) {
      groups.putIfAbsent(ride.pickupAt.dayKey, () => []).add(ride);
    }
    final days = groups.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in days) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: _DayHeader(day: groups[key]!.first.pickupAt),
          ),
          for (final ride in groups[key]!) ...[
            RideCard(
              ride: ride,
              onTap: () => context.push(R.adminRide(ride.id)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(Dates.relativeDay(day),
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Divider(color: Theme.of(context).dividerColor)),
      ],
    );
  }
}

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.filter,
      title: 'No rides match these filters',
      message: 'Try a different search, driver, or status.',
      action: AppButton.ghost(
        label: 'Clear filters',
        size: AppButtonSize.sm,
        onPressed: onClear,
      ),
    );
  }
}
