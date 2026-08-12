import 'package:flutter/widgets.dart';

/// 4pt spacing scale. Generous whitespace is enforced structurally through
/// [pageGutter] and [cardPadding] rather than left to per-screen judgement.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double x3 = 32;
  static const double x4 = 40;
  static const double x5 = 48;
  static const double x6 = 64;
  static const double x7 = 80;
  static const double x8 = 112;

  /// Widest the content column ever gets, so a 27" monitor doesn't produce
  /// 2000px-wide table rows.
  static const double maxContentWidth = 1440;

  /// Narrow column for auth forms and single-purpose dialogs.
  static const double maxFormWidth = 460;

  /// Minimum interactive target. Applies even to the small button size.
  static const double minTapTarget = 48;
}

/// Corner radii.
abstract final class AppRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));

  /// Bottom sheets: rounded top only.
  static const BorderRadius brSheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// Border widths. Hairlines carry most of the separation in this design;
/// shadows are reserved for things that genuinely float.
abstract final class AppBorders {
  static const double hairline = 1;
  static const double focus = 2;
}
