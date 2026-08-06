import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

/// Driver password reset, over our own SMS OTP.
///
/// Drivers sign in with a phone number that maps to a synthetic
/// `<digits>@drivio.internal` email, so Supabase's email-link reset can
/// never reach them. Three edge functions carry the flow instead:
///
///  1. `password-reset-start` confirms the number belongs to an account
///     before spending an SMS, then sends the OTP through Termii.
///  2. `password-reset-verify` checks the code and, because Termii burns
///     a pin the moment it verifies, hands back a single-use token.
///  3. `password-reset-complete` trades that token for the new password.
///
/// Steps 1 and 2 answer identically for an unregistered number and a
/// wrong code, so neither can be used to discover who drives for Drivio.
/// That means [start] returning normally is NOT a promise that an SMS
/// went out.
class PasswordResetService {
  PasswordResetService(this._supabase);

  final SupabaseModule _supabase;

  /// Begins a reset for [phoneE164]. Resolves normally whether or not
  /// the number has an account; throws only when the request itself
  /// could not be made.
  Future<void> start(String phoneE164) async {
    try {
      await _supabase.functions.invoke(
        'password-reset-start',
        body: <String, dynamic>{'phone': phoneE164},
      );
    } catch (e, st) {
      AppLogger.w('passwordReset.start failed', error: e, stackTrace: st);
      throw const PasswordResetException(
        "We could not reach Drivio just now. Check your connection and try again.",
      );
    }
  }

  /// Checks [code] against [phoneE164]. Returns the single-use reset
  /// token on success, or null for any wrong or expired code.
  Future<String?> verify({
    required String phoneE164,
    required String code,
  }) async {
    try {
      final FunctionResponse res = await _supabase.functions.invoke(
        'password-reset-verify',
        body: <String, dynamic>{'phone': phoneE164, 'code': code},
      );
      final Object? data = res.data;
      if (data is Map && data['verified'] == true) {
        final Object? token = data['token'];
        return token is String && token.isNotEmpty ? token : null;
      }
      return null;
    } catch (e, st) {
      AppLogger.w('passwordReset.verify failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Sets the new password. Throws [PasswordResetException] with a
  /// message worth showing when the server refuses.
  Future<void> complete({
    required String phoneE164,
    required String token,
    required String password,
  }) async {
    try {
      final FunctionResponse res = await _supabase.functions.invoke(
        'password-reset-complete',
        body: <String, dynamic>{
          'phone': phoneE164,
          'token': token,
          'password': password,
        },
      );
      final Object? data = res.data;
      if (data is Map && data['ok'] == true) {
        return;
      }
      throw PasswordResetException(_messageFor(data));
    } on PasswordResetException {
      rethrow;
    } on FunctionException catch (e) {
      AppLogger.w('passwordReset.complete FunctionException',
          data: <String, dynamic>{'detail': e.details?.toString() ?? ''});
      throw PasswordResetException(_messageFor(e.details));
    } catch (e, st) {
      AppLogger.w('passwordReset.complete failed', error: e, stackTrace: st);
      throw const PasswordResetException(
        "We could not save your new password. Please try again.",
      );
    }
  }

  String _messageFor(Object? data) {
    final String key = (data is Map ? data['error']?.toString() : null) ?? '';
    switch (key) {
      case 'weak_password':
        return 'Use at least 8 characters.';
      case 'invalid_token':
      case 'expired_token':
        return 'That code has expired. Start again to get a new one.';
      default:
        return "We could not save your new password. Please try again.";
    }
  }
}

/// Thrown when a reset step fails for a reason worth showing the driver.
class PasswordResetException implements Exception {
  const PasswordResetException(this.message);
  final String message;
}
