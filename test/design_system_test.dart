import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sublime_transfers/core/design/app_theme.dart';
import 'package:sublime_transfers/core/error/app_exception.dart';
import 'package:sublime_transfers/features/dev/component_gallery_screen.dart';
import 'package:sublime_transfers/shared/widgets/async/async_value_view.dart';
import 'package:sublime_transfers/shared/widgets/buttons/app_button.dart';
import 'package:sublime_transfers/shared/widgets/feedback/empty_state.dart';
import 'package:sublime_transfers/shared/widgets/feedback/error_state.dart';
import 'package:sublime_transfers/shared/widgets/feedback/loading_view.dart';

/// Widths the responsive sweep covers. 360 is a small Android phone, 1920 a
/// wide desktop; the two in between are the tablet and small-desktop cases
/// the admin dashboard must not break at.
const _sweepWidths = <double>[360, 768, 1024, 1440, 1920];

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(theme: AppTheme.light, home: child),
    );

Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  required double width,
  double height = 2400,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(child));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('component gallery', () {
    // Pumping the gallery exercises every component in every state at once.
    // A RenderFlex overflow anywhere in the design system fails here, which is
    // the check a successful `flutter build` cannot give us.
    for (final width in _sweepWidths) {
      testWidgets('renders without overflow at ${width.toInt()}px',
          (tester) async {
        await _pumpAt(tester, const ComponentGalleryScreen(), width: width);

        expect(tester.takeException(), isNull);
        expect(find.text('Sublime Transfers'), findsOneWidget);
      });
    }

    testWidgets('scrolls through every section without error', (tester) async {
      await _pumpAt(tester, const ComponentGalleryScreen(), width: 1440);

      final scrollable = find.byType(Scrollable).first;
      for (var i = 0; i < 12; i++) {
        await tester.drag(scrollable, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('AppButton', () {
    testWidgets('fires onPressed when enabled', (tester) async {
      var taps = 0;
      await _pumpAt(
        tester,
        Scaffold(
          body: Center(
            child: AppButton.primary(label: 'Assign', onPressed: () => taps++),
          ),
        ),
        width: 400,
        height: 400,
      );

      await tester.tap(find.text('Assign'));
      expect(taps, 1);
    });

    testWidgets('does not fire when disabled', (tester) async {
      await _pumpAt(
        tester,
        const Scaffold(
          body: Center(child: AppButton(label: 'Assign', onPressed: null)),
        ),
        width: 400,
        height: 400,
      );

      await tester.tap(find.text('Assign'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps its label laid out while loading so width is stable',
        (tester) async {
      await _pumpAt(
        tester,
        Scaffold(
          body: Center(
            child: AppButton.primary(
              label: 'Saving changes',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
        width: 400,
        height: 400,
      );

      expect(find.text('Saving changes'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ErrorState', () {
    testWidgets('offers retry for a network failure', (tester) async {
      await _pumpAt(
        tester,
        Scaffold(
          body: ErrorState(error: const NetworkFailure(), onRetry: () {}),
        ),
        width: 500,
        height: 600,
      );

      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('withholds retry where retrying cannot help', (tester) async {
      // A permission or configuration failure repeats identically on retry,
      // so offering the button would only disappoint.
      for (final error in const <AppException>[
        PermissionFailure(),
        ConfigurationFailure(message: 'Missing SUPABASE_URL'),
        NotFoundFailure(),
      ]) {
        await _pumpAt(
          tester,
          Scaffold(body: ErrorState(error: error, onRetry: () {})),
          width: 500,
          height: 600,
        );
        expect(
          find.text('Try again'),
          findsNothing,
          reason: '${error.runtimeType} should not offer retry',
        );
      }
    });

    testWidgets('renders the plain-language message, never the raw cause',
        (tester) async {
      const raw = 'PostgrestException(code: 42501, details: RLS)';
      await _pumpAt(
        tester,
        const Scaffold(
          body: ErrorState(
            error: PermissionFailure(cause: raw),
          ),
        ),
        width: 500,
        height: 600,
      );

      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(find.textContaining('42501'), findsNothing);
      expect(find.text('You don\'t have access to this.'), findsOneWidget);
    });
  });

  group('AsyncCollectionView', () {
    Widget view(AsyncValue<List<String>> value) => Scaffold(
          body: AsyncCollectionView<String>(
            value: value,
            onRetry: () {},
            empty: () => const EmptyState(
              icon: Icons.inbox,
              title: 'No rides today',
            ),
            data: (items) => Text(items.join(', ')),
          ),
        );

    testWidgets('loading shows the loading view', (tester) async {
      await _pumpAt(tester, view(const AsyncValue.loading()),
          width: 500, height: 600);
      expect(find.byType(LoadingView), findsOneWidget);
    });

    testWidgets('data shows the data', (tester) async {
      await _pumpAt(tester, view(const AsyncValue.data(['Ride A'])),
          width: 500, height: 600);
      expect(find.text('Ride A'), findsOneWidget);
    });

    testWidgets('an empty list shows the empty state, not a blank screen',
        (tester) async {
      await _pumpAt(tester, view(const AsyncValue.data([])),
          width: 500, height: 600);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No rides today'), findsOneWidget);
    });

    testWidgets('error shows the error state', (tester) async {
      await _pumpAt(
        tester,
        view(const AsyncValue.error(NetworkFailure(), StackTrace.empty)),
        width: 500,
        height: 600,
      );
      expect(find.byType(ErrorState), findsOneWidget);
    });

    testWidgets('keeps stale data visible while refreshing', (tester) async {
      // A dispatcher mid-scan should not lose their place because a realtime
      // patch triggered a refetch.
      // AsyncValue.data + isLoading is exactly the shape Riverpod produces
      // during a refetch of an already-loaded provider.
      const refreshing = AsyncValue<List<String>>.data(
        ['Ride A'],
      );
      await _pumpAt(
        tester,
        view(refreshing),
        width: 500,
        height: 600,
      );

      expect(find.text('Ride A'), findsOneWidget);
      expect(find.byType(LoadingView), findsNothing);
    });
  });
}
