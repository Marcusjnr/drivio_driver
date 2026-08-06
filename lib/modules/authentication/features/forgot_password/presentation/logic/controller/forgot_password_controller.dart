import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/data/password_reset_service.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';

/// Which step of the reset the driver is on.
enum ResetStep { phone, code, password }

class ForgotPasswordState {
  const ForgotPasswordState({
    this.step = ResetStep.phone,
    this.phone = '',
    this.code = '',
    this.password = '',
    this.token,
    this.isBusy = false,
    this.error,
    this.resendSeconds = 0,
  });

  final ResetStep step;
  final String phone;
  final String code;
  final String password;

  /// Single-use proof that the OTP was accepted. Held only in memory,
  /// and only between the code step and the password step.
  final String? token;

  final bool isBusy;
  final String? error;

  /// Seconds left before another code may be requested. 0 = ready.
  final int resendSeconds;

  bool get canResend => resendSeconds == 0 && !isBusy;

  /// Nigerian numbers are 10 digits after the +234 prefix.
  bool get canSubmitPhone => _digits.length >= 10 && !isBusy;
  bool get canSubmitCode => code.length == 6 && !isBusy;
  bool get canSubmitPassword => password.length >= 8 && !isBusy;

  String get _digits {
    String d = phone.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('234')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return d;
  }

  /// The number in the shape every backend call expects.
  String get normalizedPhone => '+234$_digits';

  /// How the number reads back to the driver on the code screen.
  String get displayPhone => '+234 $_digits';

  ForgotPasswordState copyWith({
    ResetStep? step,
    String? phone,
    String? code,
    String? password,
    String? token,
    bool? isBusy,
    String? error,
    bool clearError = false,
    int? resendSeconds,
  }) {
    return ForgotPasswordState(
      step: step ?? this.step,
      phone: phone ?? this.phone,
      code: code ?? this.code,
      password: password ?? this.password,
      token: token ?? this.token,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
      resendSeconds: resendSeconds ?? this.resendSeconds,
    );
  }
}

/// Drives the three reset screens.
///
/// The server answers identically for a number with no account and one
/// with an account, so [submitPhone] always advances. A driver who
/// mistypes their number finds out at the code step, not before, which
/// is the price of not letting anyone probe which numbers drive for
/// Drivio.
class ForgotPasswordController extends StateNotifier<ForgotPasswordState> {
  ForgotPasswordController(this._service)
      : super(const ForgotPasswordState());

  final PasswordResetService _service;
  Timer? _resendTimer;

  static const int _resendCooldown = 30;

  void onPhoneChanged(String v) =>
      state = state.copyWith(phone: v, clearError: true);

  void onCodeChanged(String v) =>
      state = state.copyWith(code: v, clearError: true);

  void onPasswordChanged(String v) =>
      state = state.copyWith(password: v, clearError: true);

  /// Step 1. Returns true once the code screen may open.
  Future<bool> submitPhone() async {
    if (!state.canSubmitPhone) return false;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.start(state.normalizedPhone);
      if (!mounted) return false;
      state = state.copyWith(
        isBusy: false,
        step: ResetStep.code,
        code: '',
      );
      _startResendCountdown();
      return true;
    } on PasswordResetException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isBusy: false, error: e.message);
      return false;
    }
  }

  /// Send another code for the same number.
  Future<void> resend() async {
    if (!state.canResend) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.start(state.normalizedPhone);
      if (!mounted) return;
      state = state.copyWith(isBusy: false);
      _startResendCountdown();
    } on PasswordResetException catch (e) {
      if (!mounted) return;
      state = state.copyWith(isBusy: false, error: e.message);
    }
  }

  /// Step 2. Returns true once the new-password screen may open.
  Future<bool> submitCode() async {
    if (!state.canSubmitCode) return false;
    state = state.copyWith(isBusy: true, clearError: true);
    final String? token = await _service.verify(
      phoneE164: state.normalizedPhone,
      code: state.code,
    );
    if (!mounted) return false;
    if (token == null) {
      state = state.copyWith(
        isBusy: false,
        // Covers a wrong code, an expired code, and a number with no
        // account. Naming the last one would leak who is registered.
        error: 'That code is not right. Check it and try again.',
      );
      return false;
    }
    state = state.copyWith(
      isBusy: false,
      token: token,
      step: ResetStep.password,
      password: '',
    );
    return true;
  }

  /// Step 3. Returns true once the password is saved.
  Future<bool> submitPassword() async {
    if (!state.canSubmitPassword) return false;
    final String? token = state.token;
    if (token == null) {
      state = state.copyWith(
        error: 'That code has expired. Start again to get a new one.',
      );
      return false;
    }
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _service.complete(
        phoneE164: state.normalizedPhone,
        token: token,
        password: state.password,
      );
      if (!mounted) return false;
      state = state.copyWith(isBusy: false);
      return true;
    } on PasswordResetException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isBusy: false, error: e.message);
      return false;
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    state = state.copyWith(resendSeconds: _resendCooldown);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final int next = state.resendSeconds - 1;
      state = state.copyWith(resendSeconds: next < 0 ? 0 : next);
      if (next <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}

/// Auto-disposed so a half-finished reset, and the token it holds, never
/// survives the driver backing out of the flow.
final AutoDisposeStateNotifierProvider<ForgotPasswordController,
        ForgotPasswordState> forgotPasswordControllerProvider =
    StateNotifierProvider.autoDispose<ForgotPasswordController,
        ForgotPasswordState>(
  (Ref _) => ForgotPasswordController(locator<PasswordResetService>()),
);
