import 'package:flutter/material.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_durations.dart';
import '../../../core/design/app_shadows.dart';
import '../../../core/design/app_spacing.dart';

/// The card. Surface fill, hairline border, barely-there shadow.
///
/// Card-based layout is the spine of every list in this app — rides, drivers,
/// offers, calendar entries — so this widget carries the hover, selection, and
/// accent-edge affordances that those lists need, rather than each re-inventing
/// them.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.selected = false,
    this.accentEdge,
    this.borderColor,
    this.backgroundColor,
    this.elevated = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  /// Selected rows get a brass tint and border.
  final bool selected;

  /// A 3px colour bar down the leading edge. Used to carry ride status into a
  /// dense list without adding another chip.
  final Color? accentEdge;

  final Color? borderColor;
  final Color? backgroundColor;

  /// Raises the shadow. For cards that genuinely float — popovers, sheets.
  final bool elevated;

  final String? semanticLabel;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final formFactor = AppBreakpoints.of(context);
    final interactive = widget.onTap != null;
    final showHover = interactive && _hovered;

    final border = widget.borderColor ??
        (widget.selected
            ? AppColors.brassLine
            : showHover
                ? AppColors.lineStrong
                : AppColors.line);

    final background = widget.backgroundColor ??
        (widget.selected ? AppColors.brassTint : AppColors.surface);

    Widget content = Padding(
      padding: widget.padding ??
          EdgeInsets.all(AppBreakpoints.cardPadding(formFactor)),
      child: widget.child,
    );

    // The accent edge is a positioned strip rather than a stretched Row child
    // or a thick left border: a Row with CrossAxisAlignment.stretch forces
    // infinite height in an unbounded column (which is exactly where ride
    // cards live), and a non-uniform Border cannot carry a border radius.
    // The Stack takes its height from the padded content and the strip
    // stretches to match; the card's own clip rounds it.
    if (widget.accentEdge != null) {
      content = Stack(
        children: [
          content,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: widget.accentEdge!),
          ),
        ],
      );
    }

    Widget card = AnimatedContainer(
      duration: AppDurations.instant,
      curve: AppDurations.standard,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: border),
        boxShadow: widget.elevated
            ? AppShadows.raised
            : showHover
                ? AppShadows.overhang
                : AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (interactive) {
      card = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: AppRadius.brLg,
            splashColor: AppColors.brassTint.withValues(alpha: 0.6),
            highlightColor: AppColors.transparent,
            child: card,
          ),
        ),
      );
    }

    if (widget.semanticLabel != null) {
      card = Semantics(
        label: widget.semanticLabel,
        button: interactive,
        child: card,
      );
    }

    return card;
  }
}
