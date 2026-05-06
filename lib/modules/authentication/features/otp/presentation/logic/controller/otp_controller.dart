import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

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

  // TODO: Replace with real OTP provider resend
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

  /// Dev-only OTP verification. Validates the hardcoded [_devOtpCode], then
  /// either signs the user up (with profile data) or signs them in. Will be
  /// replaced when a real SMS provider (Termii) is wired up.
  Future<bool> verify({
    required AuthMode mode,
    required String email,
    required String password,
    String? phone,
  }) async {
    if (!state.isComplete) return false;

    if (state.value != _devOtpCode) {
      state = state.copyWith(
        isVerifying: false,
        error: 'Wrong code. Please try again.',
        value: '',
      );
      return false;
    }

    state = state.copyWith(isVerifying: true, clearError: true);
    AppLogger.i('otp.verify start', data: <String, dynamic>{
      'mode': mode.toString(),
      'email': email,
    });

    try {
      if (mode == AuthMode.signUp) {
        final AuthResponse res = await _supabase.auth.signUp(
          email: email,
          password: password,
          data: <String, dynamic>{
            'phone': ?phone,
            'role': 'driver',
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
          email: email,
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
        error: e.message,
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
