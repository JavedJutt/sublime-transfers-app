import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_durations.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/error/app_exception.dart';

enum SnackTone { info, success, warning, error }

/// Transient feedback.
///
/// [showFailure] is the entry point for anything that threw: it picks the tone
/// from the failure type, so a lost broadcast race reads as neutral
/// information rather than a red error — losing a race is normal, and
/// alarming the driver about it would be wrong.
abstract final class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    SnackTone tone = SnackTone.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final (icon, accent) = switch (tone) {
      SnackTone.info => (AppIcons.info, AppColors.infoTint),
      SnackTone.success => (AppIcons.success, AppColors.successTint),
      SnackTone.warning => (AppIcons.warning, AppColors.warningTint),
      SnackTone.error => (AppIcons.error, AppColors.dangerTint),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration ??
              (tone == SnackTone.error
                  ? AppDurations.snackError
                  : AppDurations.snackInfo),
          content: Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.body
                      .copyWith(color: AppColors.inkInverse),
                ),
              ),
            ],
          ),
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  textColor: AppColors.brassTint,
                  onPressed: onAction ?? () {},
                ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, tone: SnackTone.success);

  /// Presents a caught failure with the right weight.
  static void showFailure(
    BuildContext context,
    AppException error, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final tone = switch (error) {
      // Another driver got there first. Expected, not a failure.
      ConflictFailure(kind: ConflictKind.rideAlreadyClaimed) => SnackTone.info,
      NetworkFailure(isOffline: true) => SnackTone.warning,
      NetworkFailure() => SnackTone.warning,
      ConflictFailure() => SnackTone.warning,
      ValidationFailure() => SnackTone.warning,
      _ => SnackTone.error,
    };

    show(
      context,
      message: error.message,
      tone: tone,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
