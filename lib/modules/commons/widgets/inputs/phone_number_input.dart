import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_text_styles.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

/// Phone number input — same outlined-floating-label shell as
/// `DrivioInput`, with a 🇳🇬 + +234 prefix block per SCR-003 / SCR-004.
///
/// Defaults to Nigeria. Other countries deferred — Drivio is pan-African
/// by design (brand §3.4) but v1 ships Nigeria-only.
class PhoneNumberInput extends ConsumerStatefulWidget {
  const PhoneNumberInput({
    super.key,
    this.controller,
    this.onChanged,
    this.flag = '🇳🇬',
    this.dialCode = '+234',
    this.label = 'Phone',
    this.hint = '801 234 5678',
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String flag;
  final String dialCode;
  final String label;
  final String hint;
  final bool autofocus;

  @override
  ConsumerState<PhoneNumberInput> createState() => _PhoneNumberInputState();
}

class _PhoneNumberInputState extends ConsumerState<PhoneNumberInput> {
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

    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.phone,
      onChanged: widget.onChanged,
      cursorColor: context.coral,
      cursorWidth: 1.6,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      style: AppTextStyles.body.copyWith(
        color: context.text,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: AppTextStyles.bodySm.copyWith(color: labelColor),
        floatingLabelStyle: AppTextStyles.bodySm.copyWith(color: labelColor),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: widget.hint,
        hintStyle: AppTextStyles.body.copyWith(color: context.textMuted),
        filled: true,
        fillColor: context.surface,
        contentPadding: const EdgeInsets.fromLTRB(0, 26, 16, 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(widget.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                widget.dialCode,
                style: AppTextStyles.body.copyWith(
                  color: context.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        border: enabled,
        enabledBorder: enabled,
        focusedBorder: focused,
      ),
    );
  }
}
