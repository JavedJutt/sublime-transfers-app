import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';

/// The "nothing here" state.
///
/// Deliberately warm rather than apologetic — an empty calendar on a quiet
/// Tuesday is not a problem, and styling it like one makes the app feel
/// broken. Distinct from the *filtered*-empty case, which every list handles
/// separately with a "Clear filters" action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.secondaryAction,
    this.compact = false,
    this.tone = EmptyStateTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Primary call to action, e.g. "Create ride".
  final Widget? action;
  final Widget? secondaryAction;

  /// Sits inside a card or a calendar cell rather than filling the page.
  final bool compact;

  final EmptyStateTone tone;

  @override
  Widget build(BuildContext context) {
    final (iconColor, backdrop) = switch (tone) {
      EmptyStateTone.neutral => (AppColors.inkMuted, AppColors.surfaceSunk),
      EmptyStateTone.positive => (AppColors.success, AppColors.successTint),
      EmptyStateTone.accent => (AppColors.brass, AppColors.brassTint),
    };

    final iconSize = compact ? 22.0 : 30.0;
    final backdropSize = compact ? 48.0 : 68.0;

    return Semantics(
      container: true,
      label: message == null ? title : '$title. $message',
      // Scrollable for the same reason as ErrorState: empty states appear
      // inside height-constrained panels and must never overflow.
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: compact ? AppSpacing.xxl : AppSpacing.x5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: backdropSize,
              height: backdropSize,
              decoration: BoxDecoration(
                color: backdrop,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: iconColor),
            ),
            SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xxl),
            Text(
              title,
              style: compact ? AppTypography.h3 : AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  message!,
                  style: AppTypography.body.copyWith(color: AppColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xxl),
              action!,
            ],
            if (secondaryAction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              secondaryAction!,
            ],
          ],
        ),
      ),
    );
  }
}

enum EmptyStateTone {
  /// Ordinary absence — no rides today.
  neutral,

  /// Absence that is good news — no pending approvals, nothing to review.
  positive,

  /// Absence that invites an action — no mailbox connected yet.
  accent,
}
