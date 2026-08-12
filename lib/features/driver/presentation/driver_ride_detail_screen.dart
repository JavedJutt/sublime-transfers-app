import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/date_x.dart';
import '../../../data/models/ride.dart';
import '../../../providers/driver_app_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_card.dart';
import '../../../shared/widgets/display/key_value_row.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/display/status_chip.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/error_state.dart';

/// A ride's full detail for the driver: who, where, when, and the facts they
/// need before and during the job. When the ride is one they're actively
/// working, a button drops them into the active-ride controls.
class DriverRideDetailScreen extends ConsumerWidget {
  const DriverRideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(driverRideProvider(rideId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(R.driverHome),
        ),
        title: const Text('Ride'),
      ),
      body: AsyncValueView<Ride?>(
        value: rideAsync,
        onRetry: () => ref.invalidate(driverRideProvider(rideId)),
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
              message: 'This ride is no longer offered to you, or it was '
                  'claimed by another driver.',
              action: AppButton.primary(
                label: 'Back to offers',
                onPressed: () => context.go(R.driverOffers),
              ),
            );
          }
          return _Body(ride: ride);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.x5,
      ),
      children: [
        _HeaderCard(ride: ride),
        const SizedBox(height: AppSpacing.lg),
        _RouteCard(ride: ride),
        const SizedBox(height: AppSpacing.lg),
        _DetailsCard(ride: ride),
        if (ride.status.isActionableByDriver) ...[
          const SizedBox(height: AppSpacing.xl),
          AppButton.primary(
            label: ride.status.isLive ? 'Open ride controls' : 'Start this ride',
            icon: AppIcons.navigate,
            size: AppButtonSize.lg,
            fullWidth: true,
            onPressed: () => context.push(R.driverActive(ride.id)),
          ),
        ],
      ],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Dates.relativeDay(ride.pickupAt),
                        style: AppTypography.bodySm
                            .copyWith(color: AppColors.inkMuted)),
                    Text(Dates.time.format(ride.pickupAt),
                        style: AppTypography.display2),
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
              Expanded(child: Text(ride.customerName, style: AppTypography.h3)),
              if (ride.customerPhone != null)
                AppButton(
                  label: 'Call',
                  icon: AppIcons.phone,
                  size: AppButtonSize.sm,
                  onPressed: () =>
                      launchUrl(Uri.parse('tel:${ride.customerPhone}')),
                ),
            ],
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
          _Point(
            icon: AppIcons.pickup,
            color: AppColors.brass,
            label: 'Pickup',
            address: ride.pickupAddress,
            onNavigate: ride.hasPickupCoords
                ? () => _openMaps(ride.pickupLat!, ride.pickupLng!)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(width: 2, height: 20, color: AppColors.line),
          ),
          _Point(
            icon: AppIcons.dropoff,
            color: AppColors.ink,
            label: 'Drop-off',
            address: ride.dropoffAddress,
            onNavigate: ride.hasDropoffCoords
                ? () => _openMaps(ride.dropoffLat!, ride.dropoffLng!)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps(double lat, double lng) {
    // A universal geo: URL — the OS hands it to whatever maps app the driver
    // uses. We never render maps ourselves on the driver side.
    return launchUrl(Uri.parse('https://maps.google.com/?q=$lat,$lng'));
  }
}

class _Point extends StatelessWidget {
  const _Point({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
    this.onNavigate,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String address;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
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
        if (onNavigate != null)
          IconButton(
            icon: const Icon(AppIcons.navigate, size: 20),
            tooltip: 'Navigate',
            color: AppColors.brass,
            onPressed: onNavigate,
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
          const SectionHeader(title: 'Details', dense: true),
          KeyValueRow(
            label: 'Passengers',
            value: '${ride.passengers}',
            icon: AppIcons.passengers,
          ),
          const Divider(),
          KeyValueRow(
            label: 'Luggage',
            value: '${ride.luggage}',
            icon: AppIcons.luggage,
          ),
          const Divider(),
          KeyValueRow(
            label: 'Fare',
            value: ride.fareAmount == null
                ? null
                : Money.format(ride.fareAmount, currency: ride.fareCurrency),
            icon: AppIcons.fare,
            emphasise: true,
          ),
          if (ride.vehicleType != null) ...[
            const Divider(),
            KeyValueRow(
              label: 'Vehicle',
              value: ride.vehicleType!.label,
              icon: AppIcons.vehicle,
            ),
          ],
          if (ride.isAirportPickup) ...[
            const Divider(),
            KeyValueRow(
              label: 'Flight',
              value: ride.flightNumber,
              icon: AppIcons.flight,
              monospace: true,
            ),
          ],
          if (ride.notes != null && ride.notes!.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(AppIcons.notes,
                          size: 15, color: AppColors.inkMuted),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Notes from the office',
                          style: AppTypography.bodySm
                              .copyWith(color: AppColors.inkMuted)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(ride.notes!, style: AppTypography.body),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
