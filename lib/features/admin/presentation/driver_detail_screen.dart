import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/routes.dart';
import '../../../data/models/ride.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../providers/driver_providers.dart';
import '../../../providers/ride_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_avatar.dart';
import '../../../shared/widgets/display/app_card.dart';
import '../../../shared/widgets/display/key_value_row.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/display/status_chip.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/layout/max_width_body.dart';
import '../widgets/ride/ride_card.dart';

/// A driver's profile and their rides.
class DriverDetailScreen extends ConsumerWidget {
  const DriverDetailScreen({super.key, required this.driverId});

  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(driverDetailProvider(driverId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver'),
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () => context.canPop() ? context.pop() : context.go(R.adminDrivers),
        ),
      ),
      body: AsyncValueView<DriverListItem?>(
        value: driver,
        onRetry: () => ref.invalidate(driverDetailProvider(driverId)),
        data: (d) {
          if (d == null) {
            return const Center(
              child: EmptyState(
                icon: AppIcons.drivers,
                title: 'Driver not found',
                compact: true,
              ),
            );
          }
          return SingleChildScrollView(
            child: MaxWidthBody(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileCard(driver: d),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(title: 'Their rides', dense: true),
                  _DriverRides(driverId: driverId),
                  const SizedBox(height: AppSpacing.x5),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.driver});

  final DriverListItem driver;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                name: driver.fullName,
                imageUrl: driver.avatarUrl,
                size: AppAvatarSize.xl,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.fullName, style: AppTypography.h2),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        StatusChip(
                          label: driver.approvalStatus.label,
                          tone: driver.approvalStatus.tone,
                        ),
                        if (driver.isApproved)
                          StatusChip(
                            label: driver.isOnDuty ? 'On duty' : 'Off duty',
                            tone: driver.isOnDuty
                                ? StatusTone.complete
                                : StatusTone.dormant,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (driver.phone != null)
                AppButton(
                  label: 'Call',
                  icon: AppIcons.phone,
                  size: AppButtonSize.sm,
                  onPressed: () => launchUrl(Uri.parse('tel:${driver.phone}')),
                ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          KeyValueRow(label: 'Email', value: driver.email, icon: AppIcons.mailbox),
          const Divider(),
          KeyValueRow(label: 'Phone', value: driver.phone, icon: AppIcons.phone),
          const Divider(),
          KeyValueRow(
            label: 'Vehicle',
            value: driver.vehicleType?.label,
            icon: AppIcons.vehicle,
          ),
          const Divider(),
          KeyValueRow(
            label: 'Registration',
            value: driver.vehiclePlate,
            monospace: true,
          ),
        ],
      ),
    );
  }
}

class _DriverRides extends ConsumerWidget {
  const _DriverRides({required this.driverId});

  final String driverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(driverRidesProvider(driverId));

    return AsyncCollectionView<Ride>(
      value: rides,
      onRetry: () => ref.invalidate(driverRidesProvider(driverId)),
      compact: true,
      empty: () => const EmptyState(
        icon: AppIcons.ride,
        title: 'No rides assigned',
        message: 'This driver has no upcoming or recent rides.',
        compact: true,
      ),
      data: (list) => Column(
        children: [
          for (final ride in list) ...[
            RideCard(
              ride: ride,
              showDriver: false,
              onTap: () => context.push(R.adminRide(ride.id)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
