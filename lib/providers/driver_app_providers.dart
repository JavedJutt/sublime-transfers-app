import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env/app_env.dart';
import '../core/utils/date_x.dart';
import '../data/models/ride.dart';
import '../data/repositories/driver_ride_repository.dart';
import '../data/sources/local/outbox.dart';
import '../data/sources/supabase_client_provider.dart';
import '../services/connectivity/connectivity_service.dart';
import '../services/connectivity/sync_service.dart';
import '../services/location/geolocator_location_service.dart';
import '../services/location/location_service.dart';

// ------------------------------------------------------------- infrastructure
/// The opened outbox database. Async because sqflite opens on disk. Overridden
/// in tests with an in-memory or fake outbox.
final outboxProvider = FutureProvider<Outbox>((ref) async {
  final outbox = await Outbox.open();
  ref.onDispose(outbox.close);
  return outbox;
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return const GeolocatorLocationService();
});

/// Online/offline stream for the offline banner.
final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onlineChanges();
});

/// The sync service, started once the outbox is open. Drains queued driver
/// actions on reconnect.
final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final outbox = await ref.watch(outboxProvider.future);
  final service = SyncService(
    outbox: outbox,
    client: ref.watch(supabaseClientProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
});

/// Live count of pending outbox items for the offline banner. Zero until the
/// outbox is ready.
final pendingSyncCountProvider = StreamProvider<int>((ref) async* {
  final sync = await ref.watch(syncServiceProvider.future);
  await sync.refreshCount();
  yield* sync.pendingCount;
});

// --------------------------------------------------------------- driver data
/// The driver ride repository, available once the outbox is open.
final driverRideRepositoryProvider =
    FutureProvider<DriverRideRepository>((ref) async {
  final outbox = await ref.watch(outboxProvider.future);
  return DriverRideRepository(ref.watch(supabaseClientProvider), outbox);
});

/// The day the driver is viewing on their home screen.
final driverSelectedDayProvider =
    NotifierProvider<DriverSelectedDay, DateTime>(DriverSelectedDay.new);

class DriverSelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now().dayStart;
  void set(DateTime d) => state = d.dayStart;
  void today() => state = DateTime.now().dayStart;
}

/// The driver's rides for the selected day.
final driverDayRidesProvider = FutureProvider<List<Ride>>((ref) async {
  final repo = await ref.watch(driverRideRepositoryProvider.future);
  final day = ref.watch(driverSelectedDayProvider);
  return repo.ridesForDay(day);
});

/// The driver's current active ride (live status), if any. Drives the "active
/// ride" tab and the big status-advance button.
final driverActiveRideProvider = FutureProvider<Ride?>((ref) async {
  final repo = await ref.watch(driverRideRepositoryProvider.future);
  return repo.activeRide();
});

/// The driver's finished rides, most recent first.
final driverHistoryProvider = FutureProvider<List<Ride>>((ref) async {
  final repo = await ref.watch(driverRideRepositoryProvider.future);
  return repo.history();
});

/// A single ride the driver can see, for the detail and active-ride screens.
final driverRideProvider =
    FutureProvider.family<Ride?, String>((ref, rideId) async {
  final repo = await ref.watch(driverRideRepositoryProvider.future);
  return repo.rideById(rideId);
});

/// Pending offers (direct + broadcast) for the driver.
final driverOffersProvider = FutureProvider<DriverOffers>((ref) async {
  final repo = await ref.watch(driverRideRepositoryProvider.future);
  return repo.offers();
});

/// Whether continuous GPS tracking is enabled (a nice-to-have, off by default).
final continuousTrackingEnabledProvider = Provider<bool>((ref) {
  return AppEnv.continuousTrackingEnabled;
});
