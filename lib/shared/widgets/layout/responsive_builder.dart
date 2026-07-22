import 'package:flutter/widgets.dart';

import '../../../core/design/app_breakpoints.dart';

/// Builds against the current [FormFactor].
///
/// Screens branch on this rather than reading raw pixel widths, so the
/// breakpoints live in exactly one place and the responsive sweep is testable
/// by pumping a fixed size.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, FormFactor formFactor) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Uses the incoming constraints, not the screen size, so a widget
        // inside a rail or a split pane adapts to its own box.
        final formFactor = AppBreakpoints.fromWidth(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width,
        );
        return builder(context, formFactor);
      },
    );
  }
}

/// Picks one of up to four widgets by form factor, falling back downward.
class ResponsiveSwitch extends StatelessWidget {
  const ResponsiveSwitch({
    super.key,
    required this.mobile,
    this.compact,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? compact;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, formFactor) => switch (formFactor) {
        FormFactor.desktop => desktop ?? tablet ?? compact ?? mobile,
        FormFactor.tablet => tablet ?? compact ?? mobile,
        FormFactor.compact => compact ?? mobile,
        FormFactor.mobile => mobile,
      },
    );
  }
}
