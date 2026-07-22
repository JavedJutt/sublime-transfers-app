import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import 'app_card.dart';
import 'status_chip.dart';

/// Icon + big figure + short copy.
///
/// This is the app's take on the reference site's "Professional drivers /
/// Fixed prices / Free waiting time" feature row, repurposed for the numbers a
/// dispatcher checks first: today's rides, unassigned count, drivers on duty.
///
/// The figure uses the serif [AppTypography.numeric], which is what makes a
/// stat row read editorial rather than like an analytics widget.
class StatCallout extends StatelessWidget {
  const StatCallout({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.caption,
    this.tone,
    this.onTap,
    this.isLoading = false,
  });

  final IconData icon;

  /// The figure. Pre-formatted — this widget does not know about locales.
  final String value;

  /// Short copy under the figure.
  final String label;

  /// Optional second line: "3 in the next hour".
  final String? caption;

  /// Tints the icon backdrop. Null uses the brass accent. Reserve [StatusTone]
  /// here for genuinely actionable counts — an unassigned-rides tile earns
  /// urgent, a completed-today tile does not.
  final StatusTone? tone;

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final iconColor = tone?.foreground ?? AppColors.brass;
    final backdrop = tone?.background ?? AppColors.brassTint;

    return AppCard(
      onTap: onTap,
      semanticLabel: '$value $label${caption == null ? '' : '. $caption'}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: backdrop, shape: BoxShape.circle),
            child: Icon(icon, size: 21, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  Container(
                    width: 56,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceSunk,
                      borderRadius: AppRadius.brSm,
                    ),
                  )
                else
                  Text(
                    value,
                    style: AppTypography.numeric,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.inkBody,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    caption!,
                    style: AppTypography.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
