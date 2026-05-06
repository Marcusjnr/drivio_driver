import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/location/location_permission_service.dart';

/// Bottom-sheet gate shown when the driver tries to go online without
/// a usable location permission. Adapts its CTA based on whether the
/// OS will let us re-prompt (denied → ask again) or whether the
/// driver has to flip a toggle in Settings (permanently denied or
/// device location services off).
class LocationGateSheet extends ConsumerWidget {
  const LocationGateSheet({
    super.key,
    required this.permission,
    required this.onAllow,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  /// Snapshot of the permission state the controller saw when it
  /// failed to start streaming. Determines copy + CTA below.
  final LocationPermState permission;

  /// Re-prompt the system permission dialog. Only fired when
  /// [permission] is [LocationPermState.denied] (or unknown) — the
  /// other states route through [onOpenSettings] instead.
  final VoidCallback onAllow;

  /// Deep-link to app settings (or device location settings, picked
  /// by [LocationPermissionService] based on the current state).
  final VoidCallback onOpenSettings;

  /// Driver tapped scrim or "Maybe later". They stay offline.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _Copy copy = _copyFor(permission);

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
                    color: copy.tone.withValues(alpha: 0.16),
                    border: Border.all(
                      color: copy.tone.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('📍', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(height: 14),
                Pill(text: copy.pill, tone: copy.pillTone),
                const SizedBox(height: 10),
                Text(
                  copy.title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1.copyWith(color: context.text),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 290,
                  child: Text(
                    copy.body,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: context.textDim,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                DrivioButton(
                  label: copy.cta,
                  onPressed: copy.useSettings ? onOpenSettings : onAllow,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    'Maybe later',
                    style:
                        TextStyle(color: context.textDim, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _Copy _copyFor(LocationPermState s) {
    switch (s) {
      case LocationPermState.permanentlyDenied:
        return const _Copy(
          pill: 'LOCATION BLOCKED',
          pillTone: PillTone.red,
          title: 'Unblock Drivio in\nsystem settings.',
          body:
              "We can't ask again from inside the app — open Settings → Permissions and switch Location on for Drivio.",
          cta: 'Open settings',
          useSettings: true,
          tone: Color(0xFFF87171),
        );
      case LocationPermState.serviceDisabled:
        return const _Copy(
          pill: 'LOCATION SERVICES OFF',
          pillTone: PillTone.amber,
          title: 'Turn on your\nphone’s location.',
          body:
              "Your device's location is off. Switch it on so we can match you with passengers nearby.",
          cta: 'Open location settings',
          useSettings: true,
          tone: Color(0xFFF59E0B),
        );
      case LocationPermState.denied:
      case LocationPermState.unknown:
      case LocationPermState.granted:
        return const _Copy(
          pill: 'LOCATION REQUIRED',
          pillTone: PillTone.amber,
          title: 'Allow location\nto go online.',
          body:
              "We use your live position to send you nearby ride requests and to share your ETA with passengers.",
          cta: 'Allow location',
          useSettings: false,
          tone: Color(0xFFF59E0B),
        );
    }
  }
}

class _Copy {
  const _Copy({
    required this.pill,
    required this.pillTone,
    required this.title,
    required this.body,
    required this.cta,
    required this.useSettings,
    required this.tone,
  });
  final String pill;
  final PillTone pillTone;
  final String title;
  final String body;
  final String cta;

  /// True when the CTA should deep-link to system settings instead of
  /// re-prompting in-app. Mirrors how the permission state is split.
  final bool useSettings;
  final Color tone;
}
