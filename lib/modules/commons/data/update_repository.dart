import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/types/app_update.dart';

/// Boot-time version gate. Reads this app's channel envelope out of
/// Firebase Remote Config (parameter [_remoteConfigKey]) and compares
/// the relevant platform's rules against the installed version.
///
/// Prod and staging are separate Firebase projects (see
/// `firebase_options_prod.dart` / `_stage.dart`), so the flavor split is
/// automatic — whichever project this build initialised is the one
/// fetched from. Only the platform (iOS vs Android) is picked client-side,
/// out of one shared JSON value:
/// ```json
/// {
///   "ios":     {"min": "1.4.0", "max": "1.6.2", "forceUpdate": false, "updateUrl": "https://apps.apple.com/..."},
///   "android": {"min": "1.4.0", "max": "1.6.2", "forceUpdate": false, "updateUrl": "https://play.google.com/..."}
/// }
/// ```
///
/// Strictly fail-open: any error, timeout, or missing config resolves to
/// [UpdateCheck.none]. A driver with a dead connection (or before this
/// value is ever configured in the console) must never be blocked from a
/// screen they could otherwise reach; the check simply runs again on the
/// next launch.
class UpdateRepository {
  const UpdateRepository();

  /// Same Remote Config project is shared with the rider app — this
  /// parameter name keeps the two apps' envelopes from colliding.
  static const String _remoteConfigKey = 'driver_update_config';

  /// How long boot will wait on the fetch before giving up. Short on
  /// purpose: this races the splash animation, not the driver's patience.
  static const Duration _timeout = Duration(seconds: 4);

  Future<UpdateCheck> check() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final String platform = Platform.isIOS ? 'ios' : 'android';

      final FirebaseRemoteConfig rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: _timeout,
          // A launch-time kill switch needs to take effect on the very
          // next launch, not whenever Remote Config's own cache next
          // expires — always attempt a fresh fetch.
          minimumFetchInterval: Duration.zero,
        ),
      );
      // Ensures `getString` never throws for a key that hasn't been
      // fetched yet (e.g. the very first launch before any network call
      // has ever completed) — an empty object parses to "no platform
      // entry" below, which fails open via UpdateCheck.none.
      await rc.setDefaults(<String, Object>{_remoteConfigKey: '{}'});
      await rc.fetchAndActivate().timeout(_timeout);

      final String raw = rc.getString(_remoteConfigKey);
      if (raw.trim().isEmpty) {
        return UpdateCheck.none;
      }

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return UpdateCheck.none;
      }
      final dynamic platformJson = decoded[platform];
      if (platformJson is! Map) {
        return UpdateCheck.none;
      }

      final UpdateChannel channel = UpdateChannel.fromJson(
        Map<String, dynamic>.from(platformJson),
      );
      final UpdateCheck result = UpdateCheck.evaluate(
        currentVersion: info.version,
        channel: channel,
      );
      AppLogger.i(
        'update.check',
        data: <String, dynamic>{
          'platform': platform,
          'current': info.version,
          'min': channel.minVersion,
          'latest': channel.latestVersion,
          'force': channel.forceUpdate,
          'verdict': result.verdict.name,
        },
      );
      return result;
    } catch (e, st) {
      AppLogger.w(
        'update.check failed, failing open',
        error: e,
        stackTrace: st,
      );
      return UpdateCheck.none;
    }
  }
}
