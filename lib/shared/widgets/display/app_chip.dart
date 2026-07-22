import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_durations.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';

/// A selectable filter chip.
///
/// Distinct from `StatusChip`, which is read-only and carries semantic colour.
/// This one is interactive and only ever brass-or-neutral, so a row of filters
/// never competes with the status colours in the list below it.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemove,
    this.icon,
    this.count,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// Renders an × affordance. For chips representing an applied filter.
  final VoidCallback? onRemove;

  final IconData? icon;

  /// Trailing count badge — "Unassigned 4".
  final int? count;

  /// Arbitrary leading widget, e.g. a driver avatar in a driver filter.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.brassPress : AppColors.inkBody;

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: count == null ? label : '$label, $count',
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.brPill,
            child: AnimatedContainer(
              duration: AppDurations.quick,
              curve: AppDurations.standard,
              constraints: const BoxConstraints(minHeight: 34),
              padding: EdgeInsets.only(
                left: leading != null ? AppSpacing.xs : AppSpacing.md,
                right: onRemove != null ? AppSpacing.xs : AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.brassTint : AppColors.surface,
                borderRadius: AppRadius.brPill,
                border: Border.all(
                  color: selected ? AppColors.brassLine : AppColors.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.sm),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 15, color: foreground),
                    const SizedBox(width: AppSpacing.xs + 2),
                  ],
                  Text(
                    label,
                    style: AppTypography.label.copyWith(color: foreground),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: AppSpacing.xs + 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.brassLine
                            : AppColors.surfaceSunk,
                        borderRadius: AppRadius.brPill,
                      ),
                      child: Text(
                        '$count',
                        style: AppTypography.caption.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (onRemove != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    InkWell(
                      onTap: onRemove,
                      borderRadius: AppRadius.brPill,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Icon(
                          AppIcons.close,
                          size: 14,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
