import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_radius.dart';
import 'package:drivio_driver/modules/commons/theme/app_text_styles.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class PhoneNumberInput extends ConsumerWidget {
  const PhoneNumberInput({
    super.key,
    this.controller,
    this.onChanged,
    this.flag = '🇳🇬',
    this.dialCode = '+234',
    this.hint = '801 234 5678',
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String flag;
  final String dialCode;
  final String hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.borderStrong),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  dialCode,
                  style: AppTextStyles.body.copyWith(
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 24, color: context.border),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              onChanged: onChanged,
              cursorColor: context.accent,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: AppTextStyles.body.copyWith(color: context.text),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: hint,
                hintStyle: AppTextStyles.body.copyWith(color: context.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
