import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sources/supabase_client_provider.dart';
import '../services/location/driver_tracking_service.dart';
import '../services/location/location_service.dart';
import 'driver_app_providers.dart';

/// The driver's current location permission state, re-checkable after a system
/// prompt or a return from settings.
class LocationPermission extends AsyncNotifier<LocationPermissionState> {
  @override
  Future<LocationPermissionState> build() {
    return ref.read(locationServiceProvider).checkPermission();
  }

  /// Show the system prompt (the caller shows the in-app rationale first).
  Future<LocationPermissionState> request() async {
    final result =
        await ref.read(locationServiceProvider).requestPermission();
    state = AsyncData(result);
    return result;
  }

  /// Re-check after the user returns from system settings.
  Future<void> recheck() async {
    state = AsyncData(
      await ref.read(locationServiceProvider).checkPermission(),
    );
  }

  Future<bool> openSettings() =>
      ref.read(locationServiceProvider).openSettings();
}

final locationPermissionProvider =
    AsyncNotifierProvider<LocationPermission, LocationPermissionState>(
  LocationPermission.new,
);

/// Streams the driver's position to the server during a live ride (the optional
/// continuous-tracking feature, gated by `CONTINUOUS_TRACKING`). One instance
/// for the app; the active-ride screen starts and stops it by ride status.
final driverTrackingServiceProvider = Provider<DriverTrackingService>((ref) {
  final client = ref.read(supabaseClientProvider);
  final service = DriverTrackingService(
    ref.read(locationServiceProvider),
    sender: (rideId, fix) => client.rpc('record_location_ping', params: {
      'p_ride_id': rideId,
      'p_lat': fix.lat,
      'p_lng': fix.lng,
      'p_accuracy_m': fix.accuracyM,
      'p_heading': fix.heading,
      'p_speed_mps': fix.speedMps,
      'p_captured_at': fix.capturedAt.toUtc().toIso8601String(),
    }),
  );
  ref.onDispose(service.stop);
  return service;
});
