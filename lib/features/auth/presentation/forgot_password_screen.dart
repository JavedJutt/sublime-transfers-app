import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/feedback/inline_banner.dart';
import '../../../shared/widgets/inputs/app_text_field.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text);
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final failure = state.hasError ? controller.errorOrNull : null;

    return AuthScaffold(
      eyebrow: 'Reset password',
      title: _sent ? 'Check your inbox' : 'Forgot password',
      subtitle: _sent
          ? 'If an account exists for that address, we\'ve sent a reset link.'
          : 'Enter your email and we\'ll send a reset link.',
      footer: Center(
        child: AppButton.ghost(
          label: 'Back to sign in',
          icon: AppIcons.arrowLeft,
          size: AppButtonSize.sm,
          onPressed: () => context.pop(),
        ),
      ),
      child: _sent
          ? _SentConfirmation(email: _email.text)
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (failure != null) ...[
                    InlineBanner.error(message: failure.message),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  AppTextField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: AppIcons.mailbox,
                    validator: Validators.email,
                    onFieldSubmitted: (_) => _submit(),
                    enabled: !state.isLoading,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton.primary(
                    label: 'Send reset link',
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    isLoading: state.isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
    );
  }
}

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.successTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.success, color: AppColors.success, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'A reset link is on its way to $email if that account exists. '
              'It may take a minute to arrive.',
              style: AppTypography.body.copyWith(color: AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}
