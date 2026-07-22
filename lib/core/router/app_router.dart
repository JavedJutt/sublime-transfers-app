import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/app_user.dart';
import '../../data/models/user_role.dart';
import '../../features/auth/presentation/driver_register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/pending_approval_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/dev/component_gallery_screen.dart';
import '../../providers/auth_providers.dart';
import 'routes.dart';

/// The app router with a single role-aware redirect.
///
/// [currentUserProvider] is the one identity source; the redirect reads it and
/// `refreshListenable` re-runs the guard whenever it changes, so sign-in,
/// sign-out, and approval all reroute in one hop. Feature routes for admin and
/// driver shells are registered in later phases.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
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
