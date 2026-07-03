import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/location/location_permission_service.dart';

/// Full-screen rationale for "Allow all the time" location (Android).
///
/// Since Android 11 the OS won't show the background-location dialog
/// in-app; the only path is the app's location-permission settings
/// screen. `Permission.locationAlways.request()` deep-links STRAIGHT to
/// that screen (no Permissions → Location digging), so this page's job
/// is simply to make sure the driver knows which option to pick before
/// they land there — hence the settings-screen illustration with
/// "Allow all the time" highlighted.
///
/// This grant is REQUIRED to go online: the page pops with `true` once
/// granted, `false` when the driver bails ("Not now" / back), and the
/// go-online flow in the drive shell blocks on that result.
class LocationAlwaysPage extends ConsumerStatefulWidget {
  const LocationAlwaysPage({super.key});

  @override
  ConsumerState<LocationAlwaysPage> createState() =>
      _LocationAlwaysPageState();
}

class _LocationAlwaysPageState extends ConsumerState<LocationAlwaysPage> {
  bool _opening = false;

  Future<void> _openSetting() async {
    setState(() => _opening = true);
    try {
      // On Android 11+ this launches the system "Location permission"
      // screen for the app; the future resolves when the driver returns.
      final PermissionStatus status =
          await Permission.locationAlways.request();
      if (!mounted) {
        return;
      }
      if (status.isGranted) {
        AppNotifier.success(
          message: "You're set — location stays on while you drive.",
        );
        if (AppNavigation.canPop()) {
          AppNavigation.pop<bool>(true);
        }
        return;
      }
    } catch (_) {
      // Fall through to the generic settings screen as a last resort.
      await locator<LocationPermissionService>().openAppSettings();
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              BackButtonBox(onTap: () => AppNavigation.pop<bool>(false)),
              const SizedBox(height: 18),
              Text(
                'STAY ONLINE',
                style: AppTextStyles.eyebrow.copyWith(color: context.coral),
              ),
              const SizedBox(height: 12),
              Text(
                'Set location to\n“All the time”.',
                style: AppTextStyles.displayLg.copyWith(
                  color: context.text,
                  fontSize: 32,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Riders can only reach you while Drivio knows where you '
                'are. “All the time” keeps you online when your screen is '
                'off or another app is open you can’t go online '
                'without it.',
                style: AppTextStyles.bodySm.copyWith(
                  color: context.textDim,
                  height: 1.55,
                ),
              ),
              const Spacer(),
              // Illustration of the settings screen the driver is about
              // to see, with the right option highlighted. Falls back to
              // a drawn preview until the generated asset lands.
              Center(
                child: Image.asset(
                  'assets/images/location_always.png',
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (BuildContext _, Object _, StackTrace? _) =>
                          const _SettingsPreview(),
                ),
              ),
              const Spacer(),
              // The one instruction that matters, spelled out.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.surface2,
                  borderRadius: AppRadius.base,
                  border: Border.all(color: context.border),
                ),
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.captionSm.copyWith(
                      color: context.textDim,
                      height: 1.5,
                    ),
                    children: <InlineSpan>[
                      const TextSpan(text: 'On the next screen, choose '),
                      TextSpan(
                        text: '“Allow all the time”',
                        style: AppTextStyles.captionSm.copyWith(
                          color: context.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DrivioButton(
                label: _opening ? 'Opening settings…' : 'Open location settings',
                disabled: _opening,
                onPressed: _opening ? null : () => unawaited(_openSetting()),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => AppNavigation.pop<bool>(false),
                  child: Text(
                    'Not now',
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.textDim,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drawn stand-in for the settings-screen illustration: the Android
/// location-permission radio list with "Allow all the time" selected.
/// Swapped out automatically once assets/images/location_always.png
/// ships in the bundle.
class _SettingsPreview extends StatelessWidget {
  const _SettingsPreview();

  @override
  Widget build(BuildContext context) {
    const List<(String, bool)> rows = <(String, bool)>[
      ('Allow all the time', true),
      ('Allow only while using the app', false),
      ('Ask every time', false),
      ("Don't allow", false),
    ];
    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'LOCATION ACCESS FOR DRIVIO DRIVER',
            style: AppTextStyles.eyebrow.copyWith(
              fontSize: 9,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          for (final (String label, bool selected) in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? context.coral.withValues(alpha: 0.12)
                    : context.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? context.coral.withValues(alpha: 0.55)
                      : context.border,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? context.coral : context.textMuted,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: selected
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.coral,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.captionSm.copyWith(
                        color: selected ? context.text : context.textDim,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
