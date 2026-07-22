import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../../../data/models/enums.dart';
import '../../../providers/auth_providers.dart';

/// Drives sign-in, registration, password reset, and sign-out.
///
/// Its state is the async status of the in-flight action; the resulting
/// identity change flows through [currentUserProvider], which the router
/// watches — so a successful sign-in navigates without this controller touching
/// navigation at all.
class AuthController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
          );
      // Force the identity to re-resolve now so the router redirect fires
      // deterministically rather than waiting on the auth event.
      await ref.read(currentUserProvider.notifier).refresh();
    });
    state = result;
    return !result.hasError;
  }

  Future<bool> registerDriver({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    VehicleType? vehicleType,
    String? vehicleMake,
    String? vehiclePlate,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).registerDriver(
            email: email,
            password: password,
            fullName: fullName,
            phone: phone,
            vehicleType: vehicleType,
            vehicleMake: vehicleMake,
            vehiclePlate: vehiclePlate,
          );
      await ref.read(currentUserProvider.notifier).refresh();
    });
    state = result;
    return !result.hasError;
  }

  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).sendPasswordReset(email),
    );
    state = result;
    return !result.hasError;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }

  /// The current error mapped to an [AppException], or null.
  AppException? get errorOrNull {
    final e = state.error;
    return e == null ? null : ErrorMapper.map(e, state.stackTrace);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
