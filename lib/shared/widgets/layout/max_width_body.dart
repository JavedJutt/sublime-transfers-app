import 'package:flutter/widgets.dart';

import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_spacing.dart';

/// Centres content within a maximum width and applies the page gutter.
///
/// This is how "generous whitespace and a calm layout even on data-dense admin
/// screens" is enforced structurally: no screen sets its own horizontal
/// padding, and no table stretches to 2000px on a wide monitor.
class MaxWidthBody extends StatelessWidget {
  const MaxWidthBody({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth,
    this.verticalPadding,
    this.horizontalPadding,
  });

  /// Narrow column for auth forms and single-purpose pages.
  const MaxWidthBody.form({
    super.key,
    required this.child,
    this.verticalPadding,
    this.horizontalPadding,
  }) : maxWidth = AppSpacing.maxFormWidth;

  final Widget child;
  final double maxWidth;
  final double? verticalPadding;
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final formFactor = AppBreakpoints.of(context);
    final gutter = horizontalPadding ?? AppBreakpoints.gutter(formFactor);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + gutter * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: gutter,
            vertical: verticalPadding ?? AppSpacing.xxl,
          ),
          child: child,
        ),
      ),
    );
  }
}
