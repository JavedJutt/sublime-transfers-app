import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../data/models/ride_status.dart';
import '../../../../providers/driver_providers.dart';
import '../../../../providers/ride_providers.dart';
import '../../../../shared/widgets/display/app_avatar.dart';
import '../../../../shared/widgets/display/app_chip.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';

/// Filter controls shared by the calendar and the ride list: search, a driver
/// picker, and status chips. Reads and writes the filter providers directly so
/// both screens stay in sync.
class CalendarFilterBar extends ConsumerWidget {
  const CalendarFilterBar({super.key, this.showSearch = true});

  final bool showSearch;

  /// The statuses worth exposing as quick filters (the operational ones).
  static const _statuses = [
    RideStatus.unassigned,
    RideStatus.offered,
    RideStatus.assigned,
    RideStatus.enRoute,
    RideStatus.inProgress,
    RideStatus.completed,
    RideStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStatuses = ref.watch(statusFilterProvider);
    final driverFilter = ref.watch(driverFilterProvider);
    final drivers = ref.watch(approvedDriversProvider).value ?? const [];
    final selectedDriver =
        drivers.where((d) => d.id == driverFilter).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSearch)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppSearchField(
              hint: 'Search name, reference, or address',
              initialValue: ref.read(searchQueryProvider),
              onChanged: (q) => ref.read(searchQueryProvider.notifier).set(q),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Driver filter: a menu of approved drivers.
              _DriverFilterChip(
                selectedName: selectedDriver?.fullName,
                selectedAvatarName: selectedDriver?.fullName,
                onClear: driverFilter == null
                    ? null
                    : () => ref.read(driverFilterProvider.notifier).set(null),
                onPick: (id) => ref.read(driverFilterProvider.notifier).set(id),
                drivers: drivers,
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(width: 1, height: 24, color: const Color(0x22000000)),
              const SizedBox(width: AppSpacing.sm),
              for (final s in _statuses) ...[
                AppChip(
                  label: s.label,
                  selected: selectedStatuses.contains(s),
                  onTap: () =>
                      ref.read(statusFilterProvider.notifier).toggle(s),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverFilterChip extends StatelessWidget {
  const _DriverFilterChip({
    required this.selectedName,
    required this.selectedAvatarName,
    required this.onClear,
    required this.onPick,
    required this.drivers,
  });

  final String? selectedName;
  final String? selectedAvatarName;
  final VoidCallback? onClear;
  final ValueChanged<String> onPick;
  final List<dynamic> drivers;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Filter by driver',
      onSelected: onPick,
      itemBuilder: (context) => [
        for (final d in drivers)
          PopupMenuItem<String>(
            value: d.id as String,
            child: Row(
              children: [
                AppAvatar(name: d.fullName as String, size: AppAvatarSize.sm),
                const SizedBox(width: AppSpacing.sm),
                Text(d.fullName as String),
              ],
            ),
          ),
      ],
      child: AppChip(
        label: selectedName ?? 'All drivers',
        selected: selectedName != null,
        leading: selectedAvatarName == null
            ? null
            : AppAvatar(name: selectedAvatarName!, size: AppAvatarSize.sm),
        onRemove: onClear,
      ),
    );
  }
}
