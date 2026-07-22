import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_durations.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';

/// Debounced search input with a clear affordance.
///
/// Debouncing lives here rather than in each provider, so no screen can
/// accidentally fire a PostgREST query per keystroke across a shared ride
/// pool.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
    this.initialValue,
    this.debounce = AppDurations.searchDebounce,
    this.autofocus = false,
    this.width,
  });

  /// Called with the settled query, and immediately with '' when cleared.
  final ValueChanged<String> onChanged;

  final String hint;
  final String? initialValue;
  final Duration debounce;
  final bool autofocus;
  final double? width;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    setState(() {}); // refresh the clear button's visibility
    _debounceTimer = Timer(widget.debounce, () => widget.onChanged(value));
  }

  void _clear() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() {});
    // Clearing is deliberate and instant — no debounce.
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;

    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        style: AppTypography.body.copyWith(color: AppColors.ink),
        cursorColor: AppColors.brass,
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.sm,
            ),
            child: Icon(AppIcons.search, size: 18),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(AppIcons.close, size: 16),
                  onPressed: _clear,
                  tooltip: 'Clear search',
                  splashRadius: 18,
                )
              : null,
        ),
      ),
    );
  }
}
