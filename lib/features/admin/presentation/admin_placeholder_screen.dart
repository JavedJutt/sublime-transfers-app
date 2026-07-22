import 'package:flutter/material.dart';

import '../../../core/design/app_icons.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/layout/max_width_body.dart';

/// A themed "coming in a later phase" placeholder for admin sections not yet
/// built (drivers, live map, review queue, Gmail settings). Keeps navigation
/// whole and on-brand rather than dead-ending on a blank route.
class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({
    super.key,
    required this.title,
    required this.phase,
    this.icon = AppIcons.settings,
  });

  final String title;
  final String phase;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: MaxWidthBody(
          maxWidth: 480,
          child: EmptyState(
            icon: icon,
            title: title,
            message: 'This section is coming in $phase.',
            tone: EmptyStateTone.accent,
          ),
        ),
      ),
    );
  }
}
