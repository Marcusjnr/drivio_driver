import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:drivio_driver/modules/commons/all.dart';

/// Prominent, in-app disclosure shown BEFORE the OS microphone-permission
/// dialog fires for the first time.
///
/// Google Play's "Prominent Disclosure and Consent" policy requires a
/// runtime permission request be immediately preceded by an in-app
/// explanation of what's being accessed and why. Calling
/// `Permission.microphone.request()` cold — as the call flow used to —
/// fails that check.
///
/// Call this right before starting or answering a free call. Returns
/// `true` when the mic is usable (already granted, or just granted here);
/// `false` when the driver declines or the OS denies. Skips the dialog
/// entirely when permission is already granted, since no fresh consent
/// prompt is about to appear.
Future<bool> ensureMicDisclosure(BuildContext context) async {
  final PermissionStatus current = await Permission.microphone.status;
  if (current.isGranted) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }

  final bool? proceed = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.border),
      ),
      title: Text(
        'Microphone access',
        style: AppTextStyles.h2.copyWith(color: context.text),
      ),
      content: Text(
        'Drivio uses your microphone for in-app voice calls with riders, '
        'so you can stay in touch during a trip without sharing phone '
        'numbers. Audio is only used for the call itself never '
        'recorded or shared.',
        style: AppTextStyles.bodySm.copyWith(color: context.textDim),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Not now', style: TextStyle(color: context.textDim)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'Allow microphone',
            style: TextStyle(color: context.accent),
          ),
        ),
      ],
    ),
  );
  if (proceed != true) {
    return false;
  }

  final PermissionStatus status = await Permission.microphone.request();
  return status.isGranted;
}
