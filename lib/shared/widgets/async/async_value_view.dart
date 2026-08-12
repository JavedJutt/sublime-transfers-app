import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_mapper.dart';
import '../feedback/error_state.dart';
import '../feedback/loading_view.dart';

/// Renders an [AsyncValue] across all four of its states.
///
/// **No screen in this app calls `AsyncValue.when()` directly.** Going through
/// this widget is what makes "every screen handles loading, empty, and error"
/// a structural guarantee rather than a review checklist: [loading] and
/// [error] have sensible defaults, and for collections [AsyncCollectionView]
/// makes the empty builder a *required* parameter, so it cannot be forgotten.
///
/// While refreshing, previously-loaded data stays on screen rather than
/// collapsing back to a spinner — a dispatcher mid-scan shouldn't lose their
/// place because a realtime patch arrived.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
    this.onRetry,
    this.compact = false,
    this.showStaleWhileRefreshing = true,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Defaults to a skeleton-free spinner. Lists should pass their own
  /// content-shaped skeleton.
  final Widget Function()? loading;

  /// Defaults to [ErrorState] with a retry.
  final Widget Function(AppException error, VoidCallback? retry)? error;

  final VoidCallback? onRetry;
  final bool compact;

  /// When false, a refresh drops back to the loading state. Only right for
  /// views where stale data would actively mislead.
  final bool showStaleWhileRefreshing;

  @override
  Widget build(BuildContext context) {
    final current = value;

    // Keep showing data during a refresh.
    if (showStaleWhileRefreshing &&
        current.isLoading &&
        current.hasValue &&
        !current.hasError) {
      return data(current.requireValue);
    }

    return current.when(
      skipLoadingOnRefresh: showStaleWhileRefreshing,
      skipLoadingOnReload: showStaleWhileRefreshing,
      data: data,
      loading: () => loading?.call() ?? LoadingView(compact: compact),
      error: (err, stack) {
        final mapped = ErrorMapper.map(err, stack);
        return error?.call(mapped, onRetry) ??
            ErrorState(error: mapped, onRetry: onRetry, compact: compact);
      },
    );
  }
}

/// [AsyncValueView] for collections, where "loaded but empty" is a real state
/// that needs its own treatment.
///
/// [empty] is required on purpose. A list that renders zero items with no
/// empty state is the single most common way this app could ship looking
/// unfinished, so the type system asks for it.
class AsyncCollectionView<T> extends StatelessWidget {
  const AsyncCollectionView({
    super.key,
    required this.value,
    required this.data,
    required this.empty,
    this.loading,
    this.error,
    this.onRetry,
    this.compact = false,
    this.isEmpty,
    this.showStaleWhileRefreshing = true,
  });

  final AsyncValue<List<T>> value;
  final Widget Function(List<T> items) data;

  /// Shown when the load succeeded and returned nothing.
  final Widget Function() empty;

  final Widget Function()? loading;
  final Widget Function(AppException error, VoidCallback? retry)? error;
  final VoidCallback? onRetry;
  final bool compact;

  /// Override for cases where emptiness isn't just `items.isEmpty` — e.g. a
  /// calendar week whose buckets are all present but each unpopulated.
  final bool Function(List<T> items)? isEmpty;

  final bool showStaleWhileRefreshing;

  @override
  Widget build(BuildContext context) {
    return AsyncValueView<List<T>>(
      value: value,
      loading: loading,
      error: error,
      onRetry: onRetry,
      compact: compact,
      showStaleWhileRefreshing: showStaleWhileRefreshing,
      data: (items) {
        final blank = isEmpty?.call(items) ?? items.isEmpty;
        return blank ? empty() : data(items);
      },
    );
  }
}

/// Wraps a section of a page so its failure is contained.
///
/// The admin dashboard composes several independent queries; one failing
/// should degrade that panel, never blank the whole page. This is what makes
/// "sections fail independently" true in practice.
class AsyncSection extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.child,
    this.minHeight = 120,
  });

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: child,
    );
  }
}
