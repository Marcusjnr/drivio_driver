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
  const OtpSendException(this.message);
  final String message;
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
      throw OtpSendException(_sendMessageFor(data));
    } on OtpSendException {
      rethrow;
    } on FunctionException catch (e) {
      AppLogger.w('otp.send FunctionException',
          data: <String, dynamic>{'detail': e.details?.toString() ?? ''});
      throw OtpSendException(_sendMessageFor(e.details));
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

  String _sendMessageFor(Object? data) {
    final String key = (data is Map ? data['error']?.toString() : null) ?? '';
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
