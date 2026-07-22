import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';

/// Semantic tones available to status chips and banners.
///
/// This enum is the *only* sanctioned use of semantic colour in the app.
/// Keeping it here — rather than letting each feature pick colours — is what
/// stops the dashboard drifting into a multi-colour mess.
enum StatusTone {
  /// Needs attention: unassigned rides, failed syncs.
  urgent,

  /// Waiting on someone: offered, pending approval.
  pending,

  /// Confirmed but not yet moving: assigned, scheduled.
  scheduled,

  /// Happening now. Brass — the accent doubles as the "live" colour.
  active,

  /// Done.
  complete,

  /// Cancelled, no-show, archived.
  dormant,
}

extension StatusToneColors on StatusTone {
  Color get foreground => switch (this) {
        StatusTone.urgent => AppColors.danger,
        StatusTone.pending => AppColors.warning,
        StatusTone.scheduled => AppColors.info,
        StatusTone.active => AppColors.brass,
        StatusTone.complete => AppColors.success,
        StatusTone.dormant => AppColors.inkMuted,
      };

  Color get background => switch (this) {
        StatusTone.urgent => AppColors.dangerTint,
        StatusTone.pending => AppColors.warningTint,
        StatusTone.scheduled => AppColors.infoTint,
        StatusTone.active => AppColors.brassTint,
        StatusTone.complete => AppColors.successTint,
        StatusTone.dormant => AppColors.surfaceSunk,
      };

  Color get border => switch (this) {
        StatusTone.dormant => AppColors.line,
        _ => foreground.withValues(alpha: 0.24),
      };
}

/// A status badge: tint fill, same-hue text, hairline border.
///
/// Every status in the app renders through this one widget, which is what
/// makes a "Completed" ride chip and an "Approved" driver chip look like they
/// belong to the same system.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.dense = false,
    this.pulse = false,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;

  /// Tighter, for dense table rows and calendar cells.
  final bool dense;

  /// Adds a filled dot — used for genuinely live states so an in-progress ride
  /// reads as live at a glance across a room.
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final height = dense ? 20.0 : 24.0;
    final textStyle = (dense
            ? AppTypography.caption
            : AppTypography.label.copyWith(fontSize: 12))
        .copyWith(color: tone.foreground, fontWeight: FontWeight.w600);

    return Semantics(
      label: 'Status: $label',
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: AppRadius.brPill,
          border: Border.all(color: tone.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pulse) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: tone.foreground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
            ] else if (icon != null) ...[
              Icon(icon, size: dense ? 11 : 13, color: tone.foreground),
              const SizedBox(width: AppSpacing.xs + 1),
            ],
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}
