import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/routes.dart';
import '../../../data/models/enums.dart';
import '../../../providers/auth_providers.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/feedback/inline_banner.dart';
import '../controllers/auth_controller.dart';

/// Where a self-registered driver waits. The router confines an unapproved
/// driver here (plus profile). "Check status" re-resolves identity — when an
/// admin approves them, the guard reroutes to the driver home on the next
/// refresh.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() =>
      _PendingApprovalScreenState();
}

class _PendingApprovalScreenState
    extends ConsumerState<PendingApprovalScreen> {
  bool _checking = false;
  String? _checkError;

  Future<void> _checkStatus() async {
    setState(() {
      _checking = true;
      _checkError = null;
    });
    try {
      await ref.read(currentUserProvider.notifier).refresh();
    } catch (_) {
      if (mounted) {
        setState(() => _checkError = 'Couldn\'t check your status. Tap to retry.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final rejected =
        user?.driver?.approvalStatus == DriverApprovalStatus.rejected;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: rejected
                          ? AppColors.dangerTint
                          : AppColors.brassTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      rejected ? AppIcons.warning : AppIcons.time,
                      size: 40,
                      color: rejected ? AppColors.danger : AppColors.brass,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    rejected ? 'Application not approved' : 'Awaiting approval',
                    style: AppTypography.h1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    rejected
                        ? (user?.driver?.rejectionReason ??
                            'Your application wasn\'t approved. Contact the '
                                'office for details.')
                        : 'Thanks${user?.fullName != null ? ', ${user!.fullName.split(' ').first}' : ''}. '
                            'An admin is reviewing your application. You\'ll be '
                            'able to receive rides as soon as it\'s approved — '
                            'usually within a business day.',
                    style: AppTypography.bodyLg.copyWith(color: AppColors.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (_checkError != null) ...[
                    InlineBanner.warning(message: _checkError!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (!rejected)
                    AppButton.primary(
                      label: 'Check status',
                      icon: AppIcons.refresh,
                      size: AppButtonSize.lg,
                      fullWidth: true,
                      isLoading: _checking,
                      onPressed: _checkStatus,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.ghost(
                    label: 'Edit profile',
                    onPressed: () => context.push(R.profile),
                  ),
                  AppButton.ghost(
                    label: 'Sign out',
                    icon: AppIcons.signOut,
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
