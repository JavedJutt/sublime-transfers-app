import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/ride.dart';
import '../../../providers/ride_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/status_chip.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/ride_card_skeleton.dart';
import '../../../shared/widgets/layout/max_width_body.dart';
import '../widgets/calendar/calendar_filter_bar.dart';
import '../widgets/ride/ride_card.dart';

/// The calendar dashboard: Day / Week / Month, filterable, colour-coded by
/// status. Rides always sort by pickup time.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(calendarViewModeProvider);

    return Scaffold(
      body: Column(
        children: [
          _CalendarHeader(),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: MaxWidthBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CalendarFilterBar(),
                    const SizedBox(height: AppSpacing.lg),
                    switch (mode) {
                      CalendarViewMode.day => const _DayView(),
                      CalendarViewMode.week => const _WeekView(),
                      CalendarViewMode.month => const _MonthView(),
                    },
                    const SizedBox(height: AppSpacing.x5),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AppBreakpoints.of(context).isMobile
          ? FloatingActionButton(
              onPressed: () => context.push(R.adminRideNew),
              backgroundColor: AppColors.brass,
              foregroundColor: AppColors.inkInverse,
              child: const Icon(AppIcons.add),
            )
          : null,
    );
  }
}

class _CalendarHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(calendarViewModeProvider);
    final focused = ref.watch(focusedDateProvider);
    final narrow = AppBreakpoints.of(context).isNarrow;

    final title = switch (mode) {
      CalendarViewMode.day => Dates.relativeDay(focused),
      CalendarViewMode.week =>
        '${Dates.dayMonth.format(focused.weekStart)} – ${Dates.dayMonth.format(focused.weekStart.addDays(6))}',
      CalendarViewMode.month => Dates.monthYear.format(focused),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppBreakpoints.gutter(AppBreakpoints.of(context)),
        AppSpacing.lg,
        AppBreakpoints.gutter(AppBreakpoints.of(context)),
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(AppIcons.chevronLeft),
            onPressed: () => ref.read(focusedDateProvider.notifier).step(-1),
            tooltip: 'Previous',
          ),
          IconButton(
            icon: const Icon(AppIcons.chevronRight),
            onPressed: () => ref.read(focusedDateProvider.notifier).step(1),
            tooltip: 'Next',
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: narrow ? AppTypography.h3 : AppTypography.h2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppButton.ghost(
            label: 'Today',
            size: AppButtonSize.sm,
            onPressed: () => ref.read(focusedDateProvider.notifier).today(),
          ),
          const SizedBox(width: AppSpacing.sm),
          _ViewSwitcher(mode: mode),
        ],
      ),
    );
  }
}

class _ViewSwitcher extends ConsumerWidget {
  const _ViewSwitcher({required this.mode});

