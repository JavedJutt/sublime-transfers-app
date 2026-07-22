import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// The type scale.
///
/// Fraunces (serif) for display, Public Sans for body, JetBrains Mono for data
/// that benefits from fixed advance (references, flight numbers, coordinates).
/// A serif display over a sans body is the mechanism behind the "confident
/// typography with clear hierarchy" requirement — it reads editorial rather
/// than utility-app.
abstract final class AppTypography {
  static TextStyle _display(
    double size,
    FontWeight weight,
    double height,
    double tracking,
  ) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: size * tracking,
        color: AppColors.ink,
      );

  static TextStyle _body(
    double size,
    FontWeight weight,
    double height,
    double tracking, {
    Color color = AppColors.inkBody,
  }) =>
      GoogleFonts.publicSans(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: size * tracking,
        color: color,
      );

  // ------------------------------------------------------------------ display
  /// Auth hero, dashboard greeting.
  static TextStyle get display1 => _display(44, FontWeight.w600, 1.08, -0.02);

  /// Screen titles on desktop.
  static TextStyle get display2 => _display(34, FontWeight.w600, 1.14, -0.015);

  /// Screen titles on mobile; ride reference.
  static TextStyle get h1 => _display(27, FontWeight.w600, 1.20, -0.01);

  /// Big figures in stat callouts.
  static TextStyle get numeric => _display(32, FontWeight.w600, 1.0, -0.01);

  // --------------------------------------------------------------------- body
  /// Section headings.
  static TextStyle get h2 =>
      _body(21, FontWeight.w600, 1.26, -0.005, color: AppColors.ink);

  /// Card titles, driver names.
  static TextStyle get h3 =>
      _body(17, FontWeight.w600, 1.32, 0, color: AppColors.ink);

  /// Driver-facing primary text — a step up, because drivers read at arm's
  /// length in bright light.
  static TextStyle get bodyLg => _body(17, FontWeight.w400, 1.52, 0);

  static TextStyle get body => _body(15, FontWeight.w400, 1.52, 0);

  /// Field values and emphasis within body copy.
  static TextStyle get bodyStrong =>
      _body(15, FontWeight.w600, 1.45, 0, color: AppColors.ink);

  /// Meta text, timestamps.
  static TextStyle get bodySm =>
      _body(13, FontWeight.w400, 1.46, 0, color: AppColors.inkMuted);

  /// ALL-CAPS label above a headline. Paired with [h2] in `SectionHeader`.
  static TextStyle get eyebrow =>
      _body(12, FontWeight.w700, 1.20, 0.10, color: AppColors.inkMuted);

  /// Form labels, chip text.
  static TextStyle get label =>
      _body(13, FontWeight.w600, 1.20, 0.01, color: AppColors.inkBody);

  /// Helper and error text below fields.
  static TextStyle get caption =>
      _body(12, FontWeight.w400, 1.40, 0.005, color: AppColors.inkMuted);

  static TextStyle get button => _body(15, FontWeight.w600, 1.0, 0.01);

  // --------------------------------------------------------------------- mono
  /// Ride references, flight numbers, coordinates.
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.40,
        color: AppColors.inkBody,
      );

  /// Assembles the Material [TextTheme] so any widget that reads
  /// `Theme.of(context).textTheme` lands on these tokens rather than defaults.
  static TextTheme get textTheme => TextTheme(
        displayLarge: display1,
        displayMedium: display2,
        displaySmall: h1,
        headlineLarge: h1,
        headlineMedium: h2,
        headlineSmall: h3,
        titleLarge: h3,
        titleMedium: bodyStrong,
        titleSmall: label,
        bodyLarge: bodyLg,
        bodyMedium: body,
        bodySmall: bodySm,
        labelLarge: button,
        labelMedium: label,
        labelSmall: caption,
      );
}
