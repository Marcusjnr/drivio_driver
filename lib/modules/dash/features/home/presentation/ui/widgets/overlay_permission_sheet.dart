import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/overlay/ride_request_overlay.dart';

/// One-time, optional education sheet for the Android "display over other
/// apps" permission, which powers the floating Drivio bubble on background
/// ride alerts. Shown after the driver's first successful go-online —
/// deliberately NOT a bare jump into system settings: the sheet explains
/// the why first, and skipping is a first-class choice.
///
/// Shows at most once (a "Not now" is remembered); never shows when the
/// permission is already granted or off-Android.

const String _kSeenKey = 'overlay_prompt_seen';

/// Illustration slot — drop the generated image here (see the ChatGPT
/// prompt in the feature notes). Falls back to an icon until it exists.
const String _kIllustrationAsset = 'assets/images/overlay_permission.png';

Future<void> showOverlayPermissionSheetIfNeeded(BuildContext context) async {
  if (!Platform.isAndroid) return;
  try {
    if (await FlutterOverlayWindow.isPermissionGranted()) return;
  } catch (_) {
    return;
  }
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kSeenKey) ?? false) return;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext ctx) => const _OverlayPermissionSheet(),
  );
  await prefs.setBool(_kSeenKey, true);
}

class _OverlayPermissionSheet extends StatelessWidget {
  const _OverlayPermissionSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderStrong,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Illustration (graceful icon fallback until the asset lands).
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  _kIllustrationAsset,
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                      Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: context.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.picture_in_picture_alt_rounded,
                      size: 48,
                      color: context.accent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Catch trips from\nany screen.',
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(color: context.text),
            ),
            const SizedBox(height: 10),
            Text(
              'When a rider requests a trip while you’re in another app '
              'maps, music, anything Drivio can float a small bubble over '
              'it with the pickup and drop-off, so you never miss a request. '
              'Allow “Display over other apps” to turn it on. Optional: '
              'you’ll still get the sound and notification without it.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm
                  .copyWith(color: context.textDim, height: 1.5),
            ),
            const SizedBox(height: 22),
            DrivioButton(
              label: 'Allow in Settings',
              onPressed: () async {
                Navigator.of(context).pop();
                await ensureOverlayPermission();
              },
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Not now',
                style: AppTextStyles.caption.copyWith(color: context.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
