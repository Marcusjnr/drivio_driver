import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/location/location_permission_service.dart';

/// Prominent, in-app disclosure shown BEFORE the OS location-permission
/// dialog fires for the first time.
///
/// Google Play's "Prominent Disclosure and Consent" policy requires that
/// a runtime permission request (and the system consent dialog it opens)
/// be immediately preceded by an in-app screen explaining what data is
/// collected and why. Calling `Geolocator.requestPermission()` cold — as
/// the old go-online flow did — fails that check. This page is that
/// disclosure: it states what ("your device's location"), why ("to match
/// you with nearby riders and track trips"), and how ("only while you're
/// online; never sold"), and only triggers the OS prompt once the driver
/// taps through it.
///
/// Pops `true` once permission is granted (while-in-use or better),
/// `false` on denial or "Not now".
class LocationWhileInUsePage extends ConsumerStatefulWidget {
  const LocationWhileInUsePage({super.key});

  @override
  ConsumerState<LocationWhileInUsePage> createState() =>
      _LocationWhileInUsePageState();
}

class _LocationWhileInUsePageState
    extends ConsumerState<LocationWhileInUsePage> {
  bool _requesting = false;

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    try {
      final LocationPermState state = await locator<LocationPermissionService>()
          .request();
      if (!mounted) return;
      if (state.isUsable) {
        AppNavigation.pop<bool>(true);
        return;
      }
      if (state == LocationPermState.permanentlyDenied) {
        AppNotifier.warning(
          message:
              'Location is blocked. Enable it in Settings to go online.',
        );
      }
      AppNavigation.pop<bool>(false);
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
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
                'LOCATION ACCESS',
                style: AppTextStyles.eyebrow.copyWith(color: context.coral),
              ),
              const SizedBox(height: 12),
              Text(
                'Drivio needs your\nlocation to go online.',
                style: AppTextStyles.displayLg.copyWith(
                  color: context.text,
                  fontSize: 32,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'While you’re online, Drivio uses your precise location '
                'to match you with nearby ride requests, route you to '
                'pickups, and share your position with the rider during a '
                'trip. Your location is only used for these driving '
                'features it’s never sold or used for advertising.',
                style: AppTextStyles.bodySm.copyWith(
                  color: context.textDim,
                  height: 1.55,
                ),
              ),
              const Spacer(),
              Center(
                child: Icon(
                  Icons.location_on_rounded,
                  size: 96,
                  color: context.coral.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
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
                        text: '"Allow"',
                        style: AppTextStyles.captionSm.copyWith(
                          color: context.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' to continue.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DrivioButton(
                label: _requesting ? 'Requesting…' : 'Allow location access',
                disabled: _requesting,
                onPressed:
                    _requesting ? null : () => unawaited(_requestPermission()),
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
