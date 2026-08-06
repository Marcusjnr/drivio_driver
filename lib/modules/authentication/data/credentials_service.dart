import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

/// Outcome of a pre-OTP credentials check.
enum CredentialCheck {
  /// Phone and password match an account.
  ok,

  /// Wrong password, or no account on that number. Deliberately one
  /// case: see [CredentialsService].
  badCredentials,

  /// Too many failed attempts on this number recently.
  locked,

  /// The check itself could not be made.
  unavailable,
}

/// Confirms a phone and password pair before the sign-in OTP is sent, so
/// a driver learns their password is wrong on the sign-in screen instead
/// of after an SMS has already gone out.
///
/// The check runs on the server ([driver-credentials-check]) rather than
/// here. Calling `signInWithPassword` on the device to test a password
/// mints a real session and fires the app's auth listeners, and signing
/// back out to undo it trips `SessionGuard`, which throws the driver out
/// to the Welcome screen.
class CredentialsService {
  CredentialsService(this._supabase);

  final SupabaseModule _supabase;

  Future<CredentialCheck> check({
    required String phoneE164,
    required String password,
  }) async {
    try {
      final FunctionResponse res = await _supabase.functions.invoke(
        'driver-credentials-check',
        body: <String, dynamic>{'phone': phoneE164, 'password': password},
      );
      final Object? data = res.data;
      if (data is! Map) return CredentialCheck.unavailable;
      if (data['valid'] == true) return CredentialCheck.ok;
      return data['error'] == 'locked'
          ? CredentialCheck.locked
          : CredentialCheck.badCredentials;
    } catch (e, st) {
      AppLogger.w('credentials.check failed', error: e, stackTrace: st);
      return CredentialCheck.unavailable;
    }
  }
}
