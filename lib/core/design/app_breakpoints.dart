import 'package:flutter/widgets.dart';

import 'app_spacing.dart';

/// Layout classes.
///
/// The driver app is mobile-first and effectively always [FormFactor.mobile].
/// The admin dashboard is desktop-primary but must stay usable all the way
/// down — hence a distinct [FormFactor.compact] rather than letting the
/// desktop layout squeeze.
enum FormFactor {
  /// < 600 — phones. Driver app's home turf.
  mobile,

  /// 600–1023 — large phones landscape, small tablets, narrow desktop windows.
  compact,

  /// 1024–1279 — tablets and half-screen desktop windows.
  tablet,

  /// >= 1280 — the admin dashboard's primary context.
  desktop;

  bool get isMobile => this == FormFactor.mobile;
  bool get isCompact => this == FormFactor.compact;
  bool get isTablet => this == FormFactor.tablet;
  bool get isDesktop => this == FormFactor.desktop;

  /// True below the tablet threshold — where the admin shell switches from a
  /// persistent rail to a hamburger drawer.
  bool get isNarrow => this == FormFactor.mobile || this == FormFactor.compact;

  bool get isWide => this == FormFactor.tablet || this == FormFactor.desktop;
}

abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double tablet = 1024;
  static const double desktop = 1280;

  static FormFactor of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static FormFactor fromWidth(double width) {
    if (width >= desktop) return FormFactor.desktop;
    if (width >= tablet) return FormFactor.tablet;
    if (width >= compact) return FormFactor.compact;
    return FormFactor.mobile;
  }

  /// Horizontal page padding per form factor.
  static double gutter(FormFactor f) => switch (f) {
        FormFactor.mobile => AppSpacing.lg,
        FormFactor.compact => AppSpacing.xxl,
        FormFactor.tablet => AppSpacing.xxl,
        FormFactor.desktop => AppSpacing.x4,
      };

  /// Internal padding for cards.
  static double cardPadding(FormFactor f) =>
      f.isNarrow ? AppSpacing.lg : AppSpacing.xxl;

  /// Vertical gap between major page sections.
  static double sectionGap(FormFactor f) =>
      f.isNarrow ? AppSpacing.xxl : AppSpacing.x4;

  /// Column count for the dashboard stat row and card grids.
  static int gridColumns(FormFactor f) => switch (f) {
        FormFactor.mobile => 1,
        FormFactor.compact => 2,
        FormFactor.tablet => 2,
        FormFactor.desktop => 3,
      };
}
