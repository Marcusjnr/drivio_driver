import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

/// Hardcoded dev-mode OTP. Skips real SMS. Replace this whole shortcut
/// with `supabase.auth.signInWithOtp(phone:)` + `verifyOTP(...)` once
/// the project has an SMS provider configured (Termii / Twilio /
/// MessageBird). Until then, drivers entering this six-digit code on
/// SCR-005 are considered phone-verified.
const String _devOtpCode = '123456';

enum AuthMode { signIn, signUp }

class OtpState {
  const OtpState({
    this.value = '',
    this.length = 6,
    this.resendSeconds = 30,
    this.phone = '',
    this.isVerifying = false,
    this.error,
  });

  final String value;
  final int length;
  final int resendSeconds;
  final String phone;
  final bool isVerifying;
  final String? error;

  bool get isComplete => value.length == length;
  bool get canResend => resendSeconds == 0;

  OtpState copyWith({
    String? value,
    int? resendSeconds,
    String? phone,
    bool? isVerifying,
    String? error,
    bool clearError = false,
  }) {
    return OtpState(
      value: value ?? this.value,
      length: length,
      resendSeconds: resendSeconds ?? this.resendSeconds,
      phone: phone ?? this.phone,
      isVerifying: isVerifying ?? this.isVerifying,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OtpController extends StateNotifier<OtpState> {
  OtpController({String phone = ''})
      : super(OtpState(phone: phone)) {
    _startTimer();
  }

  Timer? _timer;
  final SupabaseModule _supabase = locator<SupabaseModule>();

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (state.resendSeconds == 0) {
        t.cancel();
        return;
      }
      state = state.copyWith(resendSeconds: state.resendSeconds - 1);
    });
  }

  /// Dev stub — no real SMS resend. Just resets the countdown so the UI
  /// keeps behaving correctly while we wait on real SMS provider wiring.
  Future<void> resend() async {
    if (!state.canResend) return;
    state = state.copyWith(resendSeconds: 30, clearError: true);
    _startTimer();
  }

  void setValue(String value) {
    if (value.length > state.length) {
      state = state.copyWith(
        value: value.substring(0, state.length),
        clearError: true,
      );
      return;
    }
    state = state.copyWith(value: value, clearError: true);
  }

  void surfaceError(String message) {
    state = state.copyWith(
      isVerifying: false,
      error: message,
      value: '',
    );
  }

  /// Verifies the OTP code, then creates / authenticates the Supabase
  /// session.
  ///
  /// Dev shortcut: the code itself is checked against the hardcoded
  /// [_devOtpCode] — no SMS round-trip. Once verified, the actual
  /// Supabase auth call is made using a phone-derived synthetic email
  /// (`<digits>@drivio.internal`) so the phone IS the identifier from
  /// the driver's perspective while Supabase auth records it as an
  /// email under the hood. No SMS goes out in either direction.
  ///
  /// [phone] is the normalized E.164 phone (e.g. `+2348123354467`).
  /// [signUpData] is optional sign-up metadata (full name, real email,
  /// referral). Stored in `raw_user_meta_data` so the post-OTP profile
  /// insert can reach it if needed.
  Future<bool> verify({
    required AuthMode mode,
    required String phone,
    required String password,
    Map<String, dynamic>? signUpData,
  }) async {
    if (!state.isComplete) return false;

    if (state.value != _devOtpCode) {
      state = state.copyWith(
        isVerifying: false,
        error: 'Wrong code. Try again.',
        value: '',
      );
      return false;
    }

    state = state.copyWith(isVerifying: true, clearError: true);

    final String syntheticEmail = _phoneToSyntheticEmail(phone);
    AppLogger.i('otp.verify start', data: <String, dynamic>{
      'mode': mode.toString(),
      'phone': phone,
    });

    try {
      if (mode == AuthMode.signUp) {
        final AuthResponse res = await _supabase.auth.signUp(
          email: syntheticEmail,
          password: password,
          data: <String, dynamic>{
            'phone': phone,
            'role': 'driver',
            ...?signUpData,
          },
        );
        if (res.session == null) {
          AppLogger.w('otp.verify signUp returned null session');
          state = state.copyWith(
            isVerifying: false,
            error:
                'Email confirmation is enabled on this Supabase project. Disable "Confirm email" under Authentication → Sign In / Providers → Email, then try again.',
            value: '',
          );
          return false;
        }
      } else {
        await _supabase.auth.signInWithPassword(
          email: syntheticEmail,
          password: password,
        );
      }
      final Session? after = _supabase.auth.currentSession;
      AppLogger.i('otp.verify success', data: <String, dynamic>{
        'session': after == null ? 'null' : 'present',
        'user_id': after?.user.id ?? '—',
      });
      state = state.copyWith(isVerifying: false);
      return true;
    } on AuthException catch (e) {
      AppLogger.w('otp.verify AuthException',
          data: <String, dynamic>{'message': e.message});
      state = state.copyWith(
        isVerifying: false,
        error: _humaniseAuthError(e),
        value: '',
      );
      return false;
    } catch (e, st) {
      AppLogger.e('otp.verify threw', error: e, stackTrace: st);
      state = state.copyWith(
        isVerifying: false,
        error: 'Verification failed. Check your connection.',
        value: '',
      );
      return false;
    }
  }

  /// "+2348123354467" → "2348123354467@drivio.internal". The local part
  /// is the E.164 digits without the "+" so the same phone always maps
  /// to the same synthetic email — sign-up and sign-in resolve to one
  /// auth record per phone.
  String _phoneToSyntheticEmail(String normalizedPhone) {
    final String digits = normalizedPhone.replaceAll(RegExp(r'\D'), '');
    return '$digits@drivio.internal';
  }

  /// Warm-practical copy per brand §3.5.
  String _humaniseAuthError(AuthException e) {
    final String m = e.message.toLowerCase();
    if (m.contains('already registered') || m.contains('user already')) {
      return 'That number already has an account. Sign in instead.';
    }
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return "That password doesn't match. Try again or reset it.";
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return "You've tried too many times. Wait a minute, then try again.";
    }
    return e.message;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<OtpController, OtpState> otpControllerProvider =
    StateNotifierProvider<OtpController, OtpState>(
  (Ref _) => OtpController(),
);

StateNotifierProvider<OtpController, OtpState> otpControllerForPhone(
    String phone) {
  return StateNotifierProvider<OtpController, OtpState>(
    (Ref _) => OtpController(phone: phone),
  );
}
