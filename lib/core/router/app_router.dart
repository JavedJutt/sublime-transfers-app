import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_user.dart';
import '../../data/models/user_role.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/admin/presentation/calendar_screen.dart';
import '../../features/admin/presentation/dashboard_screen.dart';
import '../../features/admin/presentation/driver_approvals_screen.dart';
import '../../features/admin/presentation/driver_detail_screen.dart';
import '../../features/admin/presentation/drivers_screen.dart';
import '../../features/admin/presentation/gmail_settings_screen.dart';
import '../../features/admin/presentation/live_map_screen.dart';
import '../../features/admin/presentation/review_detail_screen.dart';
import '../../features/admin/presentation/review_queue_screen.dart';
import '../../features/admin/presentation/ride_detail_screen.dart';
import '../../features/admin/presentation/ride_form_screen.dart';
import '../../features/admin/presentation/ride_list_screen.dart';
import '../../features/auth/presentation/driver_register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/pending_approval_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/dev/component_gallery_screen.dart';
import '../../features/driver/presentation/active_ride_screen.dart';
import '../../features/driver/presentation/driver_history_screen.dart';
import '../../features/driver/presentation/driver_home_screen.dart';
import '../../features/driver/presentation/driver_offers_screen.dart';
import '../../features/driver/presentation/driver_ride_detail_screen.dart';
import '../../features/driver/presentation/driver_shell.dart';
import '../../providers/auth_providers.dart';
import 'routes.dart';

// Navigator keys. The root key hosts full-screen routes (ride form/detail,
// driver detail/approvals) that push *over* the admin shell; the shell key
// hosts the tabbed content inside the nav chrome.
final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();
final _driverShellKey = GlobalKey<NavigatorState>();

/// The app router with a single role-aware redirect.
///
/// [currentUserProvider] is the one identity source; the redirect reads it and
/// `refreshListenable` re-runs the guard whenever it changes, so sign-in,
/// sign-out, and approval all reroute in one hop. Feature routes for admin and
/// driver shells are registered in later phases.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: R.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) => _guard(ref, state),
    routes: [
      GoRoute(
        path: R.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: R.signIn,
        builder: (_, _) => const SignInScreen(),
      ),
      GoRoute(
        path: R.register,
        builder: (_, _) => const DriverRegisterScreen(),
      ),
      GoRoute(
        path: R.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: R.pendingApproval,
        builder: (_, _) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: R.profile,
        builder: (_, _) => const ProfileScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: R.components,
          builder: (_, _) => const ComponentGalleryScreen(),
        ),

      // -------------------------------------------------------------- admin
      // The shell provides the responsive nav chrome; child routes render into
      // it. Ride create/edit/detail are pushed on top (full-screen) rather than
      // nested in the shell, so the form and detail get their own app bar.
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: R.adminDashboard,
            builder: (_, _) => const DashboardScreen(),
          ),
          GoRoute(
            path: R.adminCalendar,
            builder: (_, _) => const CalendarScreen(),
          ),
          GoRoute(
            path: R.adminRides,
            builder: (_, _) => const RideListScreen(),
          ),
          GoRoute(
            path: R.adminLiveMap,
            builder: (_, _) => const LiveMapScreen(),
          ),
          GoRoute(
            path: R.adminDrivers,
            builder: (_, _) => const DriversScreen(),
            routes: [
              // Nested under /admin/drivers; `approvals` before `:driverId`.
              GoRoute(
                path: 'approvals',
                parentNavigatorKey: _rootKey,
                builder: (_, _) => const DriverApprovalsScreen(),
              ),
              GoRoute(
                path: ':driverId',
                parentNavigatorKey: _rootKey,
                builder: (_, state) =>
                    DriverDetailScreen(driverId: state.pathParameters['driverId']!),
              ),
            ],
          ),
          GoRoute(
            path: R.adminReview,
            builder: (_, _) => const ReviewQueueScreen(),
          ),
          GoRoute(
            path: R.adminGmail,
            builder: (_, _) => const GmailSettingsScreen(),
          ),
        ],
      ),
      // Full-screen admin routes (own app bar, pushed over the shell).
      // `new` is declared before the `:rideId` route so it matches first and a
      // ride can never have the id "new".
      GoRoute(
        path: R.adminRideNew,
        builder: (_, _) => const RideFormScreen(),
      ),
      GoRoute(
        path: R.adminRideEdit,
        builder: (_, state) =>
            RideFormScreen(rideId: state.pathParameters['rideId']!),
      ),
      GoRoute(
        path: R.adminRideDetail,
        builder: (_, state) =>
            RideDetailScreen(rideId: state.pathParameters['rideId']!),
      ),
      GoRoute(
        path: R.adminReviewItem,
        builder: (_, state) =>
            ReviewDetailScreen(emailId: state.pathParameters['emailId']!),
      ),

      // ------------------------------------------------------------- driver
      // Mobile-first shell: a three-tab bottom bar with an offline banner. Ride
      // detail and the active-ride controls push full-screen over it.
      ShellRoute(
        navigatorKey: _driverShellKey,
        builder: (context, state, child) => DriverShell(child: child),
        routes: [
          GoRoute(
            path: R.driverHome,
            builder: (_, _) => const DriverHomeScreen(),
          ),
          GoRoute(
            path: R.driverOffers,
            builder: (_, _) => const DriverOffersScreen(),
          ),
          GoRoute(
            path: R.driverHistory,
            builder: (_, _) => const DriverHistoryScreen(),
          ),
          GoRoute(
            path: R.driverProfile,
            builder: (_, _) => const ProfileScreen(),
          ),
        ],
      ),
      // Full-screen driver routes. `active` is nested so its path resolves, and
      // both push over the shell with their own app bar.
      GoRoute(
        path: R.driverRideDetail,
        builder: (_, state) =>
            DriverRideDetailScreen(rideId: state.pathParameters['rideId']!),
      ),
      GoRoute(
        path: R.driverActiveRide,
        builder: (_, state) =>
            ActiveRideScreen(rideId: state.pathParameters['rideId']!),
      ),
    ],
  );
});

/// Public paths reachable without a session.
const _publicPaths = {R.signIn, R.register, R.forgotPassword};

String? _guard(Ref ref, GoRouterState state) {
  final auth = ref.read(currentUserProvider);
  final loc = state.matchedLocation;

  // The gallery is a debug-only escape hatch; never redirect away from it.
  if (kDebugMode && loc == R.components) return null;

  // Still resolving the session — hold on the splash.
  if (auth.isLoading && !auth.hasValue) {
    return loc == R.splash ? null : R.splash;
  }

  // Resolution failed (bad session, network). Send to sign-in unless already
  // on a public path.
  if (auth.hasError) {
    return _publicPaths.contains(loc) ? null : R.signIn;
  }

  final AppUser? user = auth.value;

  // Signed out.
  if (user == null) {
    return _publicPaths.contains(loc) ? null : R.signIn;
  }

  // A driver awaiting approval is confined to the pending screen and profile.
  if (user.isPendingApproval) {
    return (loc == R.pendingApproval || loc == R.profile)
        ? null
        : R.pendingApproval;
  }

  final home = R.homeFor(isAdmin: user.isAdmin);

  // Signed in but sitting on splash/public/pending — go home.
  if (loc == R.splash ||
      _publicPaths.contains(loc) ||
      loc == R.pendingApproval) {
    return home;
  }

  // Cross-role containment: keep each role inside its own tree.
  if (loc.startsWith('/admin') && user.role != UserRole.admin) return home;
  if (loc.startsWith('/driver') && user.role != UserRole.driver) return home;

  return null;
}
