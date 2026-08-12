import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../core/error/error_mapper.dart';
import '../../data/sources/local/outbox.dart';
import 'connectivity_service.dart';

/// Drains the outbox when connectivity returns.
///
/// Every queued item carries a `p_client_event_id`; the server records it in
/// `client_events` with `on conflict do nothing`, so re-sending an item that
/// actually did land the first time is a harmless no-op. That is what makes it
/// safe to retry aggressively without double-advancing a ride.
class SyncService {
  SyncService({
    required Outbox outbox,
    required SupabaseClient client,
    required ConnectivityService connectivity,
  })  : _outbox = outbox,
        _client = client,
        _connectivity = connectivity;

  final Outbox _outbox;
  final SupabaseClient _client;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _sub;
  bool _draining = false;

  final _pendingCount = StreamController<int>.broadcast();

  /// A live count of queued items, for the offline banner.
  Stream<int> get pendingCount => _pendingCount.stream;

  void start() {
    _sub = _connectivity.onlineChanges().listen((online) {
      if (online) drain();
    });
    // Attempt an initial drain in case we start online with a backlog.
    drain();
  }

  Future<void> _emitCount() async {
    _pendingCount.add(await _outbox.count());
  }

  /// Drain the outbox FIFO. Business-rule failures (a lost broadcast race, an
  /// invalid transition after the ride moved on) are dropped rather than
  /// retried forever; only network failures keep an item queued.
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      final items = await _outbox.pending();
      for (final item in items) {
        try {
          await _client.rpc(item.rpc, params: item.payload);
          await _outbox.remove(item.id);
        } catch (error, stack) {
          final mapped = ErrorMapper.map(error, stack);
          if (mapped is NetworkFailure) {
            // Still offline / server unreachable — stop; try again next event.
            await _outbox.bumpAttempt(item.id, mapped.message);
            break;
          }
          // Won't succeed on retry (already claimed, invalid transition). The
          // idempotency ledger means if it *had* landed, this is a no-op error;
          // either way, drop it.
          await _outbox.remove(item.id);
        }
      }
    } finally {
      _draining = false;
      await _emitCount();
    }
  }

  Future<int> refreshCount() async {
    final c = await _outbox.count();
    _pendingCount.add(c);
    return c;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _pendingCount.close();
  }
}
