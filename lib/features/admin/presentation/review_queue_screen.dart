import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/router/routes.dart';
import '../../../data/models/inbound_email.dart';
import '../../../providers/review_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/ride_card_skeleton.dart';
import '../../../shared/widgets/layout/max_width_body.dart';
import '../widgets/review/review_email_card.dart';

/// The parser review queue: emails that arrived but weren't confidently turned
/// into rides. An empty queue is good news, styled as such.
class ReviewQueueScreen extends ConsumerWidget {
  const ReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(reviewQueueProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(reviewQueueProvider);
          await ref.read(reviewQueueProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: MaxWidthBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'Review queue',
                  subtitle:
                      'Emails the parser wasn\'t sure about. Check, correct, '
                      'and turn into rides.',
                ),
                AsyncCollectionView<InboundEmail>(
                  value: queue,
                  onRetry: () => ref.invalidate(reviewQueueProvider),
                  loading: () => const RideCardSkeleton(count: 4),
                  empty: () => const EmptyState(
                    icon: AppIcons.success,
                    title: 'Nothing to review',
                    message: 'Every booking email has been handled. New ones '
                        'that need a look will appear here.',
                    tone: EmptyStateTone.positive,
                  ),
                  data: (items) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final email in items) ...[
                        ReviewEmailCard(
                          email: email,
                          onTap: () =>
                              context.push(R.adminReviewFor(email.id)),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.x5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A short, human label for the parser's `parse_error` reason code.
String reviewReasonLabel(String? raw) {
  if (raw == null || raw.isEmpty) return 'Needs a look';
  return switch (raw) {
    'not_a_booking' => 'Not a booking',
    'amendment' => 'Change to a booking',
    'cancellation' => 'Cancellation',
    'missing_required_fields' => 'Missing details',
    'ambiguous' => 'Ambiguous',
    'unreadable' => 'Couldn\'t read it',
    'parser_unconfigured' => 'Parser not configured',
    _ when raw.startsWith('parse_failed') => 'Parser error',
    _ when raw.startsWith('import_failed') => 'Import failed',
    _ => raw,
  };
}

Color reviewReasonColor(String? raw) {
  return switch (raw) {
    'not_a_booking' || 'cancellation' => AppColors.inkMuted,
    'parser_unconfigured' => AppColors.info,
    _ when raw != null && raw.startsWith('parse_failed') => AppColors.danger,
    _ => AppColors.warning,
  };
}
