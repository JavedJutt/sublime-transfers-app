import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/routes.dart';
import '../../../data/models/ride.dart';
import '../../../data/repositories/driver_ride_repository.dart';
import '../../../providers/driver_app_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/ride_card_skeleton.dart';
import '../../shared/notification_center.dart';
import '../controllers/status_controller.dart';
import '../widgets/broadcast_card.dart';
import '../widgets/decline_reason_sheet.dart';
import '../widgets/offer_card.dart';

/// Two stacks of opportunities: rides offered directly to this driver, and the
/// open broadcast pool anyone can claim. Losing a claim race is calm here — an
/// informational note, and the card simply drops out on the next refresh.
class DriverOffersScreen extends ConsumerWidget {
  const DriverOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(driverOffersProvider);
    final busyRideId = ref.watch(_busyRideProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: Text('Offers', style: AppTypography.h3),
        actions: const [NotificationBell(), SizedBox(width: AppSpacing.xs)],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(driverOffersProvider);
          await ref.read(driverOffersProvider.future);
        },
        child: AsyncValueView<DriverOffers>(
          value: offersAsync,
          onRetry: () => ref.invalidate(driverOffersProvider),
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: const [
              RideCardSkeleton(),
              SizedBox(height: AppSpacing.sm),
              RideCardSkeleton(),
            ],
          ),
          data: (offers) {
            if (offers.isEmpty) {
              return ListView(
                // A ListView keeps pull-to-refresh working over the empty state.
                children: const [
                  SizedBox(height: AppSpacing.x6),
                  EmptyState(
                    icon: AppIcons.offers,
                    title: 'No offers right now',
                    message: 'When a dispatcher offers you a ride, or opens one '
                        'to all drivers, it shows up here.',
                    tone: EmptyStateTone.positive,
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.x5,
              ),
              children: [
                if (offers.direct.isNotEmpty) ...[
                  _SectionLabel(
                    icon: AppIcons.assignDirect,
                    label: 'Offered to you',
                    count: offers.direct.length,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final ride in offers.direct) ...[
                    OfferCard(
                      ride: ride,
                      busy: busyRideId == ride.id,
                      onTap: () => context.push(R.driverRide(ride.id)),
                      onAccept: () => _accept(context, ref, ride),
                      onDecline: () => _decline(context, ref, ride),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
                if (offers.broadcast.isNotEmpty) ...[
                  _SectionLabel(
                    icon: AppIcons.broadcast,
                    label: 'Open to all drivers',
                    count: offers.broadcast.length,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final ride in offers.broadcast) ...[
                    BroadcastCard(
                      ride: ride,
                      busy: busyRideId == ride.id,
                      onTap: () => context.push(R.driverRide(ride.id)),
                      onClaim: () => _claim(context, ref, ride),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref, Ride ride) async {
    ref.read(_busyRideProvider.notifier).set(ride.id);
    final outcome = await ref
        .read(statusControllerProvider.notifier)
        .respond(rideId: ride.id, accept: true);
    ref.read(_busyRideProvider.notifier).set(null);
    if (!context.mounted) return;
    _report(context, outcome, onSent: 'Ride accepted — find it on your day');
  }

  Future<void> _decline(BuildContext context, WidgetRef ref, Ride ride) async {
    final reason = await DeclineReasonSheet.show(context);
    if (reason == null || !context.mounted) return; // Dismissed — no action.
    ref.read(_busyRideProvider.notifier).set(ride.id);
    final outcome = await ref.read(statusControllerProvider.notifier).respond(
          rideId: ride.id,
          accept: false,
          reason: reason.isEmpty ? null : reason,
        );
    ref.read(_busyRideProvider.notifier).set(null);
    if (!context.mounted) return;
    _report(context, outcome, onSent: 'Offer declined');
  }

  Future<void> _claim(BuildContext context, WidgetRef ref, Ride ride) async {
    ref.read(_busyRideProvider.notifier).set(ride.id);
    final outcome = await ref
        .read(statusControllerProvider.notifier)
        .claim(rideId: ride.id);
    ref.read(_busyRideProvider.notifier).set(null);
    if (!context.mounted) return;
    _report(context, outcome, onSent: 'Ride claimed — it\'s yours');
  }

  void _report(
    BuildContext context,
    DriverActionOutcome outcome, {
    required String onSent,
  }) {
    switch (outcome) {
      case ActionSent():
        AppSnackbar.success(context, onSent);
      case ActionQueued():
        AppSnackbar.show(
          context,
          message: 'You\'re offline — this will send when you reconnect',
          tone: SnackTone.warning,
        );
      case ActionRejected(:final error):
        AppSnackbar.showFailure(context, error);
    }
  }
}

/// Which ride currently has an action in flight, so only that card shows a
/// spinner rather than the whole list.
final _busyRideProvider =
    NotifierProvider<_BusyRide, String?>(_BusyRide.new);

class _BusyRide extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.inkMuted),
        const SizedBox(width: AppSpacing.sm),
        Text(label.toUpperCase(), style: AppTypography.eyebrow),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.surfaceSunk,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('$count',
              style: AppTypography.caption.copyWith(color: AppColors.inkMuted)),
        ),
      ],
    );
  }
}
