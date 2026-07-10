import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/analytics/analytics_events.dart';
import 'package:drivio_driver/modules/commons/analytics/mixpanel_service.dart';
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

  /// E.164-style phone string. Surface identifier shown to the driver
  /// + stored in `profiles.phone_e164`. Supabase auth itself uses a
  /// phone-derived synthetic email under the hood (see OtpController)
  /// so no SMS goes out in dev.
  String get normalizedPhone {
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('234')) {
      digits = digits.substring(3);
    }
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

  /// Dev stub — no SMS goes out. The OTP screen accepts the hardcoded
  /// code (see `OtpController._devOtpCode`), which then triggers the
  /// real Supabase signUp via the phone-derived synthetic email.
  /// When a real SMS provider is wired (Termii / Supabase phone auth),
  /// replace this with the actual send call.
  Future<bool> requestOtp() async {
    if (!state.canSubmit) return false;
    locator<MixpanelService>().track(AnalyticsEvents.driverSignupStarted);
    state = state.copyWith(isLoading: true, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Success: stay loading until the OTP page is on screen; the page
    // calls [endLoading] once navigation settles.
    return true;
  }

  /// Called by pages after navigation completes, so the button never
  /// flashes back to idle while the route transition is running.
  void endLoading() => state = state.copyWith(isLoading: false);

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

      final MixpanelService mp = locator<MixpanelService>();
      mp.identifyUser(user.id);
      mp.setProfile(<String, dynamic>{'user_role': 'driver'});
      mp.setProfileOnce(<String, dynamic>{
        'signup_date': DateTime.now().toUtc().toIso8601String(),
        'signup_method': 'phone',
      });
      mp.track(AnalyticsEvents.driverAccountCreated);

      // Success: stay loading — the page navigates to home next.
      return true;
    } on PostgrestException catch (e) {
      final bool isDuplicate =
          e.code == '23505' || e.message.contains('duplicate');
      // Name the colliding field — a bare "account already exists" is a
      // dead end when it's actually the email that's taken.
      final String duplicateMessage;
      if (e.message.contains('profiles_email_unique')) {
        duplicateMessage =
            'That email is already on another Drivio account. Use a '
            'different email, or sign in with the number it belongs to.';
      } else if (e.message.contains('profiles_phone_e164_unique')) {
        duplicateMessage =
            'That phone number is already on another account. '
            'Sign in with it instead.';
      } else {
        duplicateMessage = 'Account already exists. Try signing in instead.';
      }
      state = state.copyWith(
        isLoading: false,
        error: isDuplicate
            ? duplicateMessage
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
