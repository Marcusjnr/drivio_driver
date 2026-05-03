import 'package:flutter_riverpod/flutter_riverpod.dart';

const int _minPasswordLength = 8;
final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class SignInState {
  const SignInState({
    this.email = '',
    this.password = '',
    this.isLoading = false,
    this.error,
  });

  final String email;
  final String password;
  final bool isLoading;
  final String? error;

  bool get hasValidEmail => _emailRegex.hasMatch(email.trim());
  bool get hasValidPassword => password.length >= _minPasswordLength;

  bool get canSubmit => hasValidEmail && hasValidPassword;

  SignInState copyWith({
    String? email,
    String? password,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SignInState(
      email: email ?? this.email,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SignInController extends StateNotifier<SignInState> {
  SignInController() : super(const SignInState());

  void onEmailChanged(String value) =>
      state = state.copyWith(email: value, clearError: true);

  void onPasswordChanged(String value) =>
      state = state.copyWith(password: value, clearError: true);

  // TODO: Replace with real OTP provider (Termii, etc.)
  Future<bool> requestOtp() async {
    if (!state.canSubmit) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    // Skip actual OTP sending — will be wired to a real provider later
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
