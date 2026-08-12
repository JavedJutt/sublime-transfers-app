import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/app_user.dart';
import '../../../providers/auth_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_avatar.dart';
import '../../../shared/widgets/display/app_card.dart';
import '../../../shared/widgets/display/key_value_row.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/display/status_chip.dart';
import '../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../shared/widgets/inputs/app_text_field.dart';
import '../../../shared/widgets/layout/max_width_body.dart';
import '../controllers/profile_controller.dart';

/// Shared profile view + inline edit for both roles.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editing = false;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _startEdit(AppUser user) {
    _name.text = user.fullName;
    _phone.text = user.phone ?? '';
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(profileControllerProvider.notifier).save(
          fullName: _name.text,
          phone: _phone.text,
        );
    if (!mounted) return;
    if (ok) {
      setState(() => _editing = false);
      AppSnackbar.success(context, 'Profile updated');
    } else {
      final err = ref.read(profileControllerProvider.notifier).errorOrNull;
      if (err != null) AppSnackbar.showFailure(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final saving = ref.watch(profileControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(AppIcons.arrowLeft),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: AsyncValueView<AppUser?>(
        value: userAsync,
        onRetry: () => ref.read(currentUserProvider.notifier).refresh(),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not signed in'));
          }
          return SingleChildScrollView(
            child: MaxWidthBody(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(user: user),
                  const SizedBox(height: AppSpacing.xxl),
                  if (_editing)
                    _EditForm(
                      formKey: _formKey,
                      name: _name,
                      phone: _phone,
                      saving: saving,
                      onCancel: () => setState(() => _editing = false),
                      onSave: _save,
                    )
                  else
                    _Details(user: user, onEdit: () => _startEdit(user)),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: 'Sign out',
                    icon: AppIcons.signOut,
                    variant: AppButtonVariant.secondary,
                    onPressed: () =>
                        ref.read(profileControllerProvider.notifier).signOut(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(
          name: user.fullName,
          imageUrl: user.avatarUrl,
          size: AppAvatarSize.xl,
        ),
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.fullName, style: AppTypography.h1),
              const SizedBox(height: AppSpacing.xs),
              Text(user.email, style: AppTypography.body.copyWith(color: AppColors.inkMuted)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  StatusChip(
                    label: user.isAdmin ? 'Admin' : 'Driver',
                    tone: user.isAdmin ? StatusTone.scheduled : StatusTone.active,
                  ),
                  if (user.driver != null)
                    StatusChip(
                      label: user.driver!.approvalStatus.label,
                      tone: user.driver!.approvalStatus.tone,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.user, required this.onEdit});

  final AppUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final driver = user.driver;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Contact details',
            dense: true,
            action: AppButton.ghost(
              label: 'Edit',
              icon: AppIcons.edit,
              size: AppButtonSize.sm,
              onPressed: onEdit,
            ),
          ),
          KeyValueRow(label: 'Full name', value: user.fullName, icon: AppIcons.customer),
          const Divider(),
          KeyValueRow(label: 'Email', value: user.email, icon: AppIcons.mailbox),
          const Divider(),
          KeyValueRow(label: 'Phone', value: user.phone, icon: AppIcons.phone),
          if (driver != null) ...[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(title: 'Vehicle', dense: true),
            KeyValueRow(
              label: 'Type',
              value: driver.vehicleType?.label,
              icon: AppIcons.vehicle,
            ),
            const Divider(),
            KeyValueRow(label: 'Make & model', value: driver.vehicleMake),
            const Divider(),
            KeyValueRow(
              label: 'Registration',
              value: driver.vehiclePlate,
              monospace: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.formKey,
    required this.name,
    required this.phone,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController phone;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'Edit contact details', dense: true),
            AppTextField(
              label: 'Full name',
              controller: name,
              required: true,
              textCapitalization: TextCapitalization.words,
              validator: Validators.name,
              enabled: !saving,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Phone',
              controller: phone,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
              enabled: !saving,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(label: 'Cancel', onPressed: saving ? null : onCancel),
                const SizedBox(width: AppSpacing.sm),
                AppButton.primary(
                  label: 'Save changes',
                  isLoading: saving,
                  onPressed: onSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
