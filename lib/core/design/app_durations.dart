import 'package:flutter/animation.dart';

/// Motion tokens. Movement is quiet and quick — this is a working tool, not a
/// showcase, and a driver mid-shift should never wait on an animation.
abstract final class AppDurations {
  /// Hover, focus, colour changes.
  static const Duration instant = Duration(milliseconds: 120);

  /// Chip selection, checkbox, small state transitions.
  static const Duration quick = Duration(milliseconds: 180);

  /// Sheets, dialogs, list item enter/exit.
  static const Duration normal = Duration(milliseconds: 260);

  /// Page transitions.
  static const Duration slow = Duration(milliseconds: 340);

  /// One shimmer sweep across a skeleton.
  static const Duration shimmer = Duration(milliseconds: 1400);

  /// How long a snackbar stays. Errors linger, because they may need reading
  /// twice; confirmations do not.
  static const Duration snackInfo = Duration(seconds: 4);
  static const Duration snackError = Duration(seconds: 6);

  /// Search input settle time before a query fires.
  static const Duration searchDebounce = Duration(milliseconds: 320);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOut;
  static const Curve exit = Curves.easeInCubic;
}
