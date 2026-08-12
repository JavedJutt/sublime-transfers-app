import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/routes.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/driver_providers.dart';
import '../../../providers/review_providers.dart';
import '../../../shared/widgets/display/app_avatar.dart';
import '../../shared/notification_center.dart';

/// Responsive chrome for the admin app.
///
/// Extended rail ≥1280, collapsed rail 1024–1279, and a hamburger + drawer
/// below that. This is what keeps the dashboard usable on a tablet or a
/// half-width desktop window rather than breaking — the desktop layout never
/// gets squeezed; it switches shape.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  static const _destinations = <_NavItem>[
    _NavItem(R.adminDashboard, 'Dashboard', AppIcons.dashboard, AppIcons.dashboardActive),
    _NavItem(R.adminCalendar, 'Calendar', AppIcons.calendar, AppIcons.calendarActive),
    _NavItem(R.adminRides, 'Rides', AppIcons.rides, AppIcons.ridesActive),
    _NavItem(R.adminLiveMap, 'Live map', AppIcons.liveMap, AppIcons.liveMapActive),
    _NavItem(R.adminDrivers, 'Drivers', AppIcons.drivers, AppIcons.driversActive),
    _NavItem(R.adminReview, 'Review', AppIcons.reviewQueue, AppIcons.reviewQueueActive),
    _NavItem(R.adminGmail, 'Gmail', AppIcons.mailbox, AppIcons.mailbox),
  ];

  int _selectedIndex(String location) {
    // Longest-prefix match so nested routes keep their parent highlighted.
    var best = 0;
    var bestLen = -1;
    for (var i = 0; i < _destinations.length; i++) {
      final path = _destinations[i].path;
      if (location == path ||
          (location.startsWith(path) && path.length > bestLen)) {
        // Guard: '/admin' is a prefix of everything, so only match it exactly.
        if (path == R.adminDashboard && location != R.adminDashboard) continue;
        best = i;
        bestLen = path.length;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formFactor = AppBreakpoints.of(context);
    final location = GoRouterState.of(context).matchedLocation;
    final index = _selectedIndex(location);

    if (formFactor.isNarrow) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_destinations[index].label),
          actions: const [
            NotificationBell(),
            _ProfileButton(compact: true),
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: _NavList(
              destinations: _destinations,
              selectedIndex: index,
              extended: true,
              onSelect: (i) {
                Navigator.of(context).pop();
                context.go(_destinations[i].path);
              },
            ),
          ),
        ),
        body: child,
      );
    }

    final extended = formFactor.isDesktop;
    return Scaffold(
      body: Row(
        children: [
          _Rail(
            destinations: _destinations,
            selectedIndex: index,
            extended: extended,
            onSelect: (i) => context.go(_destinations[i].path),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.destinations,
    required this.selectedIndex,
    required this.extended,
    required this.onSelect,
  });

  final List<_NavItem> destinations;
  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 232 : 76,
      color: AppColors.surface,
      child: Column(
        children: [
          _Brand(extended: extended),
          Expanded(
            child: _NavList(
              destinations: destinations,
              selectedIndex: selectedIndex,
              extended: extended,
              onSelect: onSelect,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: extended
                ? const Row(
                    children: [
                      Expanded(child: _ProfileButton()),
                      NotificationBell(),
                    ],
                  )
                : const Column(
                    children: [
                      NotificationBell(),
                      SizedBox(height: AppSpacing.xs),
                      _ProfileButton(compact: true),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: extended ? AppSpacing.lg : 0),
      alignment: extended ? Alignment.centerLeft : Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.brass,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('ST',
                style: AppTypography.bodyStrong.copyWith(
                    color: AppColors.inkInverse, fontSize: 13)),
          ),
          if (extended) ...[
            const SizedBox(width: AppSpacing.sm),
            Text('Sublime', style: AppTypography.h3),
          ],
        ],
      ),
    );
  }
}

class _NavList extends ConsumerWidget {
  const _NavList({
    required this.destinations,
    required this.selectedIndex,
    required this.extended,
    required this.onSelect,
  });

  final List<_NavItem> destinations;
  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A badge on the Review + Drivers items when there's work waiting.
    final pending = ref.watch(pendingDriversProvider).value?.length ?? 0;
    final review = ref.watch(reviewQueueCountProvider).value ?? 0;

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: destinations.length,
      itemBuilder: (context, i) {
        final item = destinations[i];
        final selected = i == selectedIndex;
        final badge = switch (item.path) {
          R.adminDrivers when pending > 0 => pending,
          R.adminReview when review > 0 => review,
          _ => 0,
        };
        return _NavTile(
          item: item,
          selected: selected,
          extended: extended,
          badge: badge,
          onTap: () => onSelect(i),
        );
      },
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
    this.badge = 0,
  });

  final _NavItem item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brassPress : AppColors.inkMuted;
    final icon = Icon(selected ? item.activeIcon : item.icon, size: 22, color: color);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.brassTint : AppColors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: extended ? AppSpacing.md : 0),
            alignment: extended ? Alignment.centerLeft : Alignment.center,
            child: Row(
              mainAxisSize: extended ? MainAxisSize.max : MainAxisSize.min,
              children: [
                _withBadge(icon, badge),
                if (extended) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      item.label,
                      style: AppTypography.label.copyWith(
                        color: selected ? AppColors.brassPress : AppColors.inkBody,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _withBadge(Widget child, int count) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: const BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            constraints: const BoxConstraints(minWidth: 16),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.inkInverse,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileButton extends ConsumerWidget {
  const _ProfileButton({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final avatar = AppAvatar(
      name: user?.fullName ?? '?',
      imageUrl: user?.avatarUrl,
      size: AppAvatarSize.sm,
    );

    if (compact) {
      return IconButton(
        icon: avatar,
        tooltip: 'Profile',
        onPressed: () => context.push(R.profile),
      );
    }

    return Material(
      color: AppColors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => context.push(R.profile),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? '',
                      style: AppTypography.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('Admin', style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.label, this.icon, this.activeIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
}
