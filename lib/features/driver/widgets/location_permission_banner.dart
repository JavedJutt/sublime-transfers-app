import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../services/location/location_service.dart';
import '../../../shared/widgets/buttons/app_button.dart';

/// The in-app rationale for location, shown on the active ride before the
/// system prompt. A cold OS prompt gets reflexively denied — and on Android
/// that burns the one chance — so we explain *why* first: every status update
/// is stamped with where it happened, which is how the office proves a pickup.
///
/// It never hard-blocks the advance button. A status change is never held up by
/// location (a driver in an airport car park still needs to mark "arrived"); the
/// banner just makes granting the obvious next step.
class LocationPermissionBanner extends StatelessWidget {
  const LocationPermissionBanner({
    super.key,
    required this.state,
    required this.onEnable,
    required this.onOpenSettings,
    this.busy = false,
  });

  final LocationPermissionState state;
  final VoidCallback onEnable;
  final VoidCallback onOpenSettings;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (state.isGranted) return const SizedBox.shrink();

    final needsSettings = state.needsSettings ||
        state == LocationPermissionState.serviceDisabled;

    final (title, body) = switch (state) {
      LocationPermissionState.serviceDisabled => (
          'Location is turned off',
          'Turn on location for your device so ride updates record where they '
              'happened.',
        ),
      LocationPermissionState.permanentlyDenied => (
          'Location permission is off',
          'Enable location in Settings so each status update is stamped with '
              'your position — the office relies on it to confirm pickups.',
        ),
      _ => (
          'Share your location',
          'Each time you update a ride, we record where you are. It confirms '
              'pickups and drop-offs for the office — nothing more.',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warningTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.location, size: 18, color: AppColors.warning),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyStrong
                      .copyWith(color: AppColors.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: AppTypography.bodySm.copyWith(color: AppColors.inkBody),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.primary(
            label: needsSettings ? 'Open Settings' : 'Enable location',
            icon: AppIcons.location,
            size: AppButtonSize.md,
            isLoading: busy,
            onPressed: busy ? null : (needsSettings ? onOpenSettings : onEnable),
          ),
        ],
      ),
    );
  }
}
