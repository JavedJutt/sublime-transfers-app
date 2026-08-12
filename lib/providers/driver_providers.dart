import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/driver_repository.dart';
import '../data/sources/supabase_client_provider.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(ref.watch(supabaseClientProvider));
});

/// All drivers, for the drivers screen.
final driverListProvider = FutureProvider<List<DriverListItem>>((ref) {
  return ref.watch(driverRepositoryProvider).fetchDrivers();
});

/// Approved drivers, for the driver filter and the assignment sheet.
final approvedDriversProvider = FutureProvider<List<DriverListItem>>((ref) {
  return ref.watch(driverRepositoryProvider).fetchApprovedDrivers();
});

/// Drivers awaiting approval, for the approvals screen and its dashboard count.
final pendingDriversProvider = FutureProvider<List<DriverListItem>>((ref) {
  return ref.watch(driverRepositoryProvider).fetchPendingDrivers();
});

/// A single driver by id, for the driver detail screen.
final driverDetailProvider =
    FutureProvider.family<DriverListItem?, String>((ref, id) async {
  final list = await ref.watch(driverRepositoryProvider).fetchDrivers();
  return list.where((d) => d.id == id).firstOrNull;
});
