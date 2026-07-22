import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';

/// A ±stepper for small integers.
///
/// Passengers and luggage are almost always single digits, and asking a
/// dispatcher to raise a keyboard for "3" is a worse interaction than two taps
/// — especially on tablet. The steppers are 48dp targets in their own right.
class AppCounterField extends StatelessWidget {
  const AppCounterField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.icon,
    this.helper,
    this.enabled = true,
  });

  final String label;
  final int value;
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;
  final IconData? icon;
  final String? helper;
  final bool enabled;

  bool get _canDecrement => enabled && onChanged != null && value > min;
  bool get _canIncrement => enabled && onChanged != null && value < max;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: AppColors.inkMuted),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: enabled ? AppColors.inkBody : AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          label: label,
          value: '$value',
          slider: true,
          child: ExcludeSemantics(
            child: Container(
              height: AppSpacing.minTapTarget,
              decoration: BoxDecoration(
                color: enabled ? AppColors.surface : AppColors.surfaceSunk,
                borderRadius: AppRadius.brMd,
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  _StepButton(
                    icon: Icons.remove,
                    enabled: _canDecrement,
                    onTap: () => onChanged!(value - 1),
                    tooltip: 'Decrease $label',
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$value',
                        style: AppTypography.bodyStrong.copyWith(
                          fontSize: 16,
                          color: enabled ? AppColors.ink : AppColors.inkFaint,
                        ),
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: AppIcons.add,
                    enabled: _canIncrement,
                    onTap: () => onChanged!(value + 1),
                    tooltip: 'Increase $label',
                  ),
                ],
              ),
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(helper!, style: AppTypography.caption),
          ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.brMd,
          child: SizedBox(
            width: AppSpacing.minTapTarget,
            height: AppSpacing.minTapTarget,
            child: Icon(
              icon,
              size: 18,
              color: enabled ? AppColors.inkBody : AppColors.inkFaint,
            ),
          ),
        ),
      ),
    );
  }
}
