import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_breakpoints.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_icons.dart';
import '../../core/design/app_spacing.dart';
import '../../core/design/app_typography.dart';
import '../../core/error/app_exception.dart';
import '../../shared/widgets/async/async_value_view.dart';
import '../../shared/widgets/buttons/app_button.dart';
import '../../shared/widgets/display/app_avatar.dart';
import '../../shared/widgets/display/app_card.dart';
import '../../shared/widgets/display/app_chip.dart';
import '../../shared/widgets/display/key_value_row.dart';
import '../../shared/widgets/display/section_header.dart';
import '../../shared/widgets/display/stat_callout.dart';
import '../../shared/widgets/display/status_chip.dart';
import '../../shared/widgets/feedback/empty_state.dart';
import '../../shared/widgets/feedback/error_state.dart';
import '../../shared/widgets/feedback/loading_view.dart';
import '../../shared/widgets/feedback/skeleton_box.dart';
import '../../shared/widgets/inputs/app_counter_field.dart';
import '../../shared/widgets/inputs/app_dropdown.dart';
import '../../shared/widgets/inputs/app_text_field.dart';
import '../../shared/widgets/layout/max_width_body.dart';

/// Renders every design-system component in every state.
///
/// This is the verification surface for the design system: if a variant or a
/// state isn't visible here, it hasn't been built. Debug builds only — it is
/// never routed in release.
class ComponentGalleryScreen extends ConsumerStatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  ConsumerState<ComponentGalleryScreen> createState() =>
      _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState
    extends ConsumerState<ComponentGalleryScreen> {
  final _textController = TextEditingController(text: 'Amelia Hart');
  final _notesController = TextEditingController();
  int _passengers = 2;
  int _luggage = 3;
  String? _vehicle = 'executive';
  final Set<String> _selectedFilters = {'unassigned'};

  @override
  void dispose() {
    _textController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formFactor = AppBreakpoints.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design system'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.line),
        ),
      ),
      body: SingleChildScrollView(
        child: MaxWidthBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sublime Transfers',
                style: AppTypography.display2,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Every component, every state. Currently rendering at '
                '${formFactor.name} width.',
                style: AppTypography.body.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.x4),
              ..._sections(formFactor),
              const SizedBox(height: AppSpacing.x6),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(FormFactor formFactor) => [
        _GallerySection(
          eyebrow: 'Foundation',
          title: 'Type scale',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Display 1 — 44/600', style: AppTypography.display1),
              const SizedBox(height: AppSpacing.sm),
              Text('Display 2 — 34/600', style: AppTypography.display2),
              const SizedBox(height: AppSpacing.sm),
              Text('Heading 1 — 27/600', style: AppTypography.h1),
              const SizedBox(height: AppSpacing.sm),
              Text('Heading 2 — 21/600', style: AppTypography.h2),
              const SizedBox(height: AppSpacing.sm),
              Text('Heading 3 — 17/600', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.md),
              Text('EYEBROW — 12/700 +0.10em', style: AppTypography.eyebrow),
              const SizedBox(height: AppSpacing.sm),
              Text('Body large — 17/400, driver-facing', style: AppTypography.bodyLg),
              const SizedBox(height: AppSpacing.xs),
              Text('Body — 15/400, the default', style: AppTypography.body),
              const SizedBox(height: AppSpacing.xs),
              Text('Body strong — 15/600, field values', style: AppTypography.bodyStrong),
              const SizedBox(height: AppSpacing.xs),
              Text('Body small — 13/400, meta and timestamps', style: AppTypography.bodySm),
              const SizedBox(height: AppSpacing.xs),
              Text('Caption — 12/400, helper text', style: AppTypography.caption),
              const SizedBox(height: AppSpacing.md),
              Text('ST-4F9A21C0 · BA2551 · 51.4700, -0.4543', style: AppTypography.mono),
              const SizedBox(height: AppSpacing.md),
              Text('247', style: AppTypography.numeric),
            ],
          ),
        ),
        const _GallerySection(
          eyebrow: 'Foundation',
          title: 'Palette',
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _Swatch('canvas', AppColors.canvas),
              _Swatch('surface', AppColors.surface),
              _Swatch('surfaceSunk', AppColors.surfaceSunk),
              _Swatch('line', AppColors.line),
              _Swatch('ink', AppColors.ink, dark: true),
              _Swatch('inkBody', AppColors.inkBody, dark: true),
              _Swatch('inkMuted', AppColors.inkMuted, dark: true),
              _Swatch('brass', AppColors.brass, dark: true),
              _Swatch('brassTint', AppColors.brassTint),
              _Swatch('success', AppColors.success, dark: true),
              _Swatch('warning', AppColors.warning, dark: true),
              _Swatch('danger', AppColors.danger, dark: true),
              _Swatch('info', AppColors.info, dark: true),
            ],
          ),
        ),
        _GallerySection(
          eyebrow: 'Components',
          title: 'Buttons',
          subtitle: 'Five variants, four sizes, plus loading and disabled.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppButton.primary(label: 'Assign ride', onPressed: () {}),
                  AppButton(label: 'Secondary', onPressed: () {}),
                  AppButton.ghost(label: 'Cancel', onPressed: () {}),
                  AppButton.destructive(label: 'Cancel ride', onPressed: () {}),
                  AppButton(
                    label: 'Claim',
                    variant: AppButtonVariant.accentQuiet,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  AppButton.primary(
                    label: 'Small',
                    size: AppButtonSize.sm,
                    onPressed: () {},
                  ),
                  AppButton.primary(
                    label: 'Medium',
                    onPressed: () {},
                  ),
                  AppButton.primary(
                    label: 'Large',
                    size: AppButtonSize.lg,
                    onPressed: () {},
                  ),
                  AppButton.primary(
                    label: 'Extra large',
                    size: AppButtonSize.xl,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppButton.primary(
                    label: 'With icon',
                    icon: AppIcons.assignDirect,
                    onPressed: () {},
                  ),
                  const AppButton(label: 'Disabled', onPressed: null),
                  AppButton.primary(
                    label: 'Saving',
                    isLoading: true,
                    onPressed: () {},
                  ),
                  AppButton(
                    label: 'Trailing',
                    trailingIcon: AppIcons.arrowRight,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton.primary(
                label: 'Full width — driver primary action',
                size: AppButtonSize.xl,
                fullWidth: true,
                onPressed: () {},
              ),
            ],
          ),
        ),
        const _GallerySection(
          eyebrow: 'Components',
          title: 'Status chips',
          subtitle: 'The only sanctioned use of semantic colour.',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusChip(label: 'Unassigned', tone: StatusTone.urgent),
              StatusChip(label: 'Offered', tone: StatusTone.pending),
              StatusChip(label: 'Assigned', tone: StatusTone.scheduled),
              StatusChip(label: 'En route', tone: StatusTone.active, pulse: true),
              StatusChip(label: 'Arrived', tone: StatusTone.active, pulse: true),
              StatusChip(label: 'In progress', tone: StatusTone.active, pulse: true),
              StatusChip(label: 'Completed', tone: StatusTone.complete),
              StatusChip(label: 'Cancelled', tone: StatusTone.dormant),
              StatusChip(label: 'Dense', tone: StatusTone.scheduled, dense: true),
            ],
          ),
        ),
        _GallerySection(
          eyebrow: 'Components',
          title: 'Filter chips',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (id, label, count) in const [
                ('unassigned', 'Unassigned', 4),
                ('assigned', 'Assigned', 12),
                ('in_progress', 'In progress', 3),
                ('completed', 'Completed', 28),
              ])
                AppChip(
                  label: label,
                  count: count,
                  selected: _selectedFilters.contains(id),
                  onTap: () => setState(() {
                    _selectedFilters.contains(id)
                        ? _selectedFilters.remove(id)
                        : _selectedFilters.add(id);
                  }),
                ),
              AppChip(
                label: 'Marcus Bell',
                leading: const AppAvatar(
                  name: 'Marcus Bell',
                  size: AppAvatarSize.sm,
                ),
                selected: true,
                onRemove: () {},
              ),
            ],
          ),
        ),
        _GallerySection(
          eyebrow: 'Components',
          title: 'Stat callouts',
          subtitle: 'The admin dashboard\'s icon + short-copy feature row.',
          child: _Grid(
            columns: AppBreakpoints.gridColumns(formFactor),
            children: [
              const StatCallout(
                icon: AppIcons.ride,
                value: '18',
                label: 'Rides today',
                caption: '3 in the next hour',
              ),
              const StatCallout(
                icon: AppIcons.warning,
                value: '4',
                label: 'Unassigned',
                caption: 'Earliest at 14:20',
                tone: StatusTone.urgent,
              ),
              const StatCallout(
                icon: AppIcons.drivers,
                value: '7',
                label: 'Drivers on duty',
                tone: StatusTone.complete,
              ),
              const StatCallout(
                icon: AppIcons.ride,
                value: '—',
                label: 'Loading',
                isLoading: true,
              ),
            ],
          ),
        ),
        _GallerySection(
          eyebrow: 'Components',
          title: 'Cards',
          child: Column(
            children: [
              AppCard(
                onTap: () {},
                accentEdge: AppColors.danger,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('14:20 · Heathrow T5 → Mayfair',
                              style: AppTypography.h3),
                        ),
                        const StatusChip(
                          label: 'Unassigned',
                          tone: StatusTone.urgent,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Amelia Hart · 2 passengers · 3 bags · BA2551',
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                selected: true,
                onTap: () {},
                child: Text('Selected card', style: AppTypography.body),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                elevated: true,
                child: Text('Elevated card', style: AppTypography.body),
              ),
            ],
          ),
        ),
        _GallerySection(
          eyebrow: 'Components',
          title: 'Avatars',
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const AppAvatar(name: 'Marcus Bell', size: AppAvatarSize.sm),
              const AppAvatar(name: 'Priya Raman'),
              const AppAvatar(name: 'Tom O\'Neill', size: AppAvatarSize.lg),
              const AppAvatar(name: 'Unknown', size: AppAvatarSize.xl),
              AppAvatar(
                name: 'On duty',
                size: AppAvatarSize.lg,
                badge: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        _GallerySection(
          eyebrow: 'Components',
          title: 'Form fields',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: 'Customer name',
                controller: _textController,
                required: true,
                prefixIcon: AppIcons.customer,
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppTextField(
                label: 'Customer phone',
                hint: '+44 7700 900000',
                helper: 'Used by the driver on arrival.',
                prefixIcon: AppIcons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppTextField(
                label: 'Pickup address',
                initialValue: 'Terminal 5',
                errorText: 'Add a more specific pickup point.',
                prefixIcon: AppIcons.pickup,
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppTextField(
                label: 'Read-only field',
                initialValue: 'ST-4F9A21C0',
                enabled: false,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Special notes',
                controller: _notesController,
                hint: 'Child seat, meet-and-greet, accessibility needs…',
                maxLines: 4,
                minLines: 3,
                maxLength: 400,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppDropdown<String>(
                label: 'Vehicle type',
                value: _vehicle,
                hint: 'Any vehicle',
                prefixIcon: AppIcons.vehicle,
                onChanged: (v) => setState(() => _vehicle = v),
                items: const [
                  AppDropdownItem(value: 'sedan', label: 'Sedan', subtitle: 'Up to 3 passengers'),
                  AppDropdownItem(value: 'estate', label: 'Estate', subtitle: 'Extra luggage'),
                  AppDropdownItem(value: 'mpv', label: 'MPV', subtitle: 'Up to 6 passengers'),
                  AppDropdownItem(value: 'executive', label: 'Executive', subtitle: 'Premium saloon'),
                  AppDropdownItem(
                    value: 'minibus',
                    label: 'Minibus',
                    subtitle: 'Unavailable today',
                    enabled: false,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppDropdown<String>(
                label: 'Assign driver',
                value: null,
                items: [],
                onChanged: null,
                isLoading: true,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppCounterField(
                      label: 'Passengers',
                      icon: AppIcons.passengers,
                      value: _passengers,
                      min: 1,
                      max: 16,
                      onChanged: (v) => setState(() => _passengers = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: AppCounterField(
                      label: 'Luggage',
                      icon: AppIcons.luggage,
                      value: _luggage,
                      onChanged: (v) => setState(() => _luggage = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const _GallerySection(
          eyebrow: 'Components',
          title: 'Key/value rows',
          child: AppCard(
            child: Column(
              children: [
                KeyValueRow(
                  label: 'Pickup',
                  value: 'Heathrow Terminal 5, Arrivals',
                  icon: AppIcons.pickup,
                  emphasise: true,
                ),
                Divider(),
                KeyValueRow(
                  label: 'Flight',
                  value: 'BA2551',
                  icon: AppIcons.flight,
                  monospace: true,
                ),
                Divider(),
                KeyValueRow(
                  label: 'Customer phone',
                  value: null,
                  icon: AppIcons.phone,
                ),
              ],
            ),
          ),
        ),
        _GallerySection(
          eyebrow: 'States',
          title: 'Loading',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 140,
                child: LoadingView(label: 'Restoring your session'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Skeleton(
                child: Column(
                  children: [
                    for (var i = 0; i < 2; i++) ...[
                      const AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox.circle(size: 40),
                            SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonBox.line(width: 200, height: 16),
                                  SizedBox(height: AppSpacing.sm),
                                  SkeletonBox.line(width: 280),
                                  SizedBox(height: AppSpacing.xs),
                                  SkeletonBox.line(width: 140),
                                ],
                              ),
                            ),
                            SkeletonBox(width: 84, height: 24),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        _GallerySection(
          eyebrow: 'States',
          title: 'Empty',
          child: Column(
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: EmptyState(
                  icon: AppIcons.calendar,
                  title: 'No rides on 12 March',
                  message: 'Nothing is scheduled for this day yet.',
                  action: AppButton.primary(
                    label: 'Create ride',
                    icon: AppIcons.add,
                    onPressed: () {},
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: EmptyState(
                  icon: AppIcons.filter,
                  title: 'No rides match these filters',
                  message: 'Try widening the date range or clearing a filter.',
                  compact: true,
                  action: AppButton.ghost(
                    label: 'Clear filters',
                    size: AppButtonSize.sm,
                    onPressed: () {},
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const AppCard(
                padding: EdgeInsets.zero,
                child: EmptyState(
                  icon: AppIcons.approve,
                  title: 'No pending approvals',
                  message: 'Every driver who applied has been reviewed.',
                  tone: EmptyStateTone.positive,
                  compact: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: EmptyState(
                  icon: AppIcons.mailbox,
                  title: 'No mailbox connected',
                  message: 'Connect your Gmail account to start importing '
                      'booking emails automatically.',
                  tone: EmptyStateTone.accent,
                  action: AppButton.primary(
                    label: 'Connect Gmail',
                    icon: AppIcons.mailbox,
                    onPressed: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
        _GallerySection(
          eyebrow: 'States',
          title: 'Error',
          subtitle: 'Retry is offered only where retrying can help.',
          child: Column(
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: ErrorState(
                  error: const NetworkFailure(),
                  onRetry: () {},
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const AppCard(
                padding: EdgeInsets.zero,
                child: ErrorState(
                  error: NetworkFailure(
                    message: 'Showing rides synced at 14:02.',
                    isOffline: true,
                  ),
                  compact: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: ErrorState(
                  error: const DevicePermissionFailure(
                    message: 'Location is required to update ride status so '
                        'dispatch can keep the customer informed.',
                    permanentlyDenied: true,
                  ),
                  compact: true,
                  action: AppButton.primary(
                    label: 'Open settings',
                    size: AppButtonSize.sm,
                    onPressed: () {},
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const AppCard(
                padding: EdgeInsets.zero,
                child: ErrorState(
                  error: ConflictFailure(
                    message: 'That ride was taken by another driver.',
                    kind: ConflictKind.rideAlreadyClaimed,
                  ),
                  compact: true,
                ),
              ),
            ],
          ),
        ),
        _GallerySection(
          eyebrow: 'States',
          title: 'AsyncValueView',
          subtitle: 'The widget that makes loading/empty/error structural.',
          child: Column(
            children: [
              for (final (label, value) in <(String, AsyncValue<List<String>>)>[
                ('Loading', const AsyncValue.loading()),
                ('Data', const AsyncValue.data(['One ride'])),
                ('Empty', const AsyncValue.data([])),
                (
                  'Error',
                  const AsyncValue.error(NetworkFailure(), StackTrace.empty)
                ),
              ]) ...[
                Text(label, style: AppTypography.eyebrow),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    height: 190,
                    child: AsyncCollectionView<String>(
                      value: value,
                      compact: true,
                      onRetry: () {},
                      empty: () => const EmptyState(
                        icon: AppIcons.empty,
                        title: 'Nothing here',
                        message: 'This is the empty state.',
                        compact: true,
                      ),
                      data: (items) => Center(
                        child: Text(items.first, style: AppTypography.h3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ];
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({
    required this.eyebrow,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(eyebrow: eyebrow, title: title, subtitle: subtitle),
          child,
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color, {this.dark = false});

  final String name;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 104,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.brMd,
            border: Border.all(color: AppColors.line),
          ),
          child: Center(
            child: Text(
              'Aa',
              style: AppTypography.bodyStrong.copyWith(
                color: dark ? AppColors.inkInverse : AppColors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(name, style: AppTypography.caption),
      ],
    );
  }
}

/// Simple responsive grid for the gallery. Feature screens use their own
/// layout; this exists so the stat row can be shown at every column count.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = AppSpacing.lg;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: width.clamp(200, double.infinity), child: child),
          ],
        );
      },
    );
  }
}
