import 'package:flutter/material.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../buttons/app_button.dart';

/// Adaptive confirmation: a dialog on wide screens, a bottom sheet on phones.
///
/// A sheet on mobile puts the buttons within thumb reach; a centred dialog on
/// a phone puts them mid-screen, which is the wrong place for a driver
/// confirming a status change one-handed.
abstract final class ConfirmDialog {
  /// Returns true if confirmed, false or null otherwise.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    IconData? icon,
  }) {
    final isNarrow = AppBreakpoints.of(context).isNarrow;

    final body = _ConfirmBody(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
      stackButtons: isNarrow,
    );

    if (isNarrow) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.sm,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: body,
          ),
        ),
      );
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.stackButtons,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final bool stackButtons;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final confirmButton = destructive
        ? AppButton.destructive(
            label: confirmLabel,
            size: stackButtons ? AppButtonSize.lg : AppButtonSize.md,
            fullWidth: stackButtons,
            onPressed: () => Navigator.of(context).pop(true),
          )
        : AppButton.primary(
            label: confirmLabel,
            size: stackButtons ? AppButtonSize.lg : AppButtonSize.md,
            fullWidth: stackButtons,
            onPressed: () => Navigator.of(context).pop(true),
          );

    final cancelButton = AppButton(
      label: cancelLabel,
      size: stackButtons ? AppButtonSize.lg : AppButtonSize.md,
      fullWidth: stackButtons,
      onPressed: () => Navigator.of(context).pop(false),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: destructive ? AppColors.dangerTint : AppColors.brassTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 21,
              color: destructive ? AppColors.danger : AppColors.brass,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(title, style: AppTypography.h2),
        const SizedBox(height: AppSpacing.sm),
        Text(
          message,
          style: AppTypography.body.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (stackButtons) ...[
          // Confirm on top, within thumb reach.
          confirmButton,
          const SizedBox(height: AppSpacing.sm),
          cancelButton,
        ] else
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              cancelButton,
              const SizedBox(width: AppSpacing.sm),
              confirmButton,
            ],
          ),
      ],
    );
  }
}
