import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_text_styles.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

/// Drivio text input — Material-3 floating-label outlined style, tuned
/// to the Coastal Pulse palette and the SCR-003 / SCR-004 mockups.
///
/// Resting state: ivory-light fill, hairline charcoal-teal border, label
/// floating top-left in textDim. Focused state: 1.5px coral border,
/// label tint coral. The label *always* floats — no overlay-on-empty
/// pattern — matching the mockup composition where every field reads
/// the same whether typing or not.
class DrivioInput extends ConsumerStatefulWidget {
  const DrivioInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.suffix,
    this.maxLines = 1,
    this.compact = false,
    this.autofocus = false,
    this.errorText,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final int maxLines;
  final bool compact;
  final bool autofocus;
  final String? errorText;

  @override
  ConsumerState<DrivioInput> createState() => _DrivioInputState();
}

class _DrivioInputState extends ConsumerState<DrivioInput> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Repaint when focus changes so the border/label colors animate
    // through the InputDecorator's own state.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor = context.borderStrong;
    final Color focusColor = context.coral;
    final Color labelColor = _focus.hasFocus ? context.coral : context.textDim;

    final OutlineInputBorder enabled = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor, width: 1),
    );
    final OutlineInputBorder focused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: focusColor, width: 1.5),
    );
    final OutlineInputBorder errored = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: context.red, width: 1.5),
    );

    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      obscureText: widget.obscure,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      autofocus: widget.autofocus,
      cursorColor: context.coral,
      cursorWidth: 1.6,
      style: AppTextStyles.body.copyWith(color: context.text),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: AppTextStyles.bodySm.copyWith(color: labelColor),
        floatingLabelStyle: AppTextStyles.bodySm.copyWith(color: labelColor),
        // Always-float — the mockup shows the label permanently in the
        // top-left of every field, whether the field is filled or not.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: widget.hint,
        hintStyle: AppTextStyles.body.copyWith(color: context.textMuted),
        filled: true,
        fillColor: context.surface,
        contentPadding: EdgeInsets.fromLTRB(
          16,
          widget.compact ? 22 : 26,
          16,
          widget.compact ? 12 : 14,
        ),
        suffixIcon: widget.suffix,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
        border: enabled,
        enabledBorder: enabled,
        focusedBorder: focused,
        errorBorder: errored,
        focusedErrorBorder: errored,
        errorText: widget.errorText,
        errorStyle: AppTextStyles.captionSm.copyWith(color: context.red),
      ),
    );
  }
}
