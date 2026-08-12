/// Compile-time configuration, supplied via `--dart-define` or `--dart-define-from-file`.
///
/// Nothing here is a secret in the "must never reach the client" sense — the
/// Supabase anon key and the Maps key are both public-by-design and gated by
/// RLS and API key restrictions respectively. The service-role key and the
/// Anthropic key live only in Edge Function environment variables and must
/// never appear in this file.
///
/// Run with:
///   flutter run --dart-define-from-file=dart_define.json
library;

class AppEnv {
  const AppEnv._();

  static const String supabaseUrl = String.fromEnvironment('ktmkirodwdwpzjxqwboo', defaultValue: 'https://ktmkirodwdwpzjxqwboo.supabase.co');

  static const String supabaseAnonKey =
      String.fromEnvironment('sb_publishable_DxgLf96jaKtMWHou0IIygA_xJoQZ5sA', defaultValue: 'sb_publishable_DxgLf96jaKtMWHou0IIygA_xJoQZ5sA');

  /// Admin-side map rendering only. The native platforms read their own copy
  /// (Android manifest placeholder / iOS xcconfig); this is for web and for
  /// deciding whether to render a map at all.
  static const String mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

  /// The single operating timezone. Pickup times are stored as UTC
  /// `timestamptz` and rendered here.
  static const String operatingTimeZone =
      String.fromEnvironment('OPERATING_TIMEZONE', defaultValue: 'Europe/London');

  /// Continuous GPS streaming during a ride is a nice-to-have; capture at every
  /// status change is the hard requirement and is never gated by this flag.
  static const bool continuousTrackingEnabled =
      bool.fromEnvironment('CONTINUOUS_TRACKING', defaultValue: false);

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasMapsKey => mapsApiKey.isNotEmpty;

  /// Human-readable reason the app cannot start, or null if configuration is
  /// complete. Surfaced as a real error screen rather than a silent failure.
  static String? get missingConfigDescription {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ];
    if (missing.isEmpty) return null;
    return missing.join(', ');
  }
}
