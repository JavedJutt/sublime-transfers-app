import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/router/routes.dart';
import '../../../providers/driver_app_providers.dart';
import '../widgets/offline_banner.dart';

/// The driver app chrome: an offline banner above a three-tab bottom bar
/// (Today / Offers / Profile). Mobile-first — this is the driver's whole world.
class DriverShell extends ConsumerWidget {
  const DriverShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    (R.driverHome, 'Today', AppIcons.home, AppIcons.homeActive),
    (R.driverOffers, 'Offers', AppIcons.offers, AppIcons.offersActive),
    (R.driverProfile, 'Profile', AppIcons.profile, AppIcons.profileActive),
  ];

  int _index(String location) {
    if (location.startsWith(R.driverOffers)) return 1;
    if (location.startsWith(R.driverProfile)) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _index(location);
    final offerCount = ref.watch(driverOffersProvider).value?.total ?? 0;

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: [
          for (var i = 0; i < _tabs.length; i++)
            NavigationDestination(
              icon: _maybeBadge(Icon(_tabs[i].$3), i == 1 ? offerCount : 0),
              selectedIcon: _maybeBadge(Icon(_tabs[i].$4), i == 1 ? offerCount : 0),
              label: _tabs[i].$2,
            ),
        ],
      ),
    );
  }

  Widget _maybeBadge(Widget icon, int count) {
    if (count <= 0) return icon;
    return Badge(label: Text(count > 9 ? '9+' : '$count'), child: icon);
  }
}
