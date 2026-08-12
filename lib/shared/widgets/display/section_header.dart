import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';

/// Eyebrow + headline + optional muted support line, with a trailing action.
///
/// This is where the "bold headline over muted supporting text" pattern from
/// the visual direction is codified once. Screens compose this rather than
/// hand-rolling a Row of Texts, which is how the hierarchy stays identical
/// across sixteen admin screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.lg),
    this.dense = false,
  });

  final String title;

  /// Small ALL-CAPS label above the title.
  final String? eyebrow;

  /// Muted supporting line below the title.
  final String? subtitle;

  /// Trailing control — a button, a filter, a "View all" link.
  final Widget? action;

  final EdgeInsetsGeometry padding;

  /// Uses the card-title size rather than the section size.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final titleStyle = dense ? AppTypography.h3 : AppTypography.h2;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(), style: AppTypography.eyebrow),
                  const SizedBox(height: AppSpacing.xs + 2),
                ],
                Semantics(header: true, child: Text(title, style: titleStyle)),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style:
                        AppTypography.bodySm.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.lg),
            Padding(
              padding: EdgeInsets.only(top: eyebrow != null ? AppSpacing.md : 0),
              child: action,
            ),
          ],
        ],
      ),
    );
  }
}
