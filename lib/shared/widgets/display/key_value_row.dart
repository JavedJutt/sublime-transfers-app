import 'package:flutter/material.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';

/// A labelled field value.
///
/// Stacks on narrow screens and sits inline on wide ones — ride detail is the
/// densest screen in the app and a fixed two-column layout breaks badly on a
/// phone.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueStyle,
    this.emphasise = false,
    this.monospace = false,
    this.placeholder = 'Not provided',
    this.trailing,
    this.onTap,
  });

  final String label;

  /// Null renders [placeholder] in faint text rather than collapsing the row —
  /// a missing phone number is information a dispatcher needs to see.
  final String? value;

  final IconData? icon;
  final TextStyle? valueStyle;
  final bool emphasise;

  /// For references, flight numbers, coordinates.
  final bool monospace;

  final String placeholder;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isNarrow = AppBreakpoints.of(context).isNarrow;
    final hasValue = value != null && value!.trim().isNotEmpty;

    final resolvedStyle = valueStyle ??
        (monospace
            ? AppTypography.mono
            : emphasise
                ? AppTypography.bodyStrong
                : AppTypography.body);

    final valueWidget = Text(
      hasValue ? value! : placeholder,
      style: hasValue
          ? resolvedStyle
          : AppTypography.body.copyWith(
              color: AppColors.inkFaint,
              fontStyle: FontStyle.italic,
            ),
    );

    // The label is Flexible, not fixed: on the wide layout it lives in a 160px
    // column, and a long label ("Assignment method", "Number of passengers")
    // otherwise overflows it.
    final labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            style: AppTypography.bodySm,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    Widget row;
    if (isNarrow) {
      row = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelWidget,
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(child: valueWidget),
              ?trailing,
            ],
          ),
        ],
      );
    } else {
      row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 160, child: labelWidget),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: valueWidget),
          ?trailing,
        ],
      );
    }

    row = Semantics(
      label: '$label: ${hasValue ? value! : placeholder}',
      child: ExcludeSemantics(child: row),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: row,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: row,
    );
  }
}
