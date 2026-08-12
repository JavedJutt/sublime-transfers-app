import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_typography.dart';

enum AppAvatarSize {
  sm(28, 11),
  md(40, 14),
  lg(56, 19),
  xl(80, 27);

  const AppAvatarSize(this.diameter, this.fontSize);

  final double diameter;
  final double fontSize;
}

/// Circular avatar with an initials fallback.
///
/// Falls back to initials on a sunk surface — never a broken-image glyph and
/// never a generic silhouette, both of which read as unfinished. Network
/// failures land on the same initials, so an offline driver list still looks
/// intentional.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = AppAvatarSize.md,
    this.badge,
    this.borderColor,
  });

  final String name;
  final String? imageUrl;
  final AppAvatarSize size;

  /// Small overlay at the bottom-right — used for the driver on-duty dot.
  final Widget? badge;

  final Color? borderColor;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        _initials,
        style: AppTypography.bodyStrong.copyWith(
          fontSize: size.fontSize,
          color: AppColors.inkMuted,
          height: 1,
        ),
      ),
    );

    Widget avatar = Container(
      width: size.diameter,
      height: size.diameter,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunk,
        shape: BoxShape.circle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null || imageUrl!.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              width: size.diameter,
              height: size.diameter,
              placeholder: (_, _) => fallback,
              errorWidget: (_, _, _) => fallback,
              fadeInDuration: const Duration(milliseconds: 180),
            ),
    );

    if (badge != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(right: -1, bottom: -1, child: badge!),
        ],
      );
    }

    return Semantics(label: name, image: true, child: avatar);
  }
}
