import 'location_capture.dart';

/// Native geolocation, abstracted so the status-flow logic can be unit-tested
/// against a fake and so we never couple to the plugin directly.
///
/// Location is captured via the *device's* geolocation (geolocator), never the
/// Maps SDK — the Maps key is admin-side rendering only.
abstract interface class LocationService {
  /// Current permission/service state, without prompting.
  Future<LocationPermissionState> checkPermission();

  /// Request permission (after the app has shown its own rationale). Returns
  /// the resulting state.
  Future<LocationPermissionState> requestPermission();

  /// Open the OS app-settings page, for the permanently-denied path.
  Future<bool> openSettings();

  /// One-shot capture for a status change. Applies the capture policy
  /// (timeout, last-known fallback) and **never throws** — a failure comes back
  /// as [LocationUnavailable] so the caller can still advance the ride.
  Future<LocationCapture> captureForStatusChange();

  /// A continuous position stream for the optional live-tracking feature. Only
  /// started between `en_route` and `completed`, behind a feature flag.
  Stream<LocationFix> positionStream();
}

/// Permission + service status, collapsed to what the app needs to decide.
enum LocationPermissionState {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled;

  bool get isGranted => this == LocationPermissionState.granted;
  bool get canRequest => this == LocationPermissionState.denied;
  bool get needsSettings => this == LocationPermissionState.permanentlyDenied;
}
