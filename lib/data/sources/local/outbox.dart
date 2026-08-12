import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// A queued driver mutation awaiting delivery. Every driver-side action is
/// written here *before* the network call, so a status advance made in a tunnel
/// survives an app kill and syncs on reconnect. Each carries a
/// `clientEventId` the server dedupes on, making replay a no-op.
class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.clientEventId,
    required this.rpc,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final int id;
  final String clientEventId;

  /// The RPC to call: advance_ride_status | respond_to_offer |
  /// claim_broadcast_ride.
  final String rpc;
  final Map<String, dynamic> payload;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;

  factory OutboxItem.fromRow(Map<String, dynamic> r) => OutboxItem(
        id: r['id'] as int,
        clientEventId: r['client_event_id'] as String,
        rpc: r['rpc'] as String,
        payload: jsonDecode(r['payload'] as String) as Map<String, dynamic>,
        attempts: r['attempts'] as int,
        lastError: r['last_error'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      );
}

/// The local outbox store. A thin sqflite wrapper; the draining lives in
/// `SyncService`.
class Outbox {
  Outbox._(this._db);

  final Database _db;

  static const _table = 'outbox';

  /// Opens the outbox database. [path] defaults to the on-device store;
  /// tests pass `inMemoryDatabasePath` (with the ffi factory) for isolation.
  static Future<Outbox> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'sublime_outbox.db');
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          create table $_table (
            id integer primary key autoincrement,
            client_event_id text not null unique,
            rpc text not null,
            payload text not null,
            attempts integer not null default 0,
            last_error text,
            created_at integer not null
          )
        ''');
      },
    );
    return Outbox._(db);
  }

  /// Enqueue an action. Returns the row id.
  Future<int> enqueue({
    required String clientEventId,
    required String rpc,
    required Map<String, dynamic> payload,
  }) {
    return _db.insert(_table, {
      'client_event_id': clientEventId,
      'rpc': rpc,
      'payload': jsonEncode(payload),
      'attempts': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Pending items, oldest first (FIFO drain order).
  Future<List<OutboxItem>> pending() async {
    final rows = await _db.query(_table, orderBy: 'id asc');
    return rows.map(OutboxItem.fromRow).toList();
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('select count(*) c from $_table');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> remove(int id) =>
      _db.delete(_table, where: 'id = ?', whereArgs: [id]);

  Future<void> bumpAttempt(int id, String error) async {
    await _db.rawUpdate(
      'update $_table set attempts = attempts + 1, last_error = ? where id = ?',
      [error, id],
    );
  }

  Future<void> close() => _db.close();
}
