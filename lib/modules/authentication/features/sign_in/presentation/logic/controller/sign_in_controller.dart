import 'package:flutter_riverpod/flutter_riverpod.dart';

const int _minPasswordLength = 8;
// 10–13 digits after the +234 prefix is stripped — covers NG numbers
// with or without the leading zero.
final RegExp _phoneDigitsRegex = RegExp(r'^[0-9]{10,13}$');

class SignInState {
  const SignInState({
    this.phone = '',
    this.password = '',
    this.isLoading = false,
    this.error,
  });

  /// Local digits the driver typed (without the +234 dial prefix).
  final String phone;
  final String password;
  final bool isLoading;
  final String? error;

  bool get hasValidPhone =>
      _phoneDigitsRegex.hasMatch(phone.replaceAll(RegExp(r'\D'), ''));
  bool get hasValidPassword => password.length >= _minPasswordLength;

  bool get canSubmit => hasValidPhone && hasValidPassword;

  /// E.164-style phone string. Surface identifier shown to the driver;
  /// the actual Supabase auth call (in OtpController) uses a phone-
  /// derived synthetic email so no SMS goes out in dev.
  String get normalizedPhone {
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('234')) {
      digits = digits.substring(3);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+234$digits';
  }

  SignInState copyWith({
    String? phone,
    String? password,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SignInState(
      phone: phone ?? this.phone,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SignInController extends StateNotifier<SignInState> {
  SignInController() : super(const SignInState());

  void onPhoneChanged(String value) =>
      state = state.copyWith(phone: value, clearError: true);

  void onPasswordChanged(String value) =>
      state = state.copyWith(password: value, clearError: true);

  /// Dev stub — no SMS goes out. The OTP screen accepts the hardcoded
  /// code, which then triggers `signInWithPassword` via the phone-
  /// derived synthetic email. Replace with a real send call when a
  /// production SMS provider is wired (Termii / Supabase phone auth).
  Future<bool> requestOtp() async {
    if (!state.canSubmit) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Success: stay loading until the OTP page is on screen; the page
    // calls [endLoading] once navigation settles.
    return true;
  }

  /// Called by pages after navigation completes, so the button never
  /// flashes back to idle while the route transition is running.
  void endLoading() => state = state.copyWith(isLoading: false);
}

final StateNotifierProvider<SignInController, SignInState>
    signInControllerProvider =
    StateNotifierProvider<SignInController, SignInState>(
  (Ref _) => SignInController(),
);
