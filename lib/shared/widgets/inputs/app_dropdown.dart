import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';

/// A styled select.
///
/// Wraps [DropdownButtonFormField] so the menu, the field, and the disabled
/// state all inherit the design system rather than Material defaults — the
/// stock dropdown is the most conspicuous "unstyled default form element" in
/// a Flutter app.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.helper,
    this.errorText,
    this.validator,
    this.prefixIcon,
    this.enabled = true,
    this.required = false,
    this.isLoading = false,
  });

  final String label;
  final T? value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? helper;
  final String? errorText;
  final String? Function(T?)? validator;
  final IconData? prefixIcon;
  final bool enabled;
  final bool required;

  /// Renders a skeleton in place of the options while they load — assignment
  /// sheets open before the driver list has arrived.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && !isLoading && onChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
          child: RichText(
            text: TextSpan(
              text: label,
              style: AppTypography.label.copyWith(
                color: enabled ? AppColors.inkBody : AppColors.inkFaint,
              ),
              children: [
                if (required)
                  TextSpan(
                    text: ' *',
                    style: AppTypography.label.copyWith(color: AppColors.danger),
                  ),
              ],
            ),
          ),
        ),
        if (isLoading)
          Container(
            height: AppSpacing.minTapTarget,
            decoration: BoxDecoration(
              color: AppColors.surfaceSunk,
              borderRadius: AppRadius.brMd,
              border: Border.all(color: AppColors.line),
            ),
          )
        else
          DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            validator: validator,
            onChanged: interactive ? onChanged : null,
            icon: const Icon(AppIcons.chevronDown, size: 18),
            iconEnabledColor: AppColors.inkMuted,
            iconDisabledColor: AppColors.inkFaint,
            dropdownColor: AppColors.surface,
            borderRadius: AppRadius.brMd,
            elevation: 2,
            style: AppTypography.body.copyWith(color: AppColors.ink),
            hint: hint == null
                ? null
                : Text(
                    hint!,
                    style:
                        AppTypography.body.copyWith(color: AppColors.inkFaint),
                  ),
            decoration: InputDecoration(
              helperText: helper,
              errorText: errorText,
              filled: true,
              fillColor: enabled ? AppColors.surface : AppColors.surfaceSunk,
              prefixIcon: prefixIcon == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.sm,
                      ),
                      child: Icon(prefixIcon, size: 18),
                    ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
            ),
            // The collapsed field is height-constrained, so it shows the label
            // alone. Subtitles are menu-only detail — rendering them in the
            // closed field overflows it.
            selectedItemBuilder: (context) => [
              for (final item in items)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    children: [
                      if (item.leading != null) ...[
                        item.leading!,
                        const SizedBox(width: AppSpacing.sm),
                      ] else if (item.icon != null) ...[
                        Icon(item.icon, size: 16, color: AppColors.inkMuted),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTypography.body.copyWith(color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            items: [
              for (final item in items)
                DropdownMenuItem<T>(
                  value: item.value,
                  enabled: item.enabled,
                  child: Row(
                    children: [
                      if (item.leading != null) ...[
                        item.leading!,
                        const SizedBox(width: AppSpacing.sm),
                      ] else if (item.icon != null) ...[
                        Icon(
                          item.icon,
                          size: 16,
                          color: item.enabled
                              ? AppColors.inkMuted
                              : AppColors.inkFaint,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.label,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body.copyWith(
                                color: item.enabled
                                    ? AppColors.ink
                                    : AppColors.inkFaint,
                              ),
                            ),
                            if (item.subtitle != null)
                              Text(
                                item.subtitle!,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption,
                              ),
                          ],
                        ),
                      ),
                      if (item.trailing != null) item.trailing!,
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class AppDropdownItem<T> {
  const AppDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.enabled = true,
  });

  final T value;
  final String label;

  /// Second line — a driver's vehicle, an admin's email.
  final String? subtitle;

  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;

  /// Disabled but visible, e.g. an off-duty driver, so the dispatcher can see
  /// *why* they can't pick them.
  final bool enabled;
}
