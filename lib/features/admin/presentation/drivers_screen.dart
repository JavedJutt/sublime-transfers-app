import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/router/routes.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/driver_repository.dart';
import '../../../providers/driver_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_chip.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/ride_card_skeleton.dart';
import '../../../shared/widgets/layout/max_width_body.dart';
import '../widgets/drivers/driver_card.dart';

/// The drivers roster. Filter by approval state; jump to approvals when any
/// are pending.
class DriversScreen extends ConsumerStatefulWidget {
  const DriversScreen({super.key});

  @override
  ConsumerState<DriversScreen> createState() => _DriversScreenState();
}

enum _DriverTab { all, approved, pending }

class _DriversScreenState extends ConsumerState<DriversScreen> {
  _DriverTab _tab = _DriverTab.all;

  @override
  Widget build(BuildContext context) {
    final drivers = ref.watch(driverListProvider);
    final pendingCount = ref.watch(pendingDriversProvider).value?.length ?? 0;

    return Scaffold(
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: MaxWidthBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'Drivers',
                subtitle: 'Your fleet and their approval status.',
                action: pendingCount > 0
                    ? AppButton.primary(
                        label: 'Review $pendingCount pending',
                        icon: AppIcons.approve,
                        size: AppButtonSize.sm,
                        onPressed: () => context.push(R.adminDriverApprovals),
                      )
                    : null,
              ),
              Row(
                children: [
                  for (final tab in _DriverTab.values) ...[
                    AppChip(
                      label: switch (tab) {
                        _DriverTab.all => 'All',
                        _DriverTab.approved => 'Approved',
                        _DriverTab.pending => 'Pending',
                      },
                      count: tab == _DriverTab.pending && pendingCount > 0
                          ? pendingCount
                          : null,
                      selected: _tab == tab,
                      onTap: () => setState(() => _tab = tab),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AsyncCollectionView<DriverListItem>(
                value: drivers,
                onRetry: () => ref.invalidate(driverListProvider),
                loading: () => const RideCardSkeleton(count: 4),
                isEmpty: (list) => _filter(list).isEmpty,
                empty: () => EmptyState(
                  icon: AppIcons.drivers,
                  title: _tab == _DriverTab.all
                      ? 'No drivers yet'
                      : 'No ${_tab.name} drivers',
                  message: _tab == _DriverTab.all
                      ? 'Drivers who register or are added will appear here.'
                      : 'Try a different filter.',
                ),
                data: (list) {
                  final filtered = _filter(list);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final driver in filtered) ...[
                        DriverCard(
                          driver: driver,
                          onTap: () => context.push(R.adminDriver(driver.id)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      const SizedBox(height: AppSpacing.x4),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DriverListItem> _filter(List<DriverListItem> list) => switch (_tab) {
        _DriverTab.all => list,
        _DriverTab.approved =>
          list.where((d) => d.approvalStatus == DriverApprovalStatus.approved).toList(),
        _DriverTab.pending =>
          list.where((d) => d.approvalStatus == DriverApprovalStatus.pending).toList(),
      };
}
