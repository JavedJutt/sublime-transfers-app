import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/error/error_mapper.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/ride.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/review_providers.dart';
import '../../../providers/ride_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/display/stat_callout.dart';
import '../../../shared/widgets/display/status_chip.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/error_state.dart';
import '../../../shared/widgets/feedback/ride_card_skeleton.dart';
import '../../../shared/widgets/layout/max_width_body.dart';
import '../widgets/ride/ride_card.dart';

/// A persistent amber banner shown whenever a connected mailbox is reporting a
/// sync error. A silent ingestion failure means bookings quietly stop arriving,
/// so this stays on the dashboard until the mailbox is healthy again.
class _GmailBanner extends ConsumerWidget {
  const _GmailBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasError = ref.watch(gmailHasErrorProvider).value ?? false;
    if (!hasError) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Material(
        color: AppColors.warningTint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(R.adminGmail),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(AppIcons.syncFailed, size: 20, color: AppColors.warning),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('A mailbox has stopped syncing',
                          style: AppTypography.bodyStrong
                              .copyWith(color: AppColors.warning)),
                      Text('Booking emails may not be arriving. Tap to check '
                          'Gmail settings.',
                          style: AppTypography.bodySm
                              .copyWith(color: AppColors.inkBody)),
                    ],
                  ),
                ),
                const Icon(AppIcons.chevronRight, size: 18, color: AppColors.warning),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The admin landing page: a greeting, the four key counts as stat callouts,
/// and today's rides. Every section loads and fails independently — one failed
/// query never blanks the page.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formFactor = AppBreakpoints.of(context);
    final user = ref.watch(currentUserProvider).value;
    final greeting = _greeting();
    final firstName = user?.fullName.split(' ').first ?? '';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(todayRidesProvider);
          await ref.read(todayRidesProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: MaxWidthBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$greeting$firstName', style: AppTypography.display2),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            Dates.fullDate.format(DateTime.now()),
                            style: AppTypography.body
                                .copyWith(color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    if (!formFactor.isMobile)
                      AppButton.primary(
                        label: 'New ride',
                        icon: AppIcons.add,
                        onPressed: () => context.push(R.adminRideNew),
                      ),
                  ],
                ),
                const _GmailBanner(),
                SizedBox(height: AppBreakpoints.sectionGap(formFactor)),
                _StatsRow(formFactor: formFactor),
                SizedBox(height: AppBreakpoints.sectionGap(formFactor)),
                SectionHeader(
                  eyebrow: 'Today',
                  title: 'Rides scheduled',
                  action: AppButton.ghost(
                    label: 'Open calendar',
                    trailingIcon: AppIcons.arrowRight,
                    size: AppButtonSize.sm,
                    onPressed: () => context.go(R.adminCalendar),
                  ),
                ),
                const _TodayRides(),
                if (formFactor.isMobile) ...[
                  const SizedBox(height: AppSpacing.xl),
                  AppButton.primary(
                    label: 'New ride',
                    icon: AppIcons.add,
                    fullWidth: true,
                    onPressed: () => context.push(R.adminRideNew),
                  ),
                ],
                const SizedBox(height: AppSpacing.x5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    final base = h < 12
        ? 'Good morning'
        : h < 18
            ? 'Good afternoon'
            : 'Good evening';
    return '$base, ';
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow({required this.formFactor});

  final FormFactor formFactor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final columns = AppBreakpoints.gridColumns(formFactor).clamp(1, 4);

    Widget grid(List<Widget> tiles) {
      return LayoutBuilder(
        builder: (context, c) {
          const gap = AppSpacing.lg;
          final w = (c.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final t in tiles) SizedBox(width: w.clamp(150, 9999), child: t),
            ],
          );
        },
      );
    }

    return stats.when(
      loading: () => grid(List.generate(
        4,
        (_) => const StatCallout(
          icon: AppIcons.ride,
          value: '—',
          label: 'Loading',
          isLoading: true,
        ),
      )),
      error: (e, st) => ErrorState(
        error: ErrorMapper.map(e, st),
        compact: true,
        onRetry: () => ref.invalidate(dashboardStatsProvider),
      ),
      data: (s) => grid([
        StatCallout(
          icon: AppIcons.ride,
          value: '${s.ridesToday}',
          label: 'Rides today',
          onTap: () {},
        ),
        StatCallout(
          icon: AppIcons.warning,
          value: '${s.unassignedTotal}',
          label: 'Unassigned',
          caption: s.unassignedToday > 0 ? '${s.unassignedToday} today' : 'None today',
          tone: s.unassignedTotal > 0 ? StatusTone.urgent : StatusTone.complete,
        ),
        StatCallout(
          icon: AppIcons.offers,
          value: '${s.inProgress}',
          label: 'In progress',
          tone: s.inProgress > 0 ? StatusTone.active : null,
        ),
        StatCallout(
          icon: AppIcons.drivers,
          value: '${s.driversOnDuty}',
          label: 'Drivers on duty',
          tone: StatusTone.complete,
        ),
      ]),
    );
  }
}

class _TodayRides extends ConsumerWidget {
  const _TodayRides();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(todayRidesProvider);

    return AsyncCollectionView<Ride>(
      value: rides,
      onRetry: () => ref.invalidate(todayRidesProvider),
      loading: () => const RideCardSkeleton(count: 4),
      empty: () => EmptyState(
        icon: AppIcons.calendar,
        title: 'No rides scheduled today',
        message: 'When bookings arrive or you add one, they\'ll appear here.',
        action: AppButton.primary(
          label: 'Create ride',
          icon: AppIcons.add,
          onPressed: () => context.push(R.adminRideNew),
        ),
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

