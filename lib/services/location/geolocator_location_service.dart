import 'package:geolocator/geolocator.dart';

import 'location_capture.dart';
import 'location_service.dart';

/// The real [LocationService], over the `geolocator` plugin.
///
/// The capture policy embodies the hard requirement that a status change is
/// never blocked by GPS: it tries for a fresh high-accuracy fix, falls back to
/// a recent last-known position, and otherwise returns [LocationUnavailable] —
/// but always returns, so the ride can advance and the absence is recorded.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static const _fixTimeout = Duration(seconds: 8);
  static const _lastKnownMaxAge = Duration(minutes: 2);
  static const _lastKnownMaxAccuracy = 200.0; // metres

  @override
  Future<LocationPermissionState> checkPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionState.serviceDisabled;
    }
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationPermissionState> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionState.serviceDisabled;
    }
    return _map(await Geolocator.requestPermission());
  }

  @override
  Future<bool> openSettings() => Geolocator.openAppSettings();

  @override
  Future<LocationCapture> captureForStatusChange() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationUnavailable(
          LocationUnavailableReason.serviceDisabled,
        );
      }

      final permission = _map(await Geolocator.checkPermission());
      if (permission == LocationPermissionState.permanentlyDenied) {
        return const LocationUnavailable(
          LocationUnavailableReason.permanentlyDenied,
        );
      }
      if (permission == LocationPermissionState.denied) {
        return const LocationUnavailable(LocationUnavailableReason.denied);
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: _fixTimeout,
          ),
        );
        return _toFix(pos, LocationSource.gps);
      } on Exception {
        // Timed out or failed — try a recent last-known position.
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp) < _lastKnownMaxAge &&
            (last.accuracy) <= _lastKnownMaxAccuracy) {
          return _toFix(last, LocationSource.lastKnown);
        }
        return const LocationUnavailable(LocationUnavailableReason.timeout);
      }
    } on Exception {
      return const LocationUnavailable(LocationUnavailableReason.unknown);
    }
  }

  @override
  Stream<LocationFix> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).map((p) => _toFix(p, LocationSource.gps));
  }

  LocationFix _toFix(Position p, LocationSource source) => LocationFix(
        lat: p.latitude,
        lng: p.longitude,
        accuracyM: p.accuracy,
        heading: p.heading,
        speedMps: p.speed,
        capturedAt: p.timestamp,
        source: source,
      );

  LocationPermissionState _map(LocationPermission p) => switch (p) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          LocationPermissionState.granted,
        LocationPermission.denied => LocationPermissionState.denied,
        LocationPermission.deniedForever =>
          LocationPermissionState.permanentlyDenied,
        LocationPermission.unableToDetermine =>
          LocationPermissionState.denied,
      };
}
