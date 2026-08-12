import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';

/// The text input.
///
/// Every field in the app is this widget or one built on it — no feature code
/// constructs a bare [TextFormField]. That rule is what makes "no unstyled
/// default form elements" hold, and it means a change to focus styling or
/// error presentation happens once.
///
/// The label sits *above* the field rather than floating inside it: at a
/// glance on a dense admin form, a static label column scans far faster than
/// twelve animated floating labels.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helper,
    this.errorText,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.required = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.autofocus = false,
    this.autofillHints,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;

  /// Guidance shown below the field in muted text.
  final String? helper;

  /// Server-side or cross-field error. Local [validator] errors take their own
  /// path through [Form].
  final String? errorText;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;

  /// Adds a subtle required marker. Purely presentational — validation is
  /// still [validator]'s job.
  final bool required;

  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
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
                    style: AppTypography.label.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
              ],
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          focusNode: focusNode,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          style: AppTypography.body.copyWith(
            color: enabled ? AppColors.ink : AppColors.inkMuted,
          ),
          cursorColor: AppColors.brass,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            errorText: errorText,
            filled: true,
            fillColor: enabled && !readOnly
                ? AppColors.surface
                : AppColors.surfaceSunk,
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
            suffixIcon: suffix,
            counterText: '',
          ),
        ),
        // Character counter lives outside the decoration so it can sit
        // opposite the helper text rather than pushing the field around.
        if (maxLength != null && controller != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller!,
              builder: (context, value, _) => Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${value.text.characters.length} / $maxLength',
                  style: AppTypography.caption.copyWith(
                    color: value.text.characters.length > maxLength!
                        ? AppColors.danger
                        : AppColors.inkFaint,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
