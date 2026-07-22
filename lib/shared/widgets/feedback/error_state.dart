import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/error/app_exception.dart';
import '../buttons/app_button.dart';

/// The error state.
///
/// Renders the plain-language [AppException.message] and never the underlying
/// exception — a dispatcher seeing `PostgrestException(42501)` learns nothing
/// and trusts the app less. Retry is offered only where retrying can actually
/// help; a [ConfigurationFailure] or [PermissionFailure] shows no retry, since
/// pressing it would just fail again.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
    this.action,
  });

  /// Convenience for a plain message with no exception in hand.
  ErrorState.message(
    String message, {
    super.key,
    this.onRetry,
    this.compact = false,
    this.action,
  }) : error = UnknownFailure(message: message);

  final AppException error;
  final VoidCallback? onRetry;
  final bool compact;

  /// An alternative to Retry — "Open settings", "Back to calendar".
  final Widget? action;

  /// Retrying a permission or configuration failure repeats the same failure,
  /// so the button is withheld rather than offered and disappointing.
  bool get _retryable => switch (error) {
        PermissionFailure() => false,
        ConfigurationFailure() => false,
        NotFoundFailure() => false,
        ValidationFailure() => false,
        _ => true,
      };

  (IconData, Color, Color) get _visual => switch (error) {
        NetworkFailure(isOffline: true) => (
            AppIcons.offline,
            AppColors.inkMuted,
            AppColors.surfaceSunk,
          ),
        NetworkFailure() => (
            AppIcons.offline,
            AppColors.warning,
            AppColors.warningTint,
          ),
        PermissionFailure() ||
        DevicePermissionFailure() =>
          (AppIcons.warning, AppColors.warning, AppColors.warningTint),
        NotFoundFailure() => (
            AppIcons.empty,
            AppColors.inkMuted,
            AppColors.surfaceSunk,
          ),
        ConflictFailure() => (
            AppIcons.info,
            AppColors.info,
            AppColors.infoTint,
          ),
        _ => (AppIcons.error, AppColors.danger, AppColors.dangerTint),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, backdrop) = _visual;
    final showRetry = onRetry != null && _retryable;

    final iconSize = compact ? 20.0 : 28.0;
    final backdropSize = compact ? 44.0 : 64.0;

    return Semantics(
      container: true,
      liveRegion: true,
      label: error.message,
      // Scrollable so a long message in a height-constrained panel (a
      // dashboard section, a calendar cell, a sheet) scrolls rather than
      // overflowing. In an unbounded parent this lays out as a plain column.
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: compact ? AppSpacing.xl : AppSpacing.x5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: backdropSize,
              height: backdropSize,
              decoration: BoxDecoration(color: backdrop, shape: BoxShape.circle),
              child: Icon(icon, size: iconSize, color: iconColor),
            ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
            Text(
              _headline,
              style: compact ? AppTypography.h3 : AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                error.message,
                style: AppTypography.body.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
            ),
            if (showRetry || action != null) ...[
              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xxl),
              Wrap(
                spacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  if (showRetry)
                    AppButton(
                      label: 'Try again',
                      icon: AppIcons.refresh,
                      size: compact ? AppButtonSize.sm : AppButtonSize.md,
                      onPressed: onRetry,
                    ),
                  ?action,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _headline => switch (error) {
        NetworkFailure(isOffline: true) => 'You\'re offline',
        NetworkFailure() => 'Connection problem',
        AuthFailure() => 'Sign-in problem',
        PermissionFailure() => 'No access',
        DevicePermissionFailure() => 'Permission needed',
        NotFoundFailure() => 'Not found',
        ConflictFailure() => 'This changed',
        ValidationFailure() => 'Check these details',
        ParseFailure() => 'Couldn\'t read that',
        ConfigurationFailure() => 'Not configured',
        UnknownFailure() => 'Something went wrong',
      };
}
