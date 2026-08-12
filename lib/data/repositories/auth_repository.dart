import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/error_mapper.dart';
import '../models/app_user.dart';
import '../models/enums.dart';

/// Everything auth: sign in/up/out, session resolution, and profile updates.
///
/// Wraps every call in [ErrorMapper.guard] so callers only ever see an
/// [AppException], never a raw [AuthException] or [PostgrestException].
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  Session? get currentSession => _auth.currentSession;
  String? get currentUserId => _auth.currentUser?.id;

  Future<void> signIn({
    required String email,
    required String password,
  }) =>
      ErrorMapper.guard(() async {
        await _auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
      });

  /// Driver self-registration. Role and driver metadata are read by the
  /// `handle_new_user` trigger, which creates the profile + driver_profile
  /// (starting 'pending'). The account cannot receive rides until approved.
  Future<void> registerDriver({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    VehicleType? vehicleType,
    String? vehicleMake,
    String? vehiclePlate,
  }) =>
      ErrorMapper.guard(() async {
        await _auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'role': 'driver',
            'full_name': fullName.trim(),
            'phone': phone.trim(),
            if (vehicleType != null) 'vehicle_type': vehicleType.wire,
            if (vehicleMake != null && vehicleMake.trim().isNotEmpty)
              'vehicle_make': vehicleMake.trim(),
            if (vehiclePlate != null && vehiclePlate.trim().isNotEmpty)
              'vehicle_plate': vehiclePlate.trim(),
          },
        );
      });

  Future<void> sendPasswordReset(String email) => ErrorMapper.guard(() async {
        await _auth.resetPasswordForEmail(email.trim());
      });

  Future<void> signOut() => ErrorMapper.guard(() => _auth.signOut());

  /// Resolves the current session into an [AppUser], joining the driver profile
  /// when the user is a driver. Returns null when there is no session or the
  /// profile row hasn't been created yet (a brief race right after sign-up).
  Future<AppUser?> resolveCurrentUser() => ErrorMapper.guard(() async {
        final userId = currentUserId;
        if (userId == null) return null;

        final profile = await _client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (profile == null) return null;

        Map<String, dynamic>? driverProfile;
        if (profile['role'] == 'driver') {
          driverProfile = await _client
              .from('driver_profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();
        }

        return AppUser.fromProfile(profile, driverProfile: driverProfile);
      });

  Future<AppUser> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) =>
      ErrorMapper.guard(() async {
        final updates = <String, dynamic>{
          if (fullName != null) 'full_name': fullName.trim(),
          if (phone != null) 'phone': phone.trim(),
          'avatar_url': ?avatarUrl,
        };
        if (updates.isNotEmpty) {
          await _client.from('profiles').update(updates).eq('id', userId);
        }
        final resolved = await resolveCurrentUser();
        return resolved!;
      });

  /// Driver-only: update vehicle details on their own driver profile.
  Future<void> updateDriverVehicle({
    required String userId,
    VehicleType? vehicleType,
    String? vehicleMake,
    String? vehiclePlate,
  }) =>
      ErrorMapper.guard(() async {
        await _client.from('driver_profiles').update({
          if (vehicleType != null) 'vehicle_type': vehicleType.wire,
          if (vehicleMake != null) 'vehicle_make': vehicleMake.trim(),
          if (vehiclePlate != null) 'vehicle_plate': vehiclePlate.trim(),
        }).eq('id', userId);
      });
}
