import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_durations.dart';
import '../../../core/design/app_spacing.dart';

/// A single shimmering placeholder block.
///
/// Skeletons are shaped like the content they stand in for, so the layout
/// doesn't jump when data lands — that shift is the most common way a loading
/// state feels broken.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = AppRadius.brSm,
  });

  /// A circle, for avatar placeholders.
  const SkeletonBox.circle({super.key, required double size})
      : width = size,
        height = size,
        borderRadius = AppRadius.brPill;

  /// A short line of text.
  const SkeletonBox.line({super.key, this.width, this.height = 14})
      : borderRadius = AppRadius.brSm;

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunk,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// Wraps a subtree of [SkeletonBox]es in one shimmer sweep.
///
/// One shimmer per screen region rather than per box — many independent
/// shimmers read as noise.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceSunk,
      highlightColor: AppColors.canvas,
      period: AppDurations.shimmer,
      child: child,
    );
  }
}
