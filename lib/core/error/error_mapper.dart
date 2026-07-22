import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_exception.dart';

/// Translates every error the data layer can throw into an [AppException].
///
/// This is the only place that knows about PostgREST codes and platform
/// exceptions. Repositories wrap their calls in [guard] so nothing raw
/// escapes to a provider or a widget.
abstract final class ErrorMapper {
  /// Runs [action], mapping any thrown error to an [AppException].
  static Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException {
      rethrow;
    } catch (error, stackTrace) {
      throw map(error, stackTrace);
    }
  }

  static AppException map(Object error, [StackTrace? stackTrace]) {
    if (error is AppException) return error;

    if (error is PostgrestException) {
      return _fromPostgrest(error, stackTrace);
    }
    if (error is AuthException) {
      return _fromAuth(error, stackTrace);
    }
    if (error is StorageException) {
      return UnknownFailure(
        message: 'Upload failed. Please try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is SocketException || error is HttpException) {
      return NetworkFailure(cause: error, stackTrace: stackTrace);
    }
    if (error is TimeoutException) {
      return NetworkFailure(
        message: 'That took too long. Please try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is FormatException) {
      return ParseFailure(
        message: 'Received data we couldn\'t read.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return UnknownFailure(cause: error, stackTrace: stackTrace);
  }

  static AppException _fromPostgrest(
    PostgrestException error,
    StackTrace? stackTrace,
  ) {
    // PostgREST surfaces the Postgres SQLSTATE in `code` for database errors
    // and an HTTP-ish string for its own errors.
    switch (error.code) {
      // insufficient_privilege — an RLS policy denied the row. From the
      // client this is indistinguishable from "doesn't exist", and presenting
      // it as a permission error leaks the row's existence.
      case '42501':
      case 'PGRST301':
        return PermissionFailure(cause: error, stackTrace: stackTrace);

      // unique_violation
      case '23505':
        return ConflictFailure(
          message: 'That already exists.',
          cause: error,
          stackTrace: stackTrace,
        );

      // foreign_key_violation
      case '23503':
        return ValidationFailure(
          message: 'A linked record is missing or was removed.',
          cause: error,
          stackTrace: stackTrace,
        );

      // check_violation / not_null_violation
      case '23514':
      case '23502':
        return ValidationFailure(
          message: 'Some details are missing or out of range.',
          cause: error,
          stackTrace: stackTrace,
        );

      // raise_exception — our RPCs signal business-rule failures this way, and
      // their messages are written to be user-facing.
      case 'P0001':
        return _fromRaisedMessage(error, stackTrace);

      // No rows returned by .single()
      case 'PGRST116':
        return NotFoundFailure(cause: error, stackTrace: stackTrace);

      default:
        return UnknownFailure(cause: error, stackTrace: stackTrace);
    }
  }

  /// Our RPCs `raise exception` with a machine-readable prefix so the client
  /// can distinguish a lost broadcast race (informational) from a genuine
  /// error, without string-matching prose.
  static AppException _fromRaisedMessage(
    PostgrestException error,
    StackTrace? stackTrace,
  ) {
    final message = error.message;
    if (message.startsWith('already_claimed')) {
      return ConflictFailure(
        message: 'That ride was taken by another driver.',
        kind: ConflictKind.rideAlreadyClaimed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (message.startsWith('invalid_transition')) {
      return ConflictFailure(
        message: 'This ride has moved on since you last saw it.',
        kind: ConflictKind.invalidTransition,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (message.startsWith('not_approved')) {
      return PermissionFailure(
        message: 'Your account is still awaiting approval.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (message.startsWith('not_found')) {
      return NotFoundFailure(cause: error, stackTrace: stackTrace);
    }
    if (message.startsWith('forbidden')) {
      return PermissionFailure(cause: error, stackTrace: stackTrace);
    }
    return UnknownFailure(cause: error, stackTrace: stackTrace);
  }

  static AppException _fromAuth(AuthException error, StackTrace? stackTrace) {
    final code = error.code ?? '';
    final message = error.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      return AuthFailure(
        message: 'That email and password don\'t match.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (code == 'email_not_confirmed' || message.contains('not confirmed')) {
      return AuthFailure(
        message: 'Confirm your email address before signing in.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (code == 'user_already_exists' || message.contains('already registered')) {
      return ValidationFailure(
        message: 'An account with this email already exists.',
        fieldErrors: const {'email': 'Already registered'},
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (code == 'weak_password') {
      return ValidationFailure(
        message: 'Choose a stronger password.',
        fieldErrors: const {
          'password': 'Use at least 8 characters, mixing letters and numbers',
        },
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (code == 'over_request_rate_limit' || error.statusCode == '429') {
      return AuthFailure(
        message: 'Too many attempts. Wait a moment and try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (code == 'session_expired' || code == 'refresh_token_not_found') {
      return AuthFailure(
        message: 'Your session expired. Please sign in again.',
        isSessionExpired: true,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return AuthFailure(
      message: 'Sign-in failed. Please try again.',
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
