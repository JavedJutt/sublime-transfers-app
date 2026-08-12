import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../data/models/ride.dart';
import '../../../../data/models/ride_status.dart';
import '../../../../providers/map_providers.dart';

/// A position is "stale" once it is older than this — the driver marker fades
/// and the list annotates "last seen …". Continuous tracking posts every ~30s,
/// and a status-change fix lands at each leg, so five minutes without either is
/// a genuine signal that the app has gone quiet, not just a gap between pings.
const staleAfter = Duration(minutes: 5);

/// The fleet map. One marker per active driver at their last known position,
/// tinted by ride status and faded when stale; a lighter pickup marker for a
/// ride whose driver has not set off yet. Tapping a marker selects the ride;
/// the selection drives the camera and the side panel.
///
/// Markers come straight from the denormalised `driver_last_*` columns on
/// `admin_rides`, so there is no extra query — the same [activeRidesProvider]
/// that feeds the list feeds the map.
class FleetMap extends ConsumerStatefulWidget {
  const FleetMap({super.key, required this.rides});

  final List<Ride> rides;

  @override
  ConsumerState<FleetMap> createState() => _FleetMapState();
}

class _FleetMapState extends ConsumerState<FleetMap> {
  final _controller = Completer<GoogleMapController>();
  bool _didInitialFit = false;

  // Central London — the camera's home until we have markers to fit.
  static const _fallbackCamera = CameraPosition(
    target: LatLng(51.5074, -0.1278),
    zoom: 10,
  );

  @override
  void didUpdateWidget(FleetMap old) {
    super.didUpdateWidget(old);
    // Re-fit only when the fleet's membership changes, not on every position
    // nudge — otherwise the camera would fight an admin who has panned away.
    if (_rideIds(old.rides) != _rideIds(widget.rides)) {
      _didInitialFit = false;
      _maybeFit();
    }
  }

  Set<String> _rideIds(List<Ride> rides) => rides.map((r) => r.id).toSet();

  Set<Marker> _markers() {
    final selected = ref.watch(selectedMapRideProvider);
    final markers = <Marker>{};
    final now = DateTime.now();

    for (final ride in widget.rides) {
      if (ride.hasDriverLocation) {
        final stale = ride.driverLastLocationAt == null ||
            now.difference(ride.driverLastLocationAt!) > staleAfter;
        markers.add(
          Marker(
            markerId: MarkerId('driver_${ride.id}'),
            position: LatLng(ride.driverLastLat!, ride.driverLastLng!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              stale ? BitmapDescriptor.hueViolet : _statusHue(ride.status),
            ),
            alpha: stale ? 0.6 : 1.0,
            zIndexInt: ride.id == selected ? 2 : 1,
            infoWindow: InfoWindow(
              title: ride.driverName ?? 'Driver',
              snippet: '${ride.status.label} · ${ride.reference}',
            ),
            onTap: () => ref.read(selectedMapRideProvider.notifier).select(ride.id),
          ),
        );
      } else if (ride.hasPickupCoords &&
          (ride.status == RideStatus.assigned ||
              ride.status == RideStatus.enRoute)) {
        // No driver fix yet — show where they're headed so the ride isn't
        // invisible on the map.
        markers.add(
          Marker(
            markerId: MarkerId('pickup_${ride.id}'),
            position: LatLng(ride.pickupLat!, ride.pickupLng!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            alpha: 0.8,
            infoWindow: InfoWindow(
              title: 'Pickup · ${ride.reference}',
              snippet: ride.pickupAddress,
            ),
            onTap: () => ref.read(selectedMapRideProvider.notifier).select(ride.id),
          ),
        );
      }
    }
    return markers;
  }

  /// Ride status → Google marker hue, echoing the app's status palette: live
  /// legs brass-ish (orange), freshly assigned blue.
  static double _statusHue(RideStatus status) => switch (status) {
        RideStatus.assigned => BitmapDescriptor.hueAzure,
        RideStatus.enRoute => BitmapDescriptor.hueOrange,
        RideStatus.arrived => BitmapDescriptor.hueYellow,
        RideStatus.inProgress => BitmapDescriptor.hueGreen,
        _ => BitmapDescriptor.hueRose,
      };

  List<LatLng> _points() {
    final pts = <LatLng>[];
    for (final ride in widget.rides) {
      if (ride.hasDriverLocation) {
        pts.add(LatLng(ride.driverLastLat!, ride.driverLastLng!));
      } else if (ride.hasPickupCoords) {
        pts.add(LatLng(ride.pickupLat!, ride.pickupLng!));
      }
    }
    return pts;
  }

  Future<void> _maybeFit() async {
    if (_didInitialFit || !_controller.isCompleted) return;
    final pts = _points();
    if (pts.isEmpty) return;
    _didInitialFit = true;
    final controller = await _controller.future;
    if (pts.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(pts.first, 13),
      );
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsOf(pts), 64),
    );
  }

  static LatLngBounds _boundsOf(List<LatLng> pts) {
    var minLat = pts.first.latitude, maxLat = pts.first.latitude;
    var minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pan to the selected ride's marker whenever the selection changes.
    ref.listen(selectedMapRideProvider, (_, id) => _focus(id));

    return GoogleMap(
      initialCameraPosition: _fallbackCamera,
      markers: _markers(),
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      onMapCreated: (c) {
        if (!_controller.isCompleted) _controller.complete(c);
        _maybeFit();
      },
    );
  }

  Future<void> _focus(String? id) async {
    if (id == null || !_controller.isCompleted) return;
    final ride = widget.rides.where((r) => r.id == id).firstOrNull;
    if (ride == null) return;
    final LatLng? target = ride.hasDriverLocation
        ? LatLng(ride.driverLastLat!, ride.driverLastLng!)
        : ride.hasPickupCoords
            ? LatLng(ride.pickupLat!, ride.pickupLng!)
            : null;
    if (target == null) return;
    final controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(target, 14));
  }
}
