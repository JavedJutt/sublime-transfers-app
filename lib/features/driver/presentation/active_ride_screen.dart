import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/env/app_env.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/ride.dart';
import '../../../data/models/ride_status.dart';
import '../../../providers/driver_app_providers.dart';
import '../../../providers/location_providers.dart';
import '../../../services/location/location_service.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_card.dart';
import '../../../shared/widgets/display/status_chip.dart';
import '../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../shared/widgets/feedback/confirm_dialog.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/error_state.dart';
import '../controllers/status_controller.dart';
import '../widgets/location_permission_banner.dart';
import '../widgets/status_advance_button.dart';

/// The heart of the driver app: the ride they're running now, and the one big
/// button that moves it through Assigned → En route → Arrived → In progress →
/// Completed. Every advance stamps their location (captured by the controller,
/// which never blocks the transition on a missing fix). Location permission is
/// requested here, on first open, with an in-app rationale — never at launch.
class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen>
    with WidgetsBindingObserver {
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop streaming when the driver leaves the screen. (advance_ride_status
    // still stamps location at every transition regardless of this.)
    if (AppEnv.continuousTrackingEnabled) {
      ref.read(driverTrackingServiceProvider).stop();
    }
    super.dispose();
  }

  /// Keep continuous tracking running exactly while the ride is live. Idempotent
  /// — safe to call on every ride update.
  void _syncTracking(Ride? ride) {
    if (!AppEnv.continuousTrackingEnabled) return;
    final tracking = ref.read(driverTrackingServiceProvider);
    if (ride != null && ride.status.isLive) {
      tracking.start(ride.id);
    } else if (tracking.isTracking) {
      tracking.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check after a trip to system settings, so the banner clears itself
    // the moment the driver comes back with permission granted.
    if (state == AppLifecycleState.resumed) {
      ref.read(locationPermissionProvider.notifier).recheck();
    }
  }

  Future<void> _enableLocation() async {
    setState(() => _requesting = true);
    await ref.read(locationPermissionProvider.notifier).request();
    if (mounted) setState(() => _requesting = false);
  }

  Future<void> _openSettings() =>
      ref.read(locationPermissionProvider.notifier).openSettings();

  Future<void> _advance(Ride ride) async {
    final next = ride.status.driverNext;
    if (next == null) return;

    // The terminal step gets a confirmation — it can't be walked back.
    if (next == RideStatus.completed) {
      final ok = await ConfirmDialog.show(
        context,
        title: 'Complete this ride?',
        message: 'Mark the ride finished. This records your location and '
            'closes the job.',
        confirmLabel: 'Complete ride',
        icon: AppIcons.check,
      );
      if (ok != true || !mounted) return;
    }

    final outcome = await ref
        .read(statusControllerProvider.notifier)
        .advance(rideId: ride.id, to: next);
    if (!mounted) return;

    switch (outcome) {
      case ActionSent():
        AppSnackbar.success(context, '${next.label} — recorded');
        if (next == RideStatus.completed && context.canPop()) context.pop();
      case ActionQueued():
        AppSnackbar.show(
          context,
          message: 'Saved — this will sync when you\'re back online',
          tone: SnackTone.warning,
        );
        if (next == RideStatus.completed && context.canPop()) context.pop();
      case ActionRejected(:final error):
        AppSnackbar.showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideAsync = ref.watch(driverRideProvider(widget.rideId));
    final permission = ref.watch(locationPermissionProvider);
    final busy = ref.watch(statusControllerProvider).isLoading;

    // Start/stop continuous tracking as the ride goes live and closes. Fires on
    // first load (loading → data) and on every subsequent status change.
    ref.listen(driverRideProvider(widget.rideId), (_, next) {
      _syncTracking(next.value);
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(R.driverHome),
        ),
        title: const Text('Active ride'),
      ),
      body: AsyncValueView<Ride?>(
        value: rideAsync,
        onRetry: () => ref.invalidate(driverRideProvider(widget.rideId)),
        error: (err, retry) => ErrorState(
          error: err,
          onRetry: retry,
          action: AppButton.ghost(
            label: 'Back to my day',
            onPressed: () => context.go(R.driverHome),
          ),
        ),
        data: (ride) {
          if (ride == null) {
            return EmptyState(
              icon: AppIcons.ride,
              title: 'Ride unavailable',
              message: 'This ride is no longer assigned to you.',
              action: AppButton.primary(
                label: 'Back to my day',
                onPressed: () => context.go(R.driverHome),
              ),
            );
          }
          return _Body(
            ride: ride,
            permission: permission.value ?? LocationPermissionState.denied,
            busy: busy,
            requesting: _requesting,
            onAdvance: () => _advance(ride),
            onEnableLocation: _enableLocation,
            onOpenSettings: _openSettings,
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.ride,
    required this.permission,
    required this.busy,
    required this.requesting,
    required this.onAdvance,
    required this.onEnableLocation,
    required this.onOpenSettings,
  });

  final Ride ride;
  final LocationPermissionState permission;
  final bool busy;
  final bool requesting;
  final VoidCallback onAdvance;
  final VoidCallback onEnableLocation;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    // The current leg's target: pickup until we're rolling with the passenger.
    final headingToDropoff =
        ride.status == RideStatus.inProgress || ride.status.isClosed;
    final targetAddress =
        headingToDropoff ? ride.dropoffAddress : ride.pickupAddress;
    final targetLabel = headingToDropoff ? 'Drop-off' : 'Pickup';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              _StatusHero(ride: ride),
              const SizedBox(height: AppSpacing.lg),
              _CurrentLegCard(
                label: targetLabel,
                address: targetAddress,
                customerName: ride.customerName,
                customerPhone: ride.customerPhone,
              ),
              if (!permission.isGranted) ...[
                const SizedBox(height: AppSpacing.lg),
                LocationPermissionBanner(
                  state: permission,
                  busy: requesting,
                  onEnable: onEnableLocation,
                  onOpenSettings: onOpenSettings,
                ),
              ],
            ],
          ),
        ),
        // The advance button lives in a pinned footer — always in thumb reach,
        // never scrolled away mid-ride.
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: StatusAdvanceButton(
            status: ride.status,
            busy: busy,
            onAdvance: onAdvance,
          ),
        ),
      ],
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.ride});

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
                child: Text(ride.customerName, style: AppTypography.h2),
              ),
              StatusChip(
                label: ride.status.label,
                tone: ride.status.tone,
                pulse: ride.status.isLive,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(AppIcons.time, size: 14, color: AppColors.inkFaint),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${Dates.dateTime.format(ride.pickupAt)} · '
                '${Dates.relativeTime(ride.pickupAt)}',
                style: AppTypography.bodySm.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrentLegCard extends StatelessWidget {
  const _CurrentLegCard({
    required this.label,
    required this.address,
    required this.customerName,
    required this.customerPhone,
  });

  final String label;
  final String address;
  final String customerName;
  final String? customerPhone;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypography.eyebrow),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(AppIcons.pickup, size: 22, color: AppColors.brass),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(address, style: AppTypography.bodyLg),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Navigate',
                  icon: AppIcons.navigate,
                  fullWidth: true,
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://maps.google.com/?q=${Uri.encodeComponent(address)}',
                    ),
                  ),
                ),
              ),
              if (customerPhone != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Call',
                    icon: AppIcons.phone,
                    fullWidth: true,
                    onPressed: () =>
                        launchUrl(Uri.parse('tel:$customerPhone')),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
