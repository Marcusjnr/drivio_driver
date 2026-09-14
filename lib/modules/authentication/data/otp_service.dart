import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/config/config.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

/// Dev OTP shortcut. In any non-release build (debug/profile) — and on
/// release builds of the STAGING flavor — the hardcoded `123456` code is
/// accepted and no SMS goes out, so development and internal testing
/// never spend SMS credits. Release builds of the PROD flavor always go
/// through the real Termii integration.
const String kDevOtpCode = '123456';

/// True when the [kDevOtpCode] shortcut is honoured (no real SMS).
bool otpDevModeEnabled() => !kReleaseMode || locator<Config>().isStaging;

/// Thrown when an OTP send fails for a reason worth showing the driver.
class OtpSendException implements Exception {
  const OtpSendException(this.message, {this.code});
  final String message;

  /// The backend's raw error key (`too_soon`, `too_many`, ...), when
  /// known. Lets callers react to specific failure classes — e.g. a
  /// rate-limit response should keep the resend button cooling down
  /// instead of leaving it immediately re-tappable — without parsing
  /// the human-readable [message].
  final String? code;

  /// True for a class of error where retrying immediately is guaranteed
  /// to fail again (the code was rejected for being too frequent, not
  /// because of a transient network/server issue).
  bool get isRateLimited => code == 'too_soon' || code == 'too_many';
}

/// Sends and verifies phone OTPs through the Termii-backed edge functions
/// (`termii-send-otp` / `termii-verify-otp`). The Termii key lives only on
/// the server; the app only ever sees "sent" / "verified: bool".
class OtpService {
  OtpService(this._supabase);

  final SupabaseModule _supabase;

  /// Triggers an SMS OTP to [phoneE164] (e.g. `+2348012345678`).
  /// Throws [OtpSendException] with a friendly message on failure.
  Future<void> send(String phoneE164) async {
    try {
      final FunctionResponse res = await _supabase.functions.invoke(
        'termii-send-otp',
        body: <String, dynamic>{'phone': phoneE164},
      );
      final Object? data = res.data;
      if (data is Map && data['ok'] == true) {
        return;
      }
      final String key = _errorKeyFor(data);
      throw OtpSendException(_sendMessageFor(key), code: key);
    } on OtpSendException {
      rethrow;
    } on FunctionException catch (e) {
      AppLogger.w('otp.send FunctionException',
          data: <String, dynamic>{'detail': e.details?.toString() ?? ''});
      final String key = _errorKeyFor(e.details);
      throw OtpSendException(_sendMessageFor(key), code: key);
    } catch (e, st) {
      AppLogger.w('otp.send failed', error: e, stackTrace: st);
      throw const OtpSendException(
        "Couldn't send the code. Check your connection and try again.",
      );
    }
  }

  /// Verifies [code] for [phoneE164]. Returns true only when Termii
  /// confirms the code. Never throws for a wrong code — returns false.
  Future<bool> verify({
    required String phoneE164,
    required String code,
  }) async {
    try {
      final FunctionResponse res = await _supabase.functions.invoke(
        'termii-verify-otp',
        body: <String, dynamic>{'phone': phoneE164, 'code': code},
      );
      final Object? data = res.data;
      return data is Map && data['verified'] == true;
    } catch (e, st) {
      AppLogger.w('otp.verify failed', error: e, stackTrace: st);
      return false;
    }
  }

  String _errorKeyFor(Object? data) =>
      (data is Map ? data['error']?.toString() : null) ?? '';

  String _sendMessageFor(String key) {
    switch (key) {
      case 'too_soon':
        return 'Hold on a moment before requesting another code.';
      case 'too_many':
        return "You've requested too many codes. Try again in a while.";
      case 'bad_phone':
        return 'That phone number looks off. Check it and try again.';
      case 'not_configured':
        return 'SMS is temporarily unavailable. Please try again shortly.';
      default:
        return "Couldn't send the code. Please try again.";
    }
  }
}
