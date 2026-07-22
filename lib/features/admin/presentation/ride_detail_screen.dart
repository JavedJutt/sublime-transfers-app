import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/ride.dart';
import '../../../data/models/ride_status_event.dart';
import '../../../providers/assignment_providers.dart';
import '../../../providers/ride_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_card.dart';
import '../../../shared/widgets/display/key_value_row.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/display/status_chip.dart';
import '../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../shared/widgets/feedback/confirm_dialog.dart';
import '../../../shared/widgets/feedback/error_state.dart';
import '../../../shared/widgets/layout/max_width_body.dart';
import '../widgets/ride/ride_timeline.dart';
import 'assignment_sheet.dart';

/// Full ride detail: every field, the assignment card, the audit timeline, and
/// (from Phase 4) the assignment actions. Live — reflects edits or assignments
/// made elsewhere without a manual refresh.
class RideDetailScreen extends ConsumerWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(rideDetailProvider(rideId));

    return Scaffold(
      appBar: AppBar(
        title: rideAsync.maybeWhen(
          data: (r) => Text(r.reference, style: AppTypography.mono.copyWith(fontSize: 15)),
          orElse: () => const Text('Ride'),
        ),
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () => context.canPop() ? context.pop() : context.go(R.adminCalendar),
        ),
        actions: [
          rideAsync.maybeWhen(
            data: (ride) => TextButton.icon(
              onPressed: () => context.push(R.adminRideEditFor(ride.id)),
              icon: const Icon(AppIcons.edit, size: 18),
              label: const Text('Edit'),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: AsyncValueView<Ride>(
        value: rideAsync,
        onRetry: () => ref.invalidate(rideDetailProvider(rideId)),
        error: (err, retry) => ErrorState(
          error: err,
          onRetry: retry,
          action: AppButton.ghost(
            label: 'Back to calendar',
            onPressed: () => context.go(R.adminCalendar),
          ),
        ),
        data: (ride) => _Body(ride: ride, rideId: rideId),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.ride, required this.rideId});

  final Ride ride;
  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = AppBreakpoints.of(context).isWide;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderCard(ride: ride),
        const SizedBox(height: AppSpacing.lg),
        _RouteCard(ride: ride),
        const SizedBox(height: AppSpacing.lg),
        _DetailsCard(ride: ride),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AssignmentCard(ride: ride),
        const SizedBox(height: AppSpacing.lg),
        _TimelineCard(rideId: rideId),
      ],
    );

    return SingleChildScrollView(
      child: MaxWidthBody(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: left),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(flex: 2, child: right),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  left,
                  const SizedBox(height: AppSpacing.lg),
                  right,
                  const SizedBox(height: AppSpacing.x5),
                ],
              ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Dates.fullDate.format(ride.pickupAt),
                        style: AppTypography.bodySm),
                    Text(Dates.time.format(ride.pickupAt), style: AppTypography.display2),
                  ],
                ),
              ),
              StatusChip(
                label: ride.status.label,
                tone: ride.status.tone,
                pulse: ride.status.isLive,
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              const Icon(AppIcons.customer, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(ride.customerName, style: AppTypography.h3),
              ),
              if (ride.customerPhone != null)
                AppButton(
                  label: 'Call',
                  icon: AppIcons.phone,
                  size: AppButtonSize.sm,
                  onPressed: () => launchUrl(Uri.parse('tel:${ride.customerPhone}')),
                ),
            ],
          ),
          if (ride.customerPhone != null)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text(ride.customerPhone!, style: AppTypography.bodySm),
            ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Route', dense: true),
          _point(
            icon: AppIcons.pickup,
            color: AppColors.brass,
            label: 'Pickup',
            address: ride.pickupAddress,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(width: 2, height: 20, color: AppColors.line),
          ),
          _point(
            icon: AppIcons.dropoff,
            color: AppColors.ink,
            label: 'Drop-off',
            address: ride.dropoffAddress,
          ),
        ],
      ),
    );
  }

  Widget _point({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.caption),
              Text(address, style: AppTypography.bodyStrong),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Booking details', dense: true),
          KeyValueRow(label: 'Passengers', value: '${ride.passengers}', icon: AppIcons.passengers),
          const Divider(),
          KeyValueRow(label: 'Luggage', value: '${ride.luggage}', icon: AppIcons.luggage),
          const Divider(),
          KeyValueRow(
            label: 'Fare',
            value: ride.fareAmount == null
                ? null
                : Money.format(ride.fareAmount, currency: ride.fareCurrency),
            icon: AppIcons.fare,
            emphasise: true,
          ),
          const Divider(),
          KeyValueRow(
            label: 'Vehicle',
            value: ride.vehicleType?.label,
            icon: AppIcons.vehicle,
          ),
          const Divider(),
          KeyValueRow(
            label: 'Flight',
            value: ride.flightNumber,
            icon: AppIcons.flight,
            monospace: true,
          ),
          if (ride.notes != null && ride.notes!.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(AppIcons.notes, size: 15, color: AppColors.inkMuted),
                      SizedBox(width: AppSpacing.sm),
                      Text('Special notes', style: TextStyle()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(ride.notes!, style: AppTypography.body),
                ],
              ),
            ),
          ],
          // Source admin — admin-only metadata, shown here because this is the
          // admin app. It is simply absent from the driver's data.
          if (ride.sourceAdminName != null) ...[
            const Divider(),
            KeyValueRow(
              label: 'Source',
              value: ride.sourceAdminName,
              icon: AppIcons.mailbox,
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignmentCard extends ConsumerWidget {
  const _AssignmentCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(assignmentControllerProvider).isLoading;
    final closed = ride.status.isClosed;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Assignment', dense: true),
          if (ride.isAssigned) ...[
            Row(
              children: [
                const Icon(AppIcons.drivers, size: 18, color: AppColors.inkMuted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(ride.driverName ?? 'Driver', style: AppTypography.bodyStrong)),
              ],
            ),
            if (ride.assignmentMethod != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('${ride.assignmentMethod!.label}'
                  '${ride.assigningAdminName != null ? ' · by ${ride.assigningAdminName}' : ''}',
                  style: AppTypography.bodySm),
            ],
          ] else if (ride.broadcastOpen) ...[
            const StatusChip(label: 'Broadcasting to drivers', tone: StatusTone.active, pulse: true),
            const SizedBox(height: AppSpacing.sm),
            Text('Open to all on-duty drivers. First to claim wins.',
                style: AppTypography.bodySm),
          ] else ...[
            Row(
              children: [
                Icon(closed ? AppIcons.info : AppIcons.warning,
                    size: 18,
                    color: closed ? AppColors.inkMuted : AppColors.danger),
                const SizedBox(width: AppSpacing.sm),
                Text(closed ? 'This ride is closed' : 'No driver assigned',
                    style: AppTypography.bodyStrong.copyWith(
                        color: closed ? AppColors.inkMuted : AppColors.danger)),
              ],
            ),
          ],
          if (!closed) ...[
            const SizedBox(height: AppSpacing.lg),
            _Actions(ride: ride, busy: busy),
          ],
        ],
      ),
    );
  }
}

