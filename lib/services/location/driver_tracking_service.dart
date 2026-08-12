import 'dart:async';

import 'location_capture.dart';
import 'location_service.dart';

/// Posts a single position fix for a ride to the server. Injected so the
/// throttling logic can be tested without a live Supabase client; the provider
/// wires the real `record_location_ping` RPC.
typedef PingSender = Future<void> Function(String rideId, LocationFix fix);

/// Streams the driver's position to the server during a live ride so the admin
/// map glides between status changes. This is the optional continuous-tracking
/// feature — capture at every status change (in `advance_ride_status`) is the
/// hard requirement and is entirely independent of this service.
///
/// Design choices that matter:
///  - **Not** routed through the offline outbox. Pings are ephemeral and
///    superseded by the next one; queuing a stale position to replay minutes
///    later would put a ghost on the map. If a post fails (offline), it's
///    dropped and the next tick carries the freshest fix.
///  - **Throttled to one write per [_minInterval]**, regardless of how fast the
///    stream emits, so a fast-moving driver doesn't hammer the RPC. The most
///    recent fix always wins.
///  - Foreground-only (the plugin's default). Background location is a separate
///    store-review surface the spec doesn't require.
class DriverTrackingService {
  DriverTrackingService(this._location, {required PingSender sender})
      : _sender = sender;

  final LocationService _location;
  final PingSender _sender;

  static const _minInterval = Duration(seconds: 30);

  StreamSubscription<LocationFix>? _sub;
  Timer? _flushTimer;
  String? _rideId;
  LocationFix? _pending;
  DateTime? _lastSentAt;

  bool get isTracking => _sub != null;
  String? get trackingRideId => _rideId;

  /// Begin streaming for [rideId]. Idempotent: starting the same ride again is a
  /// no-op; starting a different ride switches targets cleanly.
  Future<void> start(String rideId) async {
    if (_rideId == rideId && _sub != null) return;
    await stop();
    _rideId = rideId;
    _sub = _location.positionStream().listen(
      (fix) {
        _pending = fix;
        _maybeFlush();
      },
      onError: (_) {}, // A stream hiccup shouldn't crash the ride screen.
      cancelOnError: false,
    );
    // A heartbeat so a stationary driver (no new stream points) still refreshes
    // their "last seen" and doesn't fade to stale on the admin map.
    _flushTimer = Timer.periodic(_minInterval, (_) => _maybeFlush(force: true));
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _rideId = null;
    _pending = null;
    _lastSentAt = null;
  }

  void _maybeFlush({bool force = false}) {
    final fix = _pending;
    final rideId = _rideId;
    if (fix == null || rideId == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!) < _minInterval) {
      return; // Too soon; the periodic timer will pick this up.
    }
    _lastSentAt = now;
    unawaited(_send(rideId, fix));
  }

  Future<void> _send(String rideId, LocationFix fix) async {
    try {
      await _sender(rideId, fix);
    } catch (_) {
      // Offline or transient — drop it. The next fix supersedes this one.
    }
  }
}
