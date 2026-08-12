import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/inputs/app_text_field.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
    // On success, the router guard redirects; nothing to do here.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final failure = state.hasError ? controller.errorOrNull : null;

    // Field-level errors from a ValidationFailure attach to their inputs.
    final fieldErrors = failure is ValidationFailure
        ? failure.fieldErrors
        : const <String, String>{};
    // A non-field failure (bad credentials, network) shows as a banner.
    final bannerError = failure != null && failure is! ValidationFailure
        ? failure.message
        : null;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to manage the day\'s rides.',
      footer: _footer(context),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bannerError != null) ...[
              _ErrorBanner(message: bannerError),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              prefixIcon: AppIcons.customer,
              validator: Validators.email,
              errorText: fieldErrors['email'],
              enabled: !state.isLoading,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Password',
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => Validators.required(v, field: 'Password'),
              errorText: fieldErrors['password'],
              enabled: !state.isLoading,
              suffix: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.inkMuted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Show password' : 'Hide password',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton.ghost(
                label: 'Forgot password?',
                size: AppButtonSize.sm,
                onPressed: state.isLoading
                    ? null
                    : () => context.push(R.forgotPassword),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.primary(
              label: 'Sign in',
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

  Widget _footer(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Are you a driver?',
          style: AppTypography.body.copyWith(color: AppColors.inkMuted),
        ),
        AppButton.ghost(
          label: 'Apply to drive',
          size: AppButtonSize.sm,
          onPressed: () => context.push(R.register),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.warning, size: 18, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
