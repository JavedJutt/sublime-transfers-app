/// The app's failure taxonomy.
///
/// Every error that reaches the UI is one of these. Raw [Exception] strings,
/// PostgREST codes, and platform exceptions are mapped at the repository
/// boundary by `ErrorMapper` — no screen ever renders a driver-hostile string
/// like `PostgrestException(code: 42501)`.
sealed class AppException implements Exception {
  const AppException({required this.message, this.cause, this.stackTrace});

  /// A short, plain-language description safe to show a user.
  final String message;

  /// The underlying error, kept for logging only. Never rendered.
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message';
}

/// No route to the server: offline, DNS failure, timeout.
class NetworkFailure extends AppException {
  const NetworkFailure({
    super.message = 'Can\'t reach the server. Check your connection.',
    super.cause,
    super.stackTrace,
    this.isOffline = false,
  });

  /// True when the device itself reports no connectivity, which the UI treats
  /// as an offline state rather than an error.
  final bool isOffline;
}

/// Sign-in rejected, session expired, token refresh failed.
class AuthFailure extends AppException {
  const AuthFailure({
    required super.message,
    super.cause,
    super.stackTrace,
    this.isSessionExpired = false,
  });

  final bool isSessionExpired;
}

/// The caller is authenticated but not allowed. Typically an RLS denial, which
/// in production means a bug rather than a user mistake — logged loudly.
class PermissionFailure extends AppException {
  const PermissionFailure({
    super.message = 'You don\'t have access to this.',
    super.cause,
    super.stackTrace,
  });
}

/// OS-level permission refused (location, notifications).
class DevicePermissionFailure extends AppException {
  const DevicePermissionFailure({
    required super.message,
    required this.permanentlyDenied,
    super.cause,
    super.stackTrace,
  });

  /// True when the user must go to system settings — the UI shows a settings
  /// deep link instead of re-prompting.
  final bool permanentlyDenied;
}

/// The record changed underneath us: a concurrent edit, or a broadcast ride
/// claimed by another driver.
class ConflictFailure extends AppException {
  const ConflictFailure({
    required super.message,
    super.cause,
    super.stackTrace,
    this.kind = ConflictKind.staleWrite,
  });

  final ConflictKind kind;
}

enum ConflictKind {
  /// Another admin edited the ride while this form was open.
  staleWrite,

  /// Another driver claimed the broadcast first. Informational, not an error.
  rideAlreadyClaimed,

  /// The ride is no longer in a state that permits this transition.
  invalidTransition,
}

/// Server-side validation rejected the payload, with optional field mapping so
/// forms can attach the message to the right input.
class ValidationFailure extends AppException {
  const ValidationFailure({
    required super.message,
    this.fieldErrors = const {},
    super.cause,
    super.stackTrace,
  });

  final Map<String, String> fieldErrors;
}

/// The requested record does not exist (or is invisible under RLS, which is
/// indistinguishable from the client and correct to present the same way).
class NotFoundFailure extends AppException {
  const NotFoundFailure({
    super.message = 'This no longer exists.',
    super.cause,
    super.stackTrace,
  });
}

/// An email could not be parsed into a booking. Routes to the review queue
/// rather than failing.
class ParseFailure extends AppException {
  const ParseFailure({
    required super.message,
    this.reason,
    super.cause,
    super.stackTrace,
  });

  final String? reason;
}

/// Configuration is missing or wrong — a Maps key, a Supabase URL. Distinct
/// from a network failure because retrying will not help.
class ConfigurationFailure extends AppException {
  const ConfigurationFailure({
    required super.message,
    super.cause,
    super.stackTrace,
  });
}

/// Anything unmapped. Its presence in logs is a signal that `ErrorMapper`
/// needs another case.
class UnknownFailure extends AppException {
  const UnknownFailure({
    super.message = 'Something went wrong. Please try again.',
    super.cause,
    super.stackTrace,
  });
}
