import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../shared/widgets/layout/responsive_builder.dart';

/// The editorial split layout for auth screens.
///
/// On desktop/tablet: a full-bleed brand panel on the left, the form on the
/// right — the premium, editorial treatment the visual direction asks for. On
/// mobile: a compact branded header above a scrolling form. One layout, so
/// sign-in, register, forgot-password, and pending-approval all feel of a
/// piece.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.eyebrow = 'Sublime Transfers',
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: ResponsiveBuilder(
        builder: (context, formFactor) {
          if (formFactor.isNarrow) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandHeaderCompact(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxl,
                        AppSpacing.x3,
                        AppSpacing.xxl,
                        AppSpacing.xxl,
                      ),
                      child: _Form(
                        eyebrow: eyebrow,
                        title: title,
                        subtitle: subtitle,
                        footer: footer,
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(
                flex: 6,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.x5),
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: AppSpacing.maxFormWidth),
                      child: _Form(
                        eyebrow: eyebrow,
                        title: title,
                        subtitle: subtitle,
                        footer: footer,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow.toUpperCase(), style: AppTypography.eyebrow),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: AppTypography.display2),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: AppTypography.bodyLg.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.x3),
        child,
        if (footer != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          footer!,
        ],
      ],
    );
  }
}

/// The left brand panel: a deep ink field with a subtle brass motif and the
/// premium tagline. Stands in for the full-bleed hero imagery until brand
/// assets are supplied.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1A13), Color(0xFF2B2013)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            top: -60,
            child: _Halo(size: 320, color: AppColors.brass.withValues(alpha: 0.16)),
          ),
          Positioned(
            left: -60,
            bottom: -40,
            child: _Halo(size: 220, color: AppColors.brass.withValues(alpha: 0.10)),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _Monogram(),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      'Sublime Transfers',
                      style: AppTypography.h3.copyWith(color: AppColors.inkInverse),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dispatch,\nrefined.',
                      style: AppTypography.display1.copyWith(
                        color: AppColors.inkInverse,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Text(
                        'Every booking, every driver, every ride — on one calm, '
                        'reliable board.',
                        style: AppTypography.bodyLg.copyWith(
                          color: AppColors.inkInverse.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '© 2026 Sublime Transfers',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.inkInverse.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeaderCompact extends StatelessWidget {
  const _BrandHeaderCompact();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.x3,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1A13), Color(0xFF2B2013)],
        ),
      ),
      child: Row(
        children: [
          _Monogram(),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Sublime Transfers',
            style: AppTypography.h3.copyWith(color: AppColors.inkInverse),
          ),
        ],
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.brass,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        'ST',
        style: AppTypography.bodyStrong.copyWith(
          color: AppColors.inkInverse,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
