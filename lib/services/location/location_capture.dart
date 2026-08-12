/// The outcome of trying to capture a location fix.
///
/// A capture never *blocks* a status change — the status flow always proceeds
/// and records whichever of these it got. A successful fix carries coordinates;
/// a failure carries a reason the audit log and UI can present honestly.
sealed class LocationCapture {
  const LocationCapture();
}

/// A usable fix.
class LocationFix extends LocationCapture {
  const LocationFix({
    required this.lat,
    required this.lng,
    required this.capturedAt,
    this.accuracyM,
    this.heading,
    this.speedMps,
    this.source = LocationSource.gps,
  });

  final double lat;
  final double lng;
  final double? accuracyM;
  final double? heading;
  final double? speedMps;
  final DateTime capturedAt;
  final LocationSource source;
}

/// No fix, with the reason. The status change still goes through; the event is
/// recorded with `location_unavailable = true`.
class LocationUnavailable extends LocationCapture {
  const LocationUnavailable(this.reason, {this.message});

  final LocationUnavailableReason reason;
  final String? message;
}

enum LocationSource {
  gps,
  lastKnown,
}

enum LocationUnavailableReason {
  /// Location services are switched off device-wide.
  serviceDisabled,

  /// Permission not granted (but can still be requested).
  denied,

  /// Permission permanently denied — needs a trip to system settings.
  permanentlyDenied,

  /// A fix couldn't be obtained in time.
  timeout,

  /// Any other failure.
  unknown,
}

extension LocationUnavailableReasonX on LocationUnavailableReason {
  /// User-facing explanation.
  String get message => switch (this) {
        LocationUnavailableReason.serviceDisabled =>
          'Location is turned off on your device.',
        LocationUnavailableReason.denied =>
          'Location permission is needed to update ride status.',
        LocationUnavailableReason.permanentlyDenied =>
          'Location permission is off. Enable it in Settings to record ride '
              'updates.',
        LocationUnavailableReason.timeout =>
          'Couldn\'t get a location fix in time.',
        LocationUnavailableReason.unknown => 'Location is unavailable.',
      };

  /// Whether the right fix is a trip to system settings vs. an in-app prompt.
  bool get needsSettings => this == LocationUnavailableReason.permanentlyDenied;
}
