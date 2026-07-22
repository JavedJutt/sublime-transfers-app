import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_durations.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles [ThemeData] from the design tokens.
///
/// Light only, deliberately: the app is used in bright daylight by drivers and
/// on desktop monitors by dispatchers, and a single theme is what keeps the
/// contrast guarantees in [AppColors] verifiable.
abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brass,
      onPrimary: AppColors.inkInverse,
      primaryContainer: AppColors.brassTint,
      onPrimaryContainer: AppColors.brassPress,
      secondary: AppColors.ink,
      onSecondary: AppColors.inkInverse,
      secondaryContainer: AppColors.surfaceSunk,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.info,
      onTertiary: AppColors.inkInverse,
      error: AppColors.danger,
      onError: AppColors.inkInverse,
      errorContainer: AppColors.dangerTint,
      onErrorContainer: AppColors.danger,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.canvas,
      surfaceContainer: AppColors.surfaceSunk,
      onSurfaceVariant: AppColors.inkMuted,
      outline: AppColors.line,
      outlineVariant: AppColors.lineStrong,
      scrim: AppColors.scrim,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: AppTypography.textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      // Every interactive element clears the 48dp accessible target, including
      // the small button size — drivers tap one-handed while moving.
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: AppColors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.h3,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: AppBorders.hairline,
        space: AppBorders.hairline,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.brLg,
          side: BorderSide(color: AppColors.line),
        ),
      ),
      inputDecorationTheme: _inputTheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle:
            AppTypography.body.copyWith(color: AppColors.inkInverse),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        elevation: 0,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brXl),
        titleTextStyle: AppTypography.h2,
        contentTextStyle: AppTypography.body,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.lineStrong,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brSheet),
        clipBehavior: Clip.antiAlias,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: AppRadius.brSm,
        ),
        textStyle: AppTypography.caption.copyWith(color: AppColors.inkInverse),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brass,
        linearTrackColor: AppColors.surfaceSunk,
        circularTrackColor: AppColors.surfaceSunk,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brass
              : AppColors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.inkInverse),
        side: const BorderSide(color: AppColors.lineStrong, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.surface
              : AppColors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brass
              : AppColors.lineStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(AppColors.transparent),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brass
              : AppColors.lineStrong,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.brassTint,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
        ),
        selectedIconTheme: const IconThemeData(color: AppColors.brass, size: 22),
        unselectedIconTheme:
            const IconThemeData(color: AppColors.inkMuted, size: 22),
        selectedLabelTextStyle: AppTypography.label.copyWith(
          color: AppColors.brassPress,
        ),
        unselectedLabelTextStyle: AppTypography.label.copyWith(
          color: AppColors.inkMuted,
          fontWeight: FontWeight.w500,
        ),
        useIndicator: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        indicatorColor: AppColors.brassTint,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? AppColors.brass
                : AppColors.inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppTypography.caption.copyWith(
            fontWeight:
                s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? AppColors.brassPress
                : AppColors.inkMuted,
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.brMd,
          side: BorderSide(color: AppColors.line),
        ),
        textStyle: AppTypography.body,
      ),
      iconTheme: const IconThemeData(color: AppColors.inkBody, size: 20),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkMuted,
        minVerticalPadding: AppSpacing.md,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      splashColor: AppColors.brassTint,
      highlightColor: AppColors.transparent,
      hoverColor: AppColors.brassTint.withValues(alpha: 0.5),
      focusColor: AppColors.brassTint,
    );
  }

  /// One decoration theme for every input in the app. No feature code
  /// constructs its own — that is what keeps "no unstyled default form
  /// elements" true rather than aspirational.
  static InputDecorationTheme get _inputTheme => InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        hintStyle: AppTypography.body.copyWith(color: AppColors.inkFaint),
        labelStyle: AppTypography.label,
        floatingLabelStyle: AppTypography.label.copyWith(
          color: AppColors.brassPress,
        ),
        helperStyle: AppTypography.caption,
        helperMaxLines: 3,
        errorStyle: AppTypography.caption.copyWith(color: AppColors.danger),
        errorMaxLines: 3,
        prefixIconColor: AppColors.inkMuted,
        suffixIconColor: AppColors.inkMuted,
        border: _border(AppColors.line),
        enabledBorder: _border(AppColors.line),
        focusedBorder: _border(AppColors.brass, AppBorders.focus),
        errorBorder: _border(AppColors.danger),
        focusedErrorBorder: _border(AppColors.danger, AppBorders.focus),
        disabledBorder: _border(AppColors.line),
      );

  static OutlineInputBorder _border(
    Color color, [
    double width = AppBorders.hairline,
  ]) =>
      OutlineInputBorder(
        borderRadius: AppRadius.brMd,
        borderSide: BorderSide(color: color, width: width),
      );

  /// Motion tokens are exposed here so widgets can reach them via the theme
  /// without importing the token file directly.
  static const Duration quickMotion = AppDurations.quick;
}
