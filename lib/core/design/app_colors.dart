import 'package:flutter/widgets.dart';

/// The single palette for the whole app: a warm neutral base with one brass
/// accent.
///
/// The discipline that keeps a data-dense dispatch dashboard calm is that
/// semantic colours (success/warning/danger/info) appear **only** in status
/// chips, banners, and validation — never as a surface fill, never in
/// navigation. Brass is the only colour that drives attention.
///
/// Contrast ratios in the comments are measured against [canvas].
abstract final class AppColors {
  // ---------------------------------------------------------------- neutrals
  /// Page background.
  static const Color canvas = Color(0xFFFAF8F5);

  /// Cards, sheets, inputs.
  static const Color surface = Color(0xFFFFFFFF);

  /// Wells, table headers, disabled fields, avatar fallbacks.
  static const Color surfaceSunk = Color(0xFFF2EFEA);

  /// Hairline borders — the primary separator throughout the app.
  static const Color line = Color(0xFFE6E1DA);

  /// Hover/emphasis borders.
  static const Color lineStrong = Color(0xFFD3CCC1);

  // -------------------------------------------------------------------- text
  /// Headlines and primary text. 16.9:1
  static const Color ink = Color(0xFF16150F);

  /// Body copy. 10.4:1
  static const Color inkBody = Color(0xFF3A3733);

  /// Supporting and meta text. 5.1:1 — clears AA at small sizes, which is
  /// what makes the app readable in daylight.
  static const Color inkMuted = Color(0xFF6E6862);

  /// Placeholders and disabled text. 2.9:1 — decorative only, never used to
  /// carry information on its own.
  static const Color inkFaint = Color(0xFF9A938B);

  /// Text on brass or ink fills.
  static const Color inkInverse = Color(0xFFFAF8F5);

  // ------------------------------------------------------------------ accent
  /// The one accent. Primary actions, active navigation, in-progress states.
  /// 5.0:1
  static const Color brass = Color(0xFF9A6B24);
  static const Color brassHover = Color(0xFF835A1D);
  static const Color brassPress = Color(0xFF6B4A17);

  /// Selected rows, accent chip fill, icon backdrops.
  static const Color brassTint = Color(0xFFF5EDE0);
  static const Color brassLine = Color(0xFFE0CDAE);

  // ---------------------------------------------------------------- semantic
  static const Color success = Color(0xFF2F6B4F);
  static const Color successTint = Color(0xFFE7F0EA);

  static const Color warning = Color(0xFF8A5D14);
  static const Color warningTint = Color(0xFFFBF0DC);

  static const Color danger = Color(0xFF9B3232);
  static const Color dangerTint = Color(0xFFF7E7E5);

  static const Color info = Color(0xFF3E5A73);
  static const Color infoTint = Color(0xFFE8EEF3);

  // --------------------------------------------------------------------- map
  static const Color mapPickup = brass;
  static const Color mapDropoff = ink;
  static const Color mapDriver = success;

  // ------------------------------------------------------------------- misc
  static const Color scrim = Color(0x6616150F);
  static const Color transparent = Color(0x00000000);
}
