import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/date_x.dart';

/// The driver's day picker: a week strip they swipe through, one tap per day.
///
/// A driver mostly cares about today and the next couple of days, so the strip
/// centres on the selected day's week and pages a week at a time — big tap
/// targets, no tiny month grid to fumble with one-handed.
class DayStripSelector extends StatelessWidget {
  const DayStripSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    this.rideDays = const {},
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  /// Day keys (`yyyy-MM-dd`) that have at least one ride, for the dot marker.
  final Set<String> rideDays;

  @override
  Widget build(BuildContext context) {
    final weekStart = selected.weekStart;
    final days = [for (var i = 0; i < 7; i++) weekStart.addDays(i)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  Dates.relativeDay(selected),
                  style: AppTypography.h2,
                ),
              ),
              _NavButton(
                icon: AppIcons.chevronLeft,
                tooltip: 'Previous week',
                onTap: () => onSelect(selected.addDays(-7)),
              ),
              _NavButton(
                icon: AppIcons.chevronRight,
                tooltip: 'Next week',
                onTap: () => onSelect(selected.addDays(7)),
              ),
              if (!selected.isToday)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: TextButton(
                    onPressed: () => onSelect(DateTime.now().dayStart),
                    child: const Text('Today'),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 62,
          child: Row(
            children: [
              for (final day in days)
                Expanded(
                  child: _DayCell(
                    day: day,
                    selected: day.isSameDay(selected),
                    hasRides: rideDays.contains(day.dayKey),
                    onTap: () => onSelect(day),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      color: AppColors.inkMuted,
      onPressed: onTap,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.hasRides,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool hasRides;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = day.isToday;
    final fg = selected
        ? AppColors.inkInverse
        : isToday
            ? AppColors.brass
            : AppColors.inkBody;

    return Semantics(
      button: true,
      selected: selected,
      label: '${Dates.weekday.format(day)} ${Dates.dayMonth.format(day)}'
          '${hasRides ? ', has rides' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: selected ? AppColors.brass : AppColors.transparent,
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: selected
                  ? AppColors.brass
                  : isToday
                      ? AppColors.brassLine
                      : AppColors.line,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                Dates.dayName.format(day).toUpperCase(),
                style: AppTypography.caption.copyWith(
                  color: selected ? AppColors.inkInverse : AppColors.inkFaint,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Dates.dayNum.format(day),
                style: AppTypography.bodyStrong.copyWith(color: fg),
              ),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasRides
                      ? (selected ? AppColors.inkInverse : AppColors.brass)
                      : AppColors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
