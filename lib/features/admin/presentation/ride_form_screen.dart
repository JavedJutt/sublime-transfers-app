import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/ride_repository.dart';
import '../../../providers/ride_providers.dart';
import '../../../shared/widgets/async/async_value_view.dart';
import '../../../shared/widgets/buttons/app_button.dart';
import '../../../shared/widgets/display/app_card.dart';
import '../../../shared/widgets/display/section_header.dart';
import '../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../shared/widgets/feedback/inline_banner.dart';
import '../../../shared/widgets/inputs/app_counter_field.dart';
import '../../../shared/widgets/inputs/app_date_time_field.dart';
import '../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../shared/widgets/inputs/app_text_field.dart';
import '../../../shared/widgets/layout/max_width_body.dart';
import '../controllers/ride_form_controller.dart';

/// Create or edit a ride — the same field set as auto-parsed rides (§2.2), and
/// on save the ride flows into the same assignment pipeline. When [rideId] is
/// set, the form loads that ride and edits it.
class RideFormScreen extends ConsumerWidget {
  const RideFormScreen({super.key, this.rideId});

  final String? rideId;

  bool get isEditing => rideId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isEditing) {
      return const _FormScaffold(title: 'New ride', child: _RideForm());
    }
    // Editing: load the ride first so the fields are pre-filled.
    final rideAsync = ref.watch(rideDetailProvider(rideId!));
    return _FormScaffold(
      title: 'Edit ride',
      child: AsyncValueView(
        value: rideAsync,
        onRetry: () => ref.invalidate(rideDetailProvider(rideId!)),
        data: (ride) => _RideForm(
          rideId: rideId,
          initial: rideToInput(ride),
        ),
      ),
    );
  }
}

class _FormScaffold extends StatelessWidget {
  const _FormScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(AppIcons.close),
          onPressed: () => context.canPop() ? context.pop() : context.go(R.adminCalendar),
        ),
      ),
      body: SingleChildScrollView(child: MaxWidthBody(maxWidth: 720, child: child)),
    );
  }
}

class _RideForm extends ConsumerStatefulWidget {
  const _RideForm({this.rideId, this.initial});

  final String? rideId;
  final RideInput? initial;

  @override
  ConsumerState<_RideForm> createState() => _RideFormState();
}

