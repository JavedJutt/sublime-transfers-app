import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/app_exception.dart';
import '../core/error/error_mapper.dart';
import '../data/models/gmail_account.dart';
import '../data/models/inbound_email.dart';
import '../data/repositories/gmail_repository.dart';
import '../data/repositories/review_queue_repository.dart';
import '../data/sources/supabase_client_provider.dart';
import 'ride_providers.dart';

// ------------------------------------------------------------- review queue
final reviewQueueRepositoryProvider = Provider<ReviewQueueRepository>((ref) {
  return ReviewQueueRepository(ref.watch(supabaseClientProvider));
});

/// Emails awaiting a human decision.
final reviewQueueProvider = FutureProvider<List<InboundEmail>>((ref) async {
  return ref.watch(reviewQueueRepositoryProvider).pending();
});

/// The count for the nav badge and the dashboard stat.
final reviewQueueCountProvider = FutureProvider<int>((ref) async {
  final items = await ref.watch(reviewQueueProvider.future);
  return items.length;
});

/// A single email for the review detail screen.
final reviewEmailProvider =
    FutureProvider.family<InboundEmail?, String>((ref, id) async {
  return ref.watch(reviewQueueRepositoryProvider).byId(id);
});

// -------------------------------------------------------------------- gmail
final gmailRepositoryProvider = Provider<GmailRepository>((ref) {
  return GmailRepository(ref.watch(supabaseClientProvider));
});

/// Connected mailboxes for the settings screen.
final gmailAccountsProvider = FutureProvider<List<GmailAccount>>((ref) async {
  return ref.watch(gmailRepositoryProvider).accounts();
});

/// Whether any mailbox is in error — drives the persistent "Gmail sync failed"
/// banner on the dashboard.
final gmailHasErrorProvider = FutureProvider<bool>((ref) async {
  final accounts = await ref.watch(gmailAccountsProvider.future);
  return accounts.any((a) => a.hasError && a.isActive);
});

// -------------------------------------------------------------- controller
/// Drives the review-queue actions: importing a corrected email into a ride,
/// rejecting a non-booking, and re-running the parser. On a successful import
/// the ride caches are invalidated so the new ride appears everywhere at once.
class ReviewController extends AsyncNotifier<void> {
  @override
  void build() {}

  /// Import the (edited) payload as a ride. Returns the new ride id, or null on
  /// failure (read [errorOrNull]).
  Future<String?> import(String emailId, Map<String, dynamic> payload) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(reviewQueueRepositoryProvider).import(emailId, payload),
    );
    state = result.hasError ? AsyncError(result.error!, result.stackTrace!) : const AsyncData(null);
    if (!result.hasError) _invalidate(emailId);
    return result.value;
  }

  Future<bool> reject(String emailId, {String? reason}) async {
    return _run(emailId, () => ref
        .read(reviewQueueRepositoryProvider)
        .reject(emailId, reason: reason));
  }

  Future<bool> reparse(String emailId) async {
    return _run(emailId,
        () => ref.read(reviewQueueRepositoryProvider).reparse(emailId));
  }

  Future<bool> _run(String emailId, Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    state = result;
    if (!result.hasError) _invalidate(emailId);
    return !result.hasError;
  }

  void _invalidate(String emailId) {
    ref.invalidate(reviewQueueProvider);
    ref.invalidate(reviewEmailProvider(emailId));
    // A new ride may have appeared — refresh the ride views.
    ref.invalidate(calendarRidesProvider);
    ref.invalidate(rideListProvider);
    ref.invalidate(todayRidesProvider);
    ref.invalidate(dashboardStatsProvider);
  }

  AppException? get errorOrNull {
    final e = state.error;
    return e == null ? null : ErrorMapper.map(e, state.stackTrace);
  }
}

final reviewControllerProvider =
    AsyncNotifierProvider<ReviewController, void>(ReviewController.new);
