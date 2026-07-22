import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import 'skeleton_box.dart';

/// A shimmering placeholder shaped like a RideCard, so the list doesn't jump
/// when data lands.
class RideCardSkeleton extends StatelessWidget {
  const RideCardSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            _row(),
            if (i < count - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _row() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: AppColors.line),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 44, height: 18),
                  SizedBox(height: AppSpacing.xs),
                  SkeletonBox(width: 60, height: 10),
                ],
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 14),
                    SizedBox(height: AppSpacing.sm),
                    SkeletonBox(width: 240, height: 11),
                  ],
                ),
              ),
              SkeletonBox(width: 72, height: 20),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              SkeletonBox(width: 40, height: 11),
              SizedBox(width: AppSpacing.lg),
              SkeletonBox(width: 40, height: 11),
              Spacer(),
              SkeletonBox(width: 90, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}