  final CalendarViewMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSunk,
        borderRadius: AppRadius.brMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in CalendarViewMode.values)
            GestureDetector(
              onTap: () => ref.read(calendarViewModeProvider.notifier).set(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: m == mode ? AppColors.surface : AppColors.transparent,
                  borderRadius: AppRadius.brSm,
                  boxShadow: m == mode
                      ? const [
                          BoxShadow(color: Color(0x14000000), blurRadius: 4)
                        ]
                      : null,
                ),
                child: Text(
                  m.label,
                  style: AppTypography.label.copyWith(
                    color: m == mode ? AppColors.ink : AppColors.inkMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Day view: a simple ordered list of ride cards for the focused day.
class _DayView extends ConsumerWidget {
  const _DayView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(calendarRidesProvider);
    final filtered = ref.watch(hasActiveFiltersProvider);
    final focused = ref.watch(focusedDateProvider);

    return AsyncCollectionView<Ride>(
      value: rides,
      onRetry: () => ref.invalidate(calendarRidesProvider),
      loading: () => const RideCardSkeleton(count: 5),
      empty: () => _EmptyForRange(
        filtered: filtered,
        message: 'No rides on ${Dates.dayMonth.format(focused)}',
      ),
      data: (list) => Column(
        children: [
          for (final ride in list) ...[
            RideCard(
              ride: ride,
              onTap: () => context.push(R.adminRide(ride.id)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// Week view: seven day columns on wide screens, stacked day sections on
/// narrow ones. Each ride is a compact card.
class _WeekView extends ConsumerWidget {
  const _WeekView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(calendarRidesProvider);
    final byDay = ref.watch(ridesByDayProvider);
    final filtered = ref.watch(hasActiveFiltersProvider);
    final focused = ref.watch(focusedDateProvider);
    final wide = AppBreakpoints.of(context).isWide;
    final days = List.generate(7, (i) => focused.weekStart.addDays(i));

    return AsyncValueView(
      value: rides,
      onRetry: () => ref.invalidate(calendarRidesProvider),
      loading: () => const RideCardSkeleton(count: 4),
      data: (_) {
        final total = days.fold<int>(0, (n, d) => n + (byDay[d.dayKey]?.length ?? 0));
        if (total == 0) {
          return _EmptyForRange(filtered: filtered, message: 'No rides this week');
        }
        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _DayColumn(day: day, rides: byDay[day.dayKey] ?? const []),
                    ),
                  ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final day in days)
              if ((byDay[day.dayKey] ?? const []).isNotEmpty)
                _DaySection(day: day, rides: byDay[day.dayKey]!),
          ],
        );
      },
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.rides});

  final DateTime day;
  final List<Ride> rides;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: day.isToday ? AppColors.brassTint : AppColors.surfaceSunk,
            borderRadius: AppRadius.brSm,
          ),
          child: Column(
            children: [
              Text(Dates.dayName.format(day).toUpperCase(),
                  style: AppTypography.caption.copyWith(
                      color: day.isToday ? AppColors.brassPress : AppColors.inkMuted)),
              Text(Dates.dayNum.format(day),
                  style: AppTypography.h3.copyWith(
                      color: day.isToday ? AppColors.brassPress : AppColors.ink)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (rides.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text('—',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(color: AppColors.inkFaint)),
          )
        else
          for (final ride in rides) ...[
            _MiniRideCard(ride: ride),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day, required this.rides});

  final DateTime day;
  final List<Ride> rides;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Text(Dates.relativeDay(day), style: AppTypography.label),
        ),
        for (final ride in rides) ...[
          Builder(
            builder: (context) => RideCard(
              ride: ride,
              dense: true,
              onTap: () => _open(context, ride),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  void _open(BuildContext context, Ride ride) =>
      GoRouter.of(context).push(R.adminRide(ride.id));
}

class _MiniRideCard extends StatelessWidget {
  const _MiniRideCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final tone = ride.status.tone;
    return GestureDetector(
      onTap: () => GoRouter.of(context).push(R.adminRide(ride.id)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brSm,
          border: Border(
            left: BorderSide(color: tone.foreground, width: 3),
            top: const BorderSide(color: AppColors.line),
            right: const BorderSide(color: AppColors.line),
            bottom: const BorderSide(color: AppColors.line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Dates.time.format(ride.pickupAt),
                style: AppTypography.bodyStrong.copyWith(fontSize: 13)),
            Text(ride.customerName,
                style: AppTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Month view: a calendar grid, each cell showing a count + status dots.
class _MonthView extends ConsumerWidget {
  const _MonthView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(calendarRidesProvider);
    final byDay = ref.watch(ridesByDayProvider);
    final filtered = ref.watch(hasActiveFiltersProvider);
    final focused = ref.watch(focusedDateProvider);

    return AsyncValueView(
      value: rides,
      onRetry: () => ref.invalidate(calendarRidesProvider),
      loading: () => const SizedBox(
        height: 360,
        child: Center(child: CircularProgressIndicator()),
      ),
      data: (_) {
        final monthStart = focused.monthStart;
        final leading = monthStart.weekday - DateTime.monday; // 0..6
        final daysInMonth = focused.monthEnd.day;
        final cells = <DateTime?>[
          ...List.filled(leading, null),
          for (var d = 1; d <= daysInMonth; d++)
            DateTime(focused.year, focused.month, d),
        ];
        while (cells.length % 7 != 0) {
          cells.add(null);
        }
        final total = byDay.values.fold<int>(0, (n, l) => n + l.length);
        if (total == 0) {
          return _EmptyForRange(filtered: filtered, message: 'No rides this month');
        }

        return Column(
          children: [
            Row(
              children: [
                for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                  Expanded(
                    child: Center(
                      child: Text(d.toUpperCase(),
                          style: AppTypography.caption
                              .copyWith(color: AppColors.inkMuted)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.85,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: cells.length,
              itemBuilder: (context, i) {
                final day = cells[i];
                if (day == null) return const SizedBox.shrink();
                return _MonthCell(day: day, rides: byDay[day.dayKey] ?? const []);
              },
            ),
          ],
        );
      },
    );
  }
}

class _MonthCell extends ConsumerWidget {
  const _MonthCell({required this.day, required this.rides});

  final DateTime day;
  final List<Ride> rides;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(focusedDateProvider.notifier).set(day);
        ref.read(calendarViewModeProvider.notifier).set(CalendarViewMode.day);
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: day.isToday ? AppColors.brassTint : AppColors.surface,
          borderRadius: AppRadius.brSm,
          border: Border.all(
            color: day.isToday ? AppColors.brassLine : AppColors.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Dates.dayNum.format(day),
                style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: day.isToday ? AppColors.brassPress : AppColors.inkBody)),
            const Spacer(),
            if (rides.isNotEmpty) ...[
              Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [
                  for (final ride in rides.take(4))
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: ride.status.tone.foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text('${rides.length}',
                  style: AppTypography.caption.copyWith(
                      fontSize: 10, color: AppColors.inkMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyForRange extends ConsumerWidget {
  const _EmptyForRange({required this.filtered, required this.message});

  final bool filtered;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filtered-empty is a distinct state from genuinely-empty.
    if (filtered) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: EmptyState(
          icon: AppIcons.filter,
          title: 'No rides match these filters',
          message: 'Try widening the date range or clearing a filter.',
          action: AppButton.ghost(
            label: 'Clear filters',
            size: AppButtonSize.sm,
            onPressed: () {
              ref.read(statusFilterProvider.notifier).clear();
              ref.read(driverFilterProvider.notifier).set(null);
              ref.read(searchQueryProvider.notifier).set('');
            },
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: EmptyState(
        icon: AppIcons.calendar,
        title: message,
        message: 'Nothing scheduled for this period.',
        action: AppButton.primary(
          label: 'Create ride',
          icon: AppIcons.add,
          onPressed: () => context.push(R.adminRideNew),
        ),
      ),
    );
  }
}
