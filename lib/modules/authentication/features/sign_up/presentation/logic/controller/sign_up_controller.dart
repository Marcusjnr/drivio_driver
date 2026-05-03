import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

const int _minPasswordLength = 8;
final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class SignUpState {
  const SignUpState({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.password = '',
    this.referralCode = '',
    this.isLoading = false,
    this.error,
  });

  final String fullName;
  final String email;
  final String phone;
  final String password;
  final String referralCode;
  final bool isLoading;
  final String? error;

  bool get hasValidEmail => _emailRegex.hasMatch(email.trim());
  bool get hasValidPassword => password.length >= _minPasswordLength;

  bool get canSubmit =>
      fullName.trim().length >= 2 &&
      phone.replaceAll(RegExp(r'\s'), '').length >= 10 &&
      hasValidEmail &&
      hasValidPassword;

  String get normalizedPhone {
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+234$digits';
  }

  /// True when the user has filled in profile data and gone through OTP.
  bool get hasPendingProfile => fullName.trim().length >= 2;

  SignUpState copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? password,
    String? referralCode,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SignUpState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      referralCode: referralCode ?? this.referralCode,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SignUpController extends StateNotifier<SignUpState> {
  SignUpController() : super(const SignUpState());

  final SupabaseModule _supabase = locator<SupabaseModule>();

  void onFullNameChanged(String v) =>
      state = state.copyWith(fullName: v, clearError: true);

  void onEmailChanged(String v) =>
      state = state.copyWith(email: v, clearError: true);

  void onPhoneChanged(String v) =>
      state = state.copyWith(phone: v, clearError: true);

  void onPasswordChanged(String v) =>
      state = state.copyWith(password: v, clearError: true);

  void onReferralChanged(String v) =>
      state = state.copyWith(referralCode: v, clearError: true);

  // TODO: Replace with real OTP provider (Termii, etc.)
  Future<bool> requestOtp() async {
    if (!state.canSubmit) return false;
    state = state.copyWith(isLoading: true, clearError: true);
    // Skip actual OTP sending — will be wired to a real provider later
    await Future<void>.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(isLoading: false);
    return true;
  }

  Future<bool> submitProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final User? user = _supabase.auth.currentUser;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Session expired. Please sign in again.',
        );
        return false;
      }

      final String trimmedEmail = state.email.trim();
      final String trimmedReferral = state.referralCode.trim();

      await _supabase.db('profiles').insert(<String, dynamic>{
        'user_id': user.id,
        'full_name': state.fullName.trim(),
        'phone_e164': state.normalizedPhone,
        'email': trimmedEmail,
        'referral_code': _generateReferralCode(),
        'referred_by': trimmedReferral.isEmpty ? null : trimmedReferral,
      });

      await _supabase.db('drivers').insert(<String, dynamic>{
        'user_id': user.id,
        'kyc_status': 'not_started',
      });

      state = state.copyWith(isLoading: false);
      return true;
    } on PostgrestException catch (e) {
      final bool isDuplicate =
          e.code == '23505' || e.message.contains('duplicate');
      state = state.copyWith(
        isLoading: false,
        error: isDuplicate
            ? 'Account already exists. Try signing in instead.'
            : 'Something went wrong. Please try again.',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }

  void reset() => state = const SignUpState();

  static String _generateReferralCode() {
    const String chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random rng = Random.secure();
    return String.fromCharCodes(
      Iterable<int>.generate(
        6,
        (_) => chars.codeUnitAt(rng.nextInt(chars.length)),
      ),
    );
  }
}

final StateNotifierProvider<SignUpController, SignUpState>
    signUpControllerProvider =
    StateNotifierProvider<SignUpController, SignUpState>(
  (Ref _) => SignUpController(),
);
