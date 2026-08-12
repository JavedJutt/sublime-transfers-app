import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/routes.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/inbound_email.dart';
import '../../../providers/review_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_card.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../shared/widgets/feedback/confirm_dialog.dart';
import '../../../shared/widgets/feedback/empty_state.dart';
import '../../../shared/widgets/feedback/error_state.dart';
import '../../../shared/widgets/inputs/app_counter_field.dart';
import '../../../shared/widgets/inputs/app_date_time_field.dart';
import '../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../shared/widgets/inputs/app_text_field.dart';
import '../../../shared/widgets/layout/max_width_body.dart';
import 'review_queue_screen.dart';

/// Work a single email: read what arrived, correct what the parser guessed, and
/// either create the ride or reject the email. Re-parse is available too — handy
/// once the OpenAI key is set on an email that came in as "parser_unconfigured".
class ReviewDetailScreen extends ConsumerWidget {
  const ReviewDetailScreen({super.key, required this.emailId});

  final String emailId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailAsync = ref.watch(reviewEmailProvider(emailId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(R.adminReview),
        ),
        title: const Text('Review email'),
      ),
      body: AsyncValueView<InboundEmail?>(
        value: emailAsync,
        onRetry: () => ref.invalidate(reviewEmailProvider(emailId)),
        error: (err, retry) => ErrorState(
          error: err,
          onRetry: retry,
          action: AppButton.ghost(
            label: 'Back to queue',
            onPressed: () => context.go(R.adminReview),
          ),
        ),
        data: (email) {
          if (email == null) {
            return EmptyState(
              icon: AppIcons.mailbox,
              title: 'Email not found',
              action: AppButton.primary(
                label: 'Back to queue',
                onPressed: () => context.go(R.adminReview),
              ),
            );
          }
          if (email.wasImported) {
            return _AlreadyHandled(
              email: email,
              title: 'Already imported',
              message: 'This email was turned into a ride.',
              rideId: email.createdRideId,
            );
          }
          if (email.parseStatus == ParseStatus.rejected) {
            return _AlreadyHandled(
              email: email,
              title: 'Rejected',
              message: 'This email was marked as not a booking.',
            );
          }
          return _ReviewForm(email: email);
        },
      ),
    );
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({required this.email});

  final InboundEmail email;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _pickup;
  late final TextEditingController _dropoff;
  late final TextEditingController _fare;
  late final TextEditingController _flight;
  late final TextEditingController _notes;
  DateTime? _pickupAt;
  int _passengers = 1;
  int _luggage = 0;
  VehicleType? _vehicleType;

  @override
  void initState() {
    super.initState();
    final b = widget.email.booking;
    _name = TextEditingController(text: b?.customerName ?? '');
    _phone = TextEditingController(text: b?.customerPhone ?? '');
    _pickup = TextEditingController(text: b?.pickupAddress ?? '');
    _dropoff = TextEditingController(text: b?.dropoffAddress ?? '');
    _fare = TextEditingController(
        text: b?.fareAmount == null ? '' : '${b!.fareAmount}');
    _flight = TextEditingController(text: b?.flightNumber ?? '');
    _notes = TextEditingController(text: b?.notes ?? '');
    _pickupAt = b?.pickupAt;
    _passengers = b?.passengers ?? 1;
    _luggage = b?.luggage ?? 0;
    _vehicleType = b?.vehicleType;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _pickup, _dropoff, _fare, _flight, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  ParsedBooking _collect() => ParsedBooking(
        pickupAt: _pickupAt,
        customerName: _name.text.trim(),
        customerPhone: _phone.text.trim(),
        pickupAddress: _pickup.text.trim(),
        dropoffAddress: _dropoff.text.trim(),
        passengers: _passengers,
        luggage: _luggage,
        fareAmount: num.tryParse(_fare.text.trim()),
        fareCurrency: 'GBP',
        vehicleType: _vehicleType,
        flightNumber: _flight.text.trim().isEmpty ? null : _flight.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );

  Future<void> _import() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickupAt == null) {
      AppSnackbar.show(context,
          message: 'Set a pickup date and time first', tone: SnackTone.warning);
      return;
    }
    final controller = ref.read(reviewControllerProvider.notifier);
    final rideId = await controller.import(
        widget.email.id, _collect().toPayload());
    if (!mounted) return;
    if (rideId != null) {
      AppSnackbar.success(context, 'Ride created from email');
      context.canPop() ? context.pop() : context.go(R.adminReview);
    } else {
      AppSnackbar.showFailure(context, controller.errorOrNull!);
    }
  }

  Future<void> _reject() async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Reject this email?',
      message: 'Mark it as not a booking. It leaves the review queue and no '
          'ride is created.',
      confirmLabel: 'Reject',
      destructive: true,
      icon: AppIcons.close,
    );
    if (ok != true || !mounted) return;
    final controller = ref.read(reviewControllerProvider.notifier);
    final done = await controller.reject(widget.email.id);
    if (!mounted) return;
    if (done) {
      AppSnackbar.success(context, 'Email rejected');
      context.canPop() ? context.pop() : context.go(R.adminReview);
    } else {
      AppSnackbar.showFailure(context, controller.errorOrNull!);
    }
  }

  Future<void> _reparse() async {
    final controller = ref.read(reviewControllerProvider.notifier);
    final done = await controller.reparse(widget.email.id);
    if (!mounted) return;
    if (done) {
      ref.invalidate(reviewEmailProvider(widget.email.id));
      AppSnackbar.success(context, 'Re-parsing — refresh in a moment');
    } else {
      AppSnackbar.showFailure(context, controller.errorOrNull!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(reviewControllerProvider).isLoading;

    return SingleChildScrollView(
      child: MaxWidthBody(
        maxWidth: 720,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AssessmentCard(email: widget.email, busy: busy, onReparse: _reparse),
              const SizedBox(height: AppSpacing.lg),
              _OriginalEmailCard(email: widget.email),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: 'Booking', dense: true),
                    AppDateTimeField(
                      label: 'Pickup date & time',
                      value: _pickupAt,
                      onChanged: busy
                          ? null
                          : (d) => setState(() => _pickupAt = d),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Pickup address',
                      controller: _pickup,
                      required: true,
                      enabled: !busy,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Drop-off address',
                      controller: _dropoff,
                      required: true,
                      enabled: !busy,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Customer name',
                      controller: _name,
                      required: true,
                      textCapitalization: TextCapitalization.words,
                      enabled: !busy,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Customer phone',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      enabled: !busy,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: AppCounterField(
                            label: 'Passengers',
                            value: _passengers,
                            min: 1,
                            onChanged:
                                busy ? null : (v) => setState(() => _passengers = v),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: AppCounterField(
                            label: 'Luggage',
                            value: _luggage,
                            min: 0,
                            onChanged:
                                busy ? null : (v) => setState(() => _luggage = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Fare (£)',
                            controller: _fare,
                            keyboardType: TextInputType.number,
                            enabled: !busy,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: AppTextField(
                            label: 'Flight number',
                            controller: _flight,
                            enabled: !busy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppDropdown<VehicleType>(
                      label: 'Vehicle type',
                      value: _vehicleType,
                      onChanged:
                          busy ? null : (v) => setState(() => _vehicleType = v),
                      items: [
                        for (final t in VehicleType.values)
                          AppDropdownItem(
                              value: t, label: t.label, subtitle: t.description),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Special notes',
                      controller: _notes,
                      maxLines: 3,
                      enabled: !busy,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton.primary(
                label: 'Create ride',
                icon: AppIcons.check,
                size: AppButtonSize.lg,
                fullWidth: true,
                isLoading: busy,
                onPressed: busy ? null : _import,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton.destructive(
                label: 'Reject — not a booking',
                icon: AppIcons.close,
                fullWidth: true,
                onPressed: busy ? null : _reject,
              ),
              const SizedBox(height: AppSpacing.x5),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.email,
    required this.busy,
    required this.onReparse,
  });

  final InboundEmail email;
  final bool busy;
  final VoidCallback onReparse;

  @override
  Widget build(BuildContext context) {
    final color = reviewReasonColor(email.parseError);
    return AppCard(
      backgroundColor: color.withValues(alpha: 0.06),
      borderColor: color.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.info, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  reviewReasonLabel(email.parseError),
                  style: AppTypography.bodyStrong.copyWith(color: color),
                ),
              ),
              if (email.confidence != null)
                Text(
                  '${(email.confidence! * 100).round()}% sure',
                  style: AppTypography.bodySm.copyWith(color: AppColors.inkMuted),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The parser wasn\'t confident enough to create this automatically. '
            'Check the details below and create the ride, or reject it.',
            style: AppTypography.bodySm.copyWith(color: AppColors.inkBody),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Re-run parser',
            icon: AppIcons.refresh,
            size: AppButtonSize.sm,
            onPressed: busy ? null : onReparse,
          ),
        ],
      ),
    );
  }
}

class _OriginalEmailCard extends StatelessWidget {
  const _OriginalEmailCard({required this.email});

  final InboundEmail email;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Original email', dense: true),
          _line('From', email.fromAddress ?? 'unknown'),
          _line('Subject', email.subject ?? '(no subject)'),
          if (email.mailboxAddress != null) _line('Mailbox', email.mailboxAddress!),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: Text(
                email.bodyText?.trim().isNotEmpty == true
                    ? email.bodyText!
                    : '(no body text)',
                style: AppTypography.bodySm.copyWith(color: AppColors.inkBody),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 68,
              child: Text(label,
                  style: AppTypography.caption.copyWith(color: AppColors.inkFaint)),
            ),
            Expanded(
              child: Text(value, style: AppTypography.bodySm),
            ),
          ],
        ),
      );
}

class _AlreadyHandled extends StatelessWidget {
  const _AlreadyHandled({
    required this.email,
    required this.title,
    required this.message,
    this.rideId,
  });

  final InboundEmail email;
  final String title;
  final String message;
  final String? rideId;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: rideId != null ? AppIcons.success : AppIcons.info,
      title: title,
      message: message,
      tone: rideId != null ? EmptyStateTone.positive : EmptyStateTone.neutral,
      action: rideId != null
          ? AppButton.primary(
              label: 'View ride',
              onPressed: () => context.go(R.adminRide(rideId!)),
            )
          : AppButton.primary(
              label: 'Back to queue',
              onPressed: () => context.go(R.adminReview),
            ),
    );
  }
}
