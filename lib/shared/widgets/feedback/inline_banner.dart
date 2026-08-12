import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../display/status_chip.dart';

/// A compact inline banner for a form-level message or a persistent status
/// notice (a failed Gmail sync, an offline notice). Distinct from a snackbar:
/// this stays put until the condition clears.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.tone = StatusTone.urgent,
    this.icon,
    this.action,
    this.title,
  });

  const InlineBanner.error({super.key, required this.message, this.action, this.title})
      : tone = StatusTone.urgent,
        icon = AppIcons.warning;

  const InlineBanner.warning({super.key, required this.message, this.action, this.title})
      : tone = StatusTone.pending,
        icon = AppIcons.warning;

  const InlineBanner.info({super.key, required this.message, this.action, this.title})
      : tone = StatusTone.scheduled,
        icon = AppIcons.info;

  final String message;
  final String? title;
  final StatusTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? AppIcons.info, size: 18, color: tone.foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTypography.label.copyWith(color: tone.foreground),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: AppTypography.bodySm.copyWith(color: tone.foreground),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}
