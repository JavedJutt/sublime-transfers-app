import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_durations.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';

enum AppButtonVariant {
  /// Brass fill. One per screen region — the single obvious next action.
  primary,

  /// Surface fill with a hairline border. The default for everything else.
  secondary,

  /// Text only. Tertiary actions, "Cancel", inline links.
  ghost,

  /// Danger fill. Cancel a ride, reject a driver, delete.
  destructive,

  /// Brass tint fill. An accented action that shouldn't outrank the primary —
  /// used for "Claim" on offer cards where several sit in one list.
  accentQuiet,
}

enum AppButtonSize {
  /// 36dp visual height. Still clears 48dp of tap target via padding.
  sm,

  /// 44dp. The default.
  md,

  /// 52dp. Form submits, primary page actions.
  lg,

  /// 56dp. Driver primary actions — tapped one-handed, often in motion.
  xl,
}

/// The only button in the app.
///
/// Loading state preserves the label and reserves its width, so the button
/// never changes size mid-press and shift the layout under the user's finger.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.secondary,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
  }) : variant = AppButtonVariant.primary;

  const AppButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
  }) : variant = AppButtonVariant.destructive;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.md,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.semanticLabel,
    this.tooltip,
  }) : variant = AppButtonVariant.ghost;

  final String label;

  /// Null disables the button. There is no separate `isDisabled` flag —
  /// a disabled button with a live callback is a bug waiting to happen.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool fullWidth;
  final String? semanticLabel;
  final String? tooltip;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  double get _height => switch (widget.size) {
        AppButtonSize.sm => 36,
        AppButtonSize.md => 44,
        AppButtonSize.lg => 52,
        AppButtonSize.xl => 56,
      };

  double get _horizontalPadding => switch (widget.size) {
        AppButtonSize.sm => AppSpacing.md,
        AppButtonSize.md => AppSpacing.lg,
        AppButtonSize.lg => AppSpacing.xl,
        AppButtonSize.xl => AppSpacing.xxl,
      };

  double get _iconSize => switch (widget.size) {
        AppButtonSize.sm => 16,
        AppButtonSize.md => 18,
        AppButtonSize.lg => 20,
        AppButtonSize.xl => 22,
      };

  TextStyle get _textStyle => switch (widget.size) {
        AppButtonSize.sm => AppTypography.button.copyWith(fontSize: 13),
        AppButtonSize.md => AppTypography.button,
        AppButtonSize.lg => AppTypography.button.copyWith(fontSize: 16),
        AppButtonSize.xl => AppTypography.button.copyWith(fontSize: 17),
      };

  _ButtonPalette get _palette {
    if (!_enabled) {
      return const _ButtonPalette(
        background: AppColors.surfaceSunk,
        foreground: AppColors.inkFaint,
        border: AppColors.line,
      );
    }
    return switch (widget.variant) {
      AppButtonVariant.primary => _ButtonPalette(
          background: _pressed
              ? AppColors.brassPress
              : _hovered
                  ? AppColors.brassHover
                  : AppColors.brass,
          foreground: AppColors.inkInverse,
          border: AppColors.transparent,
        ),
      AppButtonVariant.secondary => _ButtonPalette(
          background: _pressed || _hovered
              ? AppColors.surfaceSunk
              : AppColors.surface,
          foreground: AppColors.ink,
          border: _hovered ? AppColors.lineStrong : AppColors.line,
        ),
      AppButtonVariant.ghost => _ButtonPalette(
          background: _pressed || _hovered
              ? AppColors.surfaceSunk
              : AppColors.transparent,
          foreground: AppColors.brassPress,
          border: AppColors.transparent,
        ),
      AppButtonVariant.destructive => _ButtonPalette(
          background: _pressed || _hovered
              ? const Color(0xFF7E2828)
              : AppColors.danger,
          foreground: AppColors.inkInverse,
          border: AppColors.transparent,
        ),
      AppButtonVariant.accentQuiet => _ButtonPalette(
          background: _pressed || _hovered
              ? AppColors.brassLine
              : AppColors.brassTint,
          foreground: AppColors.brassPress,
          border: AppColors.transparent,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;

    final content = Stack(
      alignment: Alignment.center,
      children: [
        // The label stays laid out while loading so the button keeps its
        // width; only its opacity drops.
        Opacity(
          opacity: widget.isLoading ? 0 : 1,
          child: Row(
            mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: _iconSize, color: palette.foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: _textStyle.copyWith(color: palette.foreground),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (widget.trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  widget.trailingIcon,
                  size: _iconSize,
                  color: palette.foreground,
                ),
              ],
            ],
          ),
        ),
        if (widget.isLoading)
          SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.foreground,
            ),
          ),
      ],
    );

    Widget button = AnimatedContainer(
      duration: AppDurations.instant,
      curve: AppDurations.standard,
      height: _height,
      width: widget.fullWidth ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: palette.border),
      ),
      child: Center(
        widthFactor: widget.fullWidth ? null : 1,
        child: content,
      ),
    );

    // Guarantees a 48dp target even for the 36dp small size.
    if (_height < AppSpacing.minTapTarget) {
      button = SizedBox(height: AppSpacing.minTapTarget, child: Center(child: button));
    }

    Widget result = Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.label,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          onTap: _enabled ? widget.onPressed : null,
          behavior: HitTestBehavior.opaque,
          child: ExcludeSemantics(child: button),
        ),
      ),
    );

    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }
    return result;
  }
}

class _ButtonPalette {
  const _ButtonPalette({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
