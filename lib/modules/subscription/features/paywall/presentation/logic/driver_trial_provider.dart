import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

/// Length of the new-driver free trial, in days, as configured by ops in
/// the admin dashboard (`platform_settings.driver_trial`). Read through the
/// anon-callable `get_driver_trial_public` RPC so the paywall copy always
/// says the same number the website does, without an app release.
///
/// Fail-soft: any error resolves to [kDefaultTrialDays], the value the
/// server itself falls back to, so the copy never blanks out and never
/// promises something the trigger wouldn't grant.
const int kDefaultTrialDays = 90;

final FutureProvider<int> driverTrialDaysProvider =
    FutureProvider<int>((Ref ref) async {
  try {
    final dynamic raw = await locator<SupabaseModule>()
        .client
        .rpc<dynamic>('get_driver_trial_public')
        .timeout(const Duration(seconds: 4));
    if (raw is Map) {
      final Object? days = raw['days'];
      if (days is int && days > 0) return days;
      if (days is num && days > 0) return days.toInt();
    }
  } catch (e) {
    AppLogger.w('driver trial length lookup failed, using default', error: e);
  }
  return kDefaultTrialDays;
});
