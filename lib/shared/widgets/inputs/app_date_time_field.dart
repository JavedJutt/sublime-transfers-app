import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_theme.dart';
import '../../../core/design/app_typography.dart';

/// Combined date + time picker.
///
/// Pickup time is the single most consequential field in a booking — it is the
/// calendar's sort key and the thing a driver plans their day around — so it
/// gets a dedicated control that always shows the weekday. "Thu 12 Mar, 14:20"
/// makes a wrong-day parse obvious in a way "12/03 14:20" does not.
class AppDateTimeField extends StatelessWidget {
  const AppDateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.errorText,
    this.required = false,
    this.enabled = true,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime>? onChanged;
  final String? helper;
  final String? errorText;
  final bool required;
  final bool enabled;
  final DateTime? firstDate;
  final DateTime? lastDate;

  static final _formatter = DateFormat('EEE d MMM yyyy, HH:mm');

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final seed = value ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: seed,
      // Past dates stay selectable: bookings are sometimes entered after the
      // fact, and a picker that refuses yesterday blocks legitimate data entry.
      firstDate: firstDate ?? now.subtract(const Duration(days: 365)),
      lastDate: lastDate ?? now.add(const Duration(days: 730)),
      builder: (context, child) =>
          Theme(data: AppTheme.light, child: child ?? const SizedBox.shrink()),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
      builder: (context, child) => Theme(
        data: AppTheme.light,
        child: MediaQuery(
          // Transfer bookings are quoted in 24h; a 12h picker invites
          // AM/PM mistakes on an airport pickup.
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
    if (time == null) return;

    onChanged?.call(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onChanged != null;
    final hasError = errorText != null;

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
        Semantics(
          button: true,
          label: value == null
              ? '$label, not set'
              : '$label, ${_formatter.format(value!)}',
          child: ExcludeSemantics(
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: interactive ? () => _pick(context) : null,
                borderRadius: AppRadius.brMd,
                child: Container(
                  height: AppSpacing.minTapTarget,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: enabled ? AppColors.surface : AppColors.surfaceSunk,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(
                      color: hasError ? AppColors.danger : AppColors.line,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        AppIcons.calendar,
                        size: 18,
                        color: AppColors.inkMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          value == null
                              ? 'Select date and time'
                              : _formatter.format(value!),
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            color: value == null
                                ? AppColors.inkFaint
                                : enabled
                                    ? AppColors.ink
                                    : AppColors.inkMuted,
                          ),
                        ),
                      ),
                      if (interactive)
                        const Icon(
                          AppIcons.chevronDown,
                          size: 16,
                          color: AppColors.inkMuted,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              errorText!,
              style: AppTypography.caption.copyWith(color: AppColors.danger),
            ),
          )
        else if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(helper!, style: AppTypography.caption),
          ),
      ],
    );
  }
}
