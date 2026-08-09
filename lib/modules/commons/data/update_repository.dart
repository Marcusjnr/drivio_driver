import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

import 'package:drivio_driver/modules/commons/config/config.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/app_update.dart';

/// Boot-time version gate. Reads this build's channel row from
/// `app_versions` (via the anon-callable `get_app_update_channel` RPC,
/// since the check runs before sign-in) and compares it against the
/// installed version.
///
/// Strictly fail-open: any error, timeout, or missing config resolves to
/// [UpdateCheck.none]. A driver with a dead connection must never be
/// blocked from a screen they could otherwise reach; the check simply
/// runs again on the next launch.
class UpdateRepository {
  UpdateRepository(this._supabase, this._config);

  final SupabaseModule _supabase;
  final Config _config;

  /// How long boot will wait on the network before giving up. Short on
  /// purpose: this races the splash animation, not the driver's patience.
  static const Duration _timeout = Duration(seconds: 4);

  Future<UpdateCheck> check() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final String platform = Platform.isIOS ? 'ios' : 'android';
      final String flavor = _config.isStaging ? 'staging' : 'prod';

      final dynamic raw = await _supabase.client
          .rpc<dynamic>(
            'get_app_update_channel',
            params: <String, dynamic>{
              'p_app': 'driver',
              'p_platform': platform,
              'p_flavor': flavor,
            },
          )
          .timeout(_timeout);

      if (raw is! Map) return UpdateCheck.none;
      final UpdateChannel channel =
          UpdateChannel.fromJson(Map<String, dynamic>.from(raw));

      final UpdateCheck result = UpdateCheck.evaluate(
        currentVersion: info.version,
        channel: channel,
      );
      AppLogger.i('update.check', data: <String, dynamic>{
        'current': info.version,
        'min': channel.minVersion,
        'latest': channel.latestVersion,
        'force': channel.forceUpdate,
        'verdict': result.verdict.name,
      });
      return result;
    } catch (e, st) {
      AppLogger.w('update.check failed, failing open',
          error: e, stackTrace: st);
      return UpdateCheck.none;
    }
  }
}