/// The context-sensitive assignment action buttons.
class _Actions extends ConsumerWidget {
  const _Actions({required this.ride, required this.busy});

  final Ride ride;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttons = <Widget>[];

    if (ride.isAssigned || ride.broadcastOpen) {
      // Assigned / offered / broadcasting: reassign, unassign, cancel.
      buttons.add(AppButton.primary(
        label: 'Reassign',
        icon: AppIcons.reassign,
        fullWidth: true,
        onPressed: busy
            ? null
            : () => AssignmentSheet.show(context, ride: ride, isReassign: true),
      ));
      buttons.add(AppButton(
        label: 'Unassign',
        fullWidth: true,
        onPressed: busy ? null : () => _unassign(context, ref),
      ));
    } else {
      // Unassigned: assign or broadcast.
      buttons.add(AppButton.primary(
        label: 'Assign driver',
        icon: AppIcons.assignDirect,
        fullWidth: true,
        onPressed: busy ? null : () => AssignmentSheet.show(context, ride: ride),
      ));
    }

    buttons.add(AppButton.destructive(
      label: 'Cancel ride',
      icon: AppIcons.close,
      fullWidth: true,
      onPressed: busy ? null : () => _cancel(context, ref),
    ));

    return Column(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          buttons[i],
          if (i < buttons.length - 1) const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Future<void> _unassign(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Unassign this ride?',
      message: 'It returns to the unassigned pool. '
          '${ride.driverName ?? 'The driver'} will be notified.',
      confirmLabel: 'Unassign',
      icon: AppIcons.reassign,
    );
    if (confirmed != true || !context.mounted) return;
    final controller = ref.read(assignmentControllerProvider.notifier);
    final ok = await controller.unassign(rideId: ride.id);
    if (!context.mounted) return;
    ok
        ? AppSnackbar.success(context, 'Ride unassigned')
        : AppSnackbar.showFailure(context, controller.errorOrNull!);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Cancel this ride?',
      message: 'This cannot be undone. Any assigned driver will be notified.',
      confirmLabel: 'Cancel ride',
      cancelLabel: 'Keep ride',
      destructive: true,
      icon: AppIcons.warning,
    );
    if (confirmed != true || !context.mounted) return;
    final controller = ref.read(assignmentControllerProvider.notifier);
    final ok = await controller.cancel(rideId: ride.id);
    if (!context.mounted) return;
    ok
        ? AppSnackbar.success(context, 'Ride cancelled')
        : AppSnackbar.showFailure(context, controller.errorOrNull!);
  }
}

class _TimelineCard extends ConsumerWidget {
  const _TimelineCard({required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(rideTimelineProvider(rideId));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'History', dense: true),
          AsyncValueView<List<RideStatusEvent>>(
            value: timeline,
            compact: true,
            onRetry: () => ref.invalidate(rideTimelineProvider(rideId)),
            data: (events) => events.isEmpty
                ? Text('No history yet.', style: AppTypography.bodySm)
                : RideTimeline(events: events),
          ),
        ],
      ),
    );
  }
}
