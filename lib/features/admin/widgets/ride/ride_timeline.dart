import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_icons.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../data/models/ride_status_event.dart';
import '../../../../shared/widgets/display/status_chip.dart';

/// The audit trail as a vertical timeline. Each entry shows the action, who
/// triggered it, when, and — for driver actions — the captured location or a
/// clear "location unavailable" note, so the record is honest either way.
///
/// Dedupes the RPC-authored row against the trigger safety-net row: when both
/// describe the same transition, the RPC row (which carries location) wins.
class RideTimeline extends StatelessWidget {
  const RideTimeline({super.key, required this.events});

  final List<RideStatusEvent> events;

  List<RideStatusEvent> get _deduped {
    // events arrive newest-first. Collapse a trigger row when an RPC row exists
    // for the same (to_status, second-resolution timestamp).
    final result = <RideStatusEvent>[];
    for (final e in events) {
      final dup = result.any((k) =>
          k.toStatus == e.toStatus &&
          k.action == e.action &&
          k.createdAt.difference(e.createdAt).abs().inSeconds < 2 &&
          k.isRpcRow &&
          e.isTriggerRow);
      if (dup) continue;
      result.add(e);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final items = _deduped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          _TimelineRow(
            event: items[i],
            isFirst: i == 0,
            isLast: i == items.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final RideStatusEvent event;
  final bool isFirst;
  final bool isLast;

  Color get _dotColor => switch (event.action) {
        'offer_declined' || 'cancelled' => AppColors.danger,
        'claimed' || 'offer_accepted' => AppColors.success,
        'created' => AppColors.brass,
        _ => event.toStatus.tone.foreground,
      };

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rail + dot.
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 6,
                  color: isFirst ? AppColors.transparent : AppColors.line,
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? AppColors.transparent : AppColors.line,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Content.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(event.actionLabel,
                            style: AppTypography.bodyStrong),
                      ),
                      Text(
                        Dates.dateTime.format(event.createdAt),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                  if (event.actorName != null || event.actorRole != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _actorLine,
                      style: AppTypography.bodySm.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                  if (event.note != null && event.note!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text('“${event.note}”',
                        style: AppTypography.bodySm
                            .copyWith(fontStyle: FontStyle.italic)),
                  ],
                  if (event.hasLocation)
                    _LocationChip(event: event)
                  else if (event.locationUnavailable)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Row(
                        children: [
                          const Icon(AppIcons.locationOff,
                              size: 12, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text('Location unavailable',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.warning)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _actorLine {
    final who = event.actorName ?? (event.actorRole?.name ?? 'system');
    final role = event.actorRole == null ? '' : ' · ${event.actorRole!.name}';
    return '$who$role';
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.event});

  final RideStatusEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(AppIcons.location, size: 12, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Text(
            '${event.lat!.toStringAsFixed(4)}, ${event.lng!.toStringAsFixed(4)}',
            style: AppTypography.mono.copyWith(
              fontSize: 11,
              color: AppColors.inkMuted,
            ),
          ),
          if (event.accuracyM != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text('±${event.accuracyM!.round()}m', style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}
