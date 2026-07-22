import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/app_user.dart';
import '../data/models/user_role.dart';
import '../data/repositories/auth_repository.dart';
import '../data/sources/supabase_client_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// The single source of truth for identity and role.
///
/// Rebuilds whenever Supabase reports an auth change (sign in/out, token
/// refresh, user update) and re-resolves the [AppUser] — profile joined with
/// driver profile. Everything downstream (role, approval, the router guard)
/// reads from here, so a change propagates in one hop.
class CurrentUser extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    // Rebuild on every auth event.
    final sub = ref
        .watch(supabaseClientProvider)
        .auth
        .onAuthStateChange
        .listen((state) {
      // signedOut clears immediately; other events trigger a re-resolve.
      switch (state.event) {
        case AuthChangeEvent.signedOut:
          this.state = const AsyncData(null);
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.userUpdated:
        case AuthChangeEvent.tokenRefreshed:
          ref.invalidateSelf();
        default:
          break;
      }
    });
    ref.onDispose(sub.cancel);

    return ref.read(authRepositoryProvider).resolveCurrentUser();
  }

  /// Re-fetch the profile — used after a profile edit or an approval poll.
  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).resolveCurrentUser(),
    );
  }
}

final currentUserProvider =
    AsyncNotifierProvider<CurrentUser, AppUser?>(CurrentUser.new);

/// The resolved role, or null while loading / signed out. Reads only from
/// [currentUserProvider] so it never touches Supabase directly.
final roleProvider = Provider<UserRole?>((ref) {
  return ref.watch(currentUserProvider).value?.role;
});

final isApprovedDriverProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.isDriver == true && user?.isApproved == true;
});

/// A [Listenable] that pokes GoRouter to re-run its redirect whenever identity
/// changes. GoRouter's refreshListenable wants a ChangeNotifier, so we adapt
/// the provider into one.
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(this._ref) {
    _sub = _ref.listen<AsyncValue<AppUser?>>(
      currentUserProvider,
      (_, _) => notifyListeners(),
      fireImmediately: false,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<AppUser?>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final routerRefreshProvider = Provider<RouterRefresh>((ref) {
  final refresh = RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});
