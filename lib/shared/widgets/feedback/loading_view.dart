import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';

/// A centred spinner with optional label.
///
/// Used only where a skeleton isn't possible — a full-page route resolve, or a
/// blocking action. Lists and cards get skeletons instead, because a spinner
/// tells the user nothing about what is coming.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label, this.compact = false});

  final String? label;

  /// Sits inline in a card or sheet rather than filling the page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: compact ? 20 : 28,
          height: compact ? 20 : 28,
          child: const CircularProgressIndicator(strokeWidth: 2.5),
        ),
        if (label != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            label!,
            style: AppTypography.bodySm,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: content),
      );
    }

    return Semantics(
      label: label ?? 'Loading',
      liveRegion: true,
      child: ColoredBox(
        color: AppColors.canvas,
        child: Center(child: content),
      ),
    );
  }
}
