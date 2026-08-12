import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../data/models/inbound_email.dart';
import '../../../../shared/widgets/display/app_card.dart';
import '../../presentation/review_queue_screen.dart';

/// A queue row: what arrived, from where, why it needs a look, and — if the
/// parser got partway — a peek at the booking it found.
class ReviewEmailCard extends StatelessWidget {
  const ReviewEmailCard({super.key, required this.email, this.onTap});

  final InboundEmail email;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reasonColor = reviewReasonColor(email.parseError);
    final booking = email.booking;

    return AppCard(
      onTap: onTap,
      accentEdge: reasonColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  email.subject?.trim().isNotEmpty == true
                      ? email.subject!
                      : '(no subject)',
                  style: AppTypography.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ReasonChip(label: reviewReasonLabel(email.parseError), color: reasonColor),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(AppIcons.customer, size: 12, color: AppColors.inkFaint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  email.fromAddress ?? 'unknown sender',
                  style: AppTypography.bodySm.copyWith(color: AppColors.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (email.receivedAt != null)
                Text(
                  Dates.relativeTime(email.receivedAt!),
                  style: AppTypography.caption.copyWith(color: AppColors.inkFaint),
                ),
            ],
          ),
          if (booking != null && (booking.pickupAddress != null ||
              booking.pickupAt != null)) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            _BookingPeek(booking: booking),
          ],
          if (email.mailboxAddress != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(AppIcons.mailbox, size: 12, color: AppColors.inkFaint),
                const SizedBox(width: 4),
                Text(
                  email.mailboxAddress!,
                  style: AppTypography.caption.copyWith(color: AppColors.inkFaint),
                ),
                if (email.confidence != null) ...[
                  const Spacer(),
                  Text(
                    'Confidence ${(email.confidence! * 100).round()}%',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.inkFaint),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: AppTypography.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _BookingPeek extends StatelessWidget {
  const _BookingPeek({required this.booking});

  final ParsedBooking booking;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (booking.customerName?.isNotEmpty == true) booking.customerName!,
      if (booking.pickupAt != null) Dates.dateTime.format(booking.pickupAt!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parts.isNotEmpty)
          Text(parts.join(' · '),
              style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600)),
        if (booking.pickupAddress != null)
          Row(
            children: [
              const Icon(AppIcons.pickup, size: 12, color: AppColors.brass),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  booking.pickupAddress!,
                  style: AppTypography.caption.copyWith(color: AppColors.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
