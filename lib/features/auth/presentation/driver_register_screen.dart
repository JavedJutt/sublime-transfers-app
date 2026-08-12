import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/enums.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/feedback/inline_banner.dart';
import '../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../shared/widgets/inputs/app_text_field.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Driver self-registration. The account is created 'pending' and cannot
/// receive rides until an admin approves it — on success the router sends the
/// new driver straight to the pending-approval screen.
class DriverRegisterScreen extends ConsumerStatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  ConsumerState<DriverRegisterScreen> createState() =>
      _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends ConsumerState<DriverRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _make = TextEditingController();
  final _plate = TextEditingController();
  VehicleType? _vehicleType;
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _make, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).registerDriver(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
          phone: _phone.text,
          vehicleType: _vehicleType,
          vehicleMake: _make.text,
          vehiclePlate: _plate.text,
        );
    // Router redirects to pending-approval on success.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final failure = state.hasError ? controller.errorOrNull : null;
    final fieldErrors =
        failure is ValidationFailure ? failure.fieldErrors : const <String, String>{};
    final bannerError = failure != null && failure is! ValidationFailure
        ? failure.message
        : null;

    return AuthScaffold(
      eyebrow: 'Driver application',
      title: 'Apply to drive',
      subtitle: 'Create your account. An admin reviews every application before '
          'you can receive rides.',
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Already have an account?',
              style: AppTypography.body.copyWith(color: AppColors.inkMuted)),
          AppButton.ghost(
            label: 'Sign in',
            size: AppButtonSize.sm,
            onPressed: () => context.pop(),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bannerError != null) ...[
              InlineBanner.error(message: bannerError),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppTextField(
              label: 'Full name',
              controller: _name,
              required: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              prefixIcon: AppIcons.customer,
              validator: Validators.name,
              enabled: !state.isLoading,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Email',
              controller: _email,
              required: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: AppIcons.mailbox,
              validator: Validators.email,
              errorText: fieldErrors['email'],
              enabled: !state.isLoading,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Phone',
              controller: _phone,
              required: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              prefixIcon: AppIcons.phone,
              validator: Validators.phone,
              enabled: !state.isLoading,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Password',
              controller: _password,
              required: true,
              obscureText: _obscure,
              helper: 'At least 8 characters.',
              validator: Validators.password,
              errorText: fieldErrors['password'],
              enabled: !state.isLoading,
              suffix: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.inkMuted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              title: 'Your vehicle',
              subtitle: 'Optional now — an admin can complete this later.',
              dense: true,
            ),
            AppDropdown<VehicleType>(
              label: 'Vehicle type',
              value: _vehicleType,
              hint: 'Select a class',
              prefixIcon: AppIcons.vehicle,
              onChanged: state.isLoading
                  ? null
                  : (v) => setState(() => _vehicleType = v),
              items: [
                for (final t in VehicleType.values)
                  AppDropdownItem(
                    value: t,
                    label: t.label,
                    subtitle: t.description,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Make & model',
                    controller: _make,
                    hint: 'Mercedes E-Class',
                    enabled: !state.isLoading,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: AppTextField(
                    label: 'Registration',
                    controller: _plate,
                    hint: 'LX21 ATE',
                    textCapitalization: TextCapitalization.characters,
                    enabled: !state.isLoading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppButton.primary(
              label: 'Submit application',
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
