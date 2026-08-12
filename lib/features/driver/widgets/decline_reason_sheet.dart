import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../shared/widgets/buttons/app_button.dart';

/// Asks why a driver is declining an offer, so the dispatcher gets a useful
/// reason back rather than a silent bounce. Returns the chosen reason string,
/// an empty string for "no reason given", or null if the sheet was dismissed
/// (meaning: don't decline after all).
abstract final class DeclineReasonSheet {
  static const _reasons = [
    'Too far away',
    'Already busy',
    'Vehicle mismatch',
    'Off duty soon',
  ];

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Decline this offer?', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The dispatcher will be told. A reason helps them reassign '
                'quickly.',
                style: AppTypography.bodySm.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final reason in _reasons) ...[
                _ReasonTile(
                  label: reason,
                  onTap: () => Navigator.of(context).pop(reason),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Decline without a reason',
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(''),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton.ghost(
                label: 'Keep the offer',
                fullWidth: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.line),
          ),
          child: Text(label, style: AppTypography.body),
        ),
      ),
    );
  }
}
