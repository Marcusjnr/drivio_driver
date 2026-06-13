import 'package:flutter/material.dart';

import 'package:drivio_driver/modules/commons/all.dart';

/// One-time rationale shown after the driver first goes online without
/// "Allow all the time" location. Android can't prompt for background
/// location in-app, so this routes the driver to Settings. Dismissible —
/// going online still works without it.
class AlwaysLocationNudgeSheet extends StatelessWidget {
  const AlwaysLocationNudgeSheet({
    super.key,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  /// Deep-link to the app's settings page.
  final VoidCallback onOpenSettings;

  /// Driver tapped the scrim or "Not now". They stay online; tracking
  /// continues while the app is backgrounded, just without reboot-resume.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GestureDetector(
          onTap: onDismiss,
          child: Container(color: Colors.black.withValues(alpha: 0.55)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: BottomSheetCard(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: context.coral.withValues(alpha: 0.16),
                    border: Border.all(
                      color: context.coral.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🛰️', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(height: 14),
                const Pill(
                  text: 'STAY ONLINE IN BACKGROUND',
                  tone: PillTone.accent,
                ),
                const SizedBox(height: 10),
                Text(
                  'Keep location on\nall the time.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1.copyWith(color: context.text),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 290,
                  child: Text(
                    "Android only lets you choose this in Settings. Set "
                    "Location to “Allow all the time” so Drivio can "
                    'keep you online even after your phone restarts.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: context.textDim,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                DrivioButton(
                  label: 'Open location settings',
                  onPressed: onOpenSettings,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    'Not now',
                    style: TextStyle(color: context.textDim, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
