import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/app_dimensions.dart';
import 'package:drivio_driver/modules/commons/theme/app_radius.dart';
import 'package:drivio_driver/modules/commons/theme/app_text_styles.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

enum DrivioButtonVariant { accent, primary, ghost, danger }

class DrivioButton extends ConsumerWidget {
  const DrivioButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = DrivioButtonVariant.accent,
    this.icon,
    this.disabled = false,
    this.loading = false,
    this.height = AppDimensions.buttonHeight,
    this.width = double.infinity,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DrivioButtonVariant variant;
  final IconData? icon;
  final bool disabled;

  /// Shows a centred spinner in place of the label and blocks taps.
  /// Also auto-detected when [label] ends with an ellipsis (the app's
  /// "Saving…" / "Going online…" loading-label convention) so callers
  /// get a spinner instead of changing text without any extra wiring.
  final bool loading;
  final double height;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _ButtonStyle style = _resolveStyle(context);
    final String trimmed = label.trimRight();
    final bool busy =
        loading || trimmed.endsWith('…') || trimmed.endsWith('...');
    final bool disabledByCaller = disabled || onPressed == null;
    return Opacity(
      // A busy button stays full-opacity (the spinner reads as active);
      // only a caller-disabled, non-busy button dims.
      opacity: disabledByCaller && !busy ? 0.55 : 1,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: style.bg,
          borderRadius: AppRadius.md,
          child: InkWell(
            borderRadius: AppRadius.md,
            onTap: disabledByCaller || busy ? null : onPressed,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.md,
                border: style.border,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact
                    ? AppDimensions.space14
                    : AppDimensions.space16,
              ),
              alignment: Alignment.center,
              child: busy
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(style.fg),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (icon != null) ...<Widget>[
                          Icon(icon, size: 18, color: style.fg),
                          const SizedBox(width: AppDimensions.space8),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.button.copyWith(
                              color: style.fg,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  _ButtonStyle _resolveStyle(BuildContext context) {
    switch (variant) {
      case DrivioButtonVariant.accent:
        return _ButtonStyle(bg: context.accent, fg: context.accentInk);
      case DrivioButtonVariant.primary:
        return _ButtonStyle(bg: context.blue, fg: context.blueInk);
      case DrivioButtonVariant.ghost:
        return _ButtonStyle(
          bg: context.surface2,
          fg: context.text,
          border: Border.all(color: context.border),
        );
      case DrivioButtonVariant.danger:
        return _ButtonStyle(
          bg: context.red.withValues(alpha: 0.16),
          fg: context.red,
          border: Border.all(color: context.red.withValues(alpha: 0.3)),
        );
    }
  }
}

class _ButtonStyle {
  _ButtonStyle({required this.bg, required this.fg, this.border});
  final Color bg;
  final Color fg;
  final BoxBorder? border;
}
