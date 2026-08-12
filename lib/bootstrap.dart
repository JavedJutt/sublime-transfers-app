import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/design/app_theme.dart';
import 'core/env/app_env.dart';
import 'core/error/app_exception.dart';
import 'shared/widgets/feedback/error_state.dart';

/// Starts the app.
///
/// Configuration problems surface as a real, readable screen rather than a
/// crash or a blank window — a missing `--dart-define` is the most likely
/// first-run failure and it should say so.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final missing = AppEnv.missingConfigDescription;
  if (missing != null) {
    runApp(_ConfigErrorApp(missing: missing));
    return;
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) return;
    // Production crash reporting hooks in here.
  };

  try {
    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      publishableKey: AppEnv.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: kDebugMode ? RealtimeLogLevel.info : RealtimeLogLevel.error,
      ),
    );
  } catch (error, stack) {
    debugPrintStack(label: 'Supabase init failed', stackTrace: stack);
    runApp(
      const _ConfigErrorApp(
        missing: 'Could not reach the Sublime Transfers server.',
        isConnectivity: true,
      ),
    );
    return;
  }

  runApp(const ProviderScope(child: SublimeTransfersApp()));
}

/// Shown when the app cannot start at all. Deliberately styled — even the
/// failure path uses the design system.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({required this.missing, this.isConnectivity = false});

  final String missing;
  final bool isConnectivity;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sublime Transfers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: ErrorState(
            error: isConnectivity
                ? NetworkFailure(message: missing)
                : ConfigurationFailure(
                    message: 'Missing configuration: $missing.\n\n'
                        'Run with --dart-define-from-file=dart_define.json '
                        '(copy dart_define.example.json to start).',
                  ),
          ),
        ),
      ),
    );
  }
}
