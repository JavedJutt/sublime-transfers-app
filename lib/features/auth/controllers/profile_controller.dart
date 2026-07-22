import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../../../providers/auth_providers.dart';

/// Drives profile edits and sign-out from the profile screen.
class ProfileController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> save({required String fullName, required String phone}) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return false;

    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).updateProfile(
            userId: user.id,
            fullName: fullName,
            phone: phone,
          );
      await ref.read(currentUserProvider.notifier).refresh();
    });
    state = result;
    return !result.hasError;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }

  AppException? get errorOrNull {
    final e = state.error;
    return e == null ? null : ErrorMapper.map(e, state.stackTrace);
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, void>(ProfileController.new);
