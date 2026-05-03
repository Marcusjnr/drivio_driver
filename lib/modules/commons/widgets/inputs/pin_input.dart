import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_radius.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class PinInput extends ConsumerStatefulWidget {
  const PinInput({
    super.key,
    this.length = 6,
    this.initial,
    this.onChanged,
    this.autofocus = true,
  });

  final int length;
  final String? initial;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  ConsumerState<PinInput> createState() => _PinInputState();
}

class _PinInputState extends ConsumerState<PinInput> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial ?? '');
    _focus = FocusNode();
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(PinInput old) {
    super.didUpdateWidget(old);
    if (widget.initial != null && widget.initial != _ctrl.text && !_focus.hasFocus) {
      _ctrl.text = widget.initial!;
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
    widget.onChanged?.call(_ctrl.text);
  }

  void _focusInput() {
    if (!_focus.hasFocus) {
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String value = _ctrl.text;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              showCursor: false,
            ),
          ),
        ),
        GestureDetector(
          onTap: _focusInput,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: List<Widget>.generate(widget.length, (int i) {
              final bool filled = i < value.length;
              final bool active = i == value.length && _focus.hasFocus;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == widget.length - 1 ? 0 : 10),
                  child: AspectRatio(
                    aspectRatio: 1 / 1.1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: AppRadius.md,
                        border: Border.all(
                          color: filled || active
                              ? context.accent
                              : context.borderStrong,
                          width: filled || active ? 1.5 : 1.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        filled ? value[i] : (active ? '|' : '—'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: filled
                              ? context.text
                              : active
                                  ? context.accent
                                  : context.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