class _RideFormState extends ConsumerState<_RideForm> {
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
  bool _pickupError = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.customerName ?? '');
    _phone = TextEditingController(text: i?.customerPhone ?? '');
    _pickup = TextEditingController(text: i?.pickupAddress ?? '');
    _dropoff = TextEditingController(text: i?.dropoffAddress ?? '');
    _fare = TextEditingController(
        text: i?.fareAmount == null ? '' : '${i!.fareAmount}');
    _flight = TextEditingController(text: i?.flightNumber ?? '');
    _notes = TextEditingController(text: i?.notes ?? '');
    _pickupAt = i?.pickupAt;
    _passengers = i?.passengers ?? 1;
    _luggage = i?.luggage ?? 0;
    _vehicleType = i?.vehicleType;
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _pickup, _dropoff, _fare, _flight, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  RideInput _build() => RideInput(
        pickupAt: _pickupAt!,
        customerName: _name.text,
        customerPhone: _phone.text.trim().isEmpty ? null : _phone.text,
        pickupAddress: _pickup.text,
        dropoffAddress: _dropoff.text,
        passengers: _passengers,
        luggage: _luggage,
        fareAmount: num.tryParse(_fare.text.trim()),
        vehicleType: _vehicleType,
        flightNumber: _flight.text,
        notes: _notes.text,
        // Preserve any coordinates the original had; geocoding is a later add.
        pickupLat: widget.initial?.pickupLat,
        pickupLng: widget.initial?.pickupLng,
        dropoffLat: widget.initial?.dropoffLat,
        dropoffLng: widget.initial?.dropoffLng,
      );

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    final dateOk = _pickupAt != null;
    setState(() => _pickupError = !dateOk);
    if (!formOk || !dateOk) return;

    FocusScope.of(context).unfocus();
    final controller = ref.read(rideFormControllerProvider.notifier);
    final input = _build();
    final id = widget.rideId == null
        ? await controller.submitCreate(input)
        : await controller.submitUpdate(widget.rideId!, input);

    if (!mounted) return;
    if (id != null) {
      AppSnackbar.success(
          context, widget.rideId == null ? 'Ride created' : 'Ride updated');
      context.go(R.adminRide(id));
    } else {
      final err = controller.errorOrNull;
      if (err != null) AppSnackbar.showFailure(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rideFormControllerProvider);
    final saving = state.isLoading;
    final failure = state.hasError
        ? ref.read(rideFormControllerProvider.notifier).errorOrNull
        : null;
    final fieldErrors =
        failure is ValidationFailure ? failure.fieldErrors : const <String, String>{};

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null && failure is! ValidationFailure) ...[
            InlineBanner.error(message: failure.message),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Pickup', dense: true),
                AppDateTimeField(
                  label: 'Pickup date & time',
                  required: true,
                  value: _pickupAt,
                  errorText: _pickupError ? 'Choose a pickup date and time' : null,
                  onChanged: (d) => setState(() {
                    _pickupAt = d;
                    _pickupError = false;
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Pickup address',
                  controller: _pickup,
                  required: true,
                  prefixIcon: AppIcons.pickup,
                  validator: (v) => Validators.required(v, field: 'Pickup address'),
                  enabled: !saving,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Drop-off address',
                  controller: _dropoff,
                  required: true,
                  prefixIcon: AppIcons.dropoff,
                  validator: (v) => Validators.required(v, field: 'Drop-off address'),
                  enabled: !saving,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Customer', dense: true),
                AppTextField(
                  label: 'Customer name',
                  controller: _name,
                  required: true,
                  textCapitalization: TextCapitalization.words,
                  prefixIcon: AppIcons.customer,
                  validator: Validators.name,
                  errorText: fieldErrors['customer_name'],
                  enabled: !saving,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Customer phone',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  prefixIcon: AppIcons.phone,
                  helper: 'Optional. The driver calls this on arrival.',
                  enabled: !saving,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(title: 'Details', dense: true),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppCounterField(
                        label: 'Passengers',
                        icon: AppIcons.passengers,
                        value: _passengers,
                        min: 1,
                        max: 60,
                        onChanged: saving ? null : (v) => setState(() => _passengers = v),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppCounterField(
                        label: 'Luggage',
                        icon: AppIcons.luggage,
                        value: _luggage,
                        max: 60,
                        onChanged: saving ? null : (v) => setState(() => _luggage = v),
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
                        label: 'Fare',
                        controller: _fare,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        prefixIcon: AppIcons.fare,
                        enabled: !saving,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: AppTextField(
                        label: 'Flight number',
                        controller: _flight,
                        textCapitalization: TextCapitalization.characters,
                        prefixIcon: AppIcons.flight,
                        enabled: !saving,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppDropdown<VehicleType>(
                  label: 'Vehicle type',
                  value: _vehicleType,
                  hint: 'Any vehicle',
                  prefixIcon: AppIcons.vehicle,
                  onChanged: saving ? null : (v) => setState(() => _vehicleType = v),
                  items: [
                    for (final t in VehicleType.values)
                      AppDropdownItem(value: t, label: t.label, subtitle: t.description),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Special notes',
                  controller: _notes,
                  hint: 'Child seat, meet & greet, accessibility…',
                  maxLines: 4,
                  minLines: 2,
                  maxLength: 500,
                  enabled: !saving,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  size: AppButtonSize.lg,
                  onPressed: saving ? null : () => context.pop(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: AppButton.primary(
                  label: widget.rideId == null ? 'Create ride' : 'Save changes',
                  size: AppButtonSize.lg,
                  isLoading: saving,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x5),
        ],
      ),
    );
  }
}
