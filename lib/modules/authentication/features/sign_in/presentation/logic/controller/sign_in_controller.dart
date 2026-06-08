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

  /// E.164-style phone string sent through to the auth/OTP layer.
  /// Strips non-digits and drops a leading "0" before prepending +234.
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

  /// Legacy alias — old callers (OTP page) read `signInState.email` as the
  /// identifier. For phone-based sign-in the identifier is the normalized
  /// phone; keep this getter so old call sites keep compiling without an
  /// API shift.
  String get email => normalizedPhone;

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

  // TODO: Replace with real OTP provider (Termii, etc.)
  Future<bool> requestOtp() async {
    if (!state.canSubmit) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    // Skip actual OTP sending — will be wired to a real provider later.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(isLoading: false);
    return true;
  }
}

final StateNotifierProvider<SignInController, SignInState>
    signInControllerProvider =
    StateNotifierProvider<SignInController, SignInState>(
  (Ref _) => SignInController(),
);
