import 'package:flutter/widgets.dart';

/// Shadows are used sparingly — 1px hairline borders carry most of the
/// separation. Only things that genuinely float above the page get [raised].
abstract final class AppShadows {
  /// Cards and list rows. Barely there; enough to lift off the canvas.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A16150F),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// Sheets, dialogs, dropdown menus, popovers.
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x1416150F),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -4,
    ),
  ];

  /// Sticky headers and the driver's bottom action bar, where the shadow
  /// signals content scrolling underneath.
  static const List<BoxShadow> overhang = [
    BoxShadow(
      color: Color(0x0F16150F),
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  static const List<BoxShadow> none = [];
}
