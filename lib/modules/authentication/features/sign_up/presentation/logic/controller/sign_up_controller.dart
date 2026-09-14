import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/authentication/data/otp_service.dart';
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
    this.fullNameTouched = false,
    this.emailTouched = false,
    this.phoneTouched = false,
    this.passwordTouched = false,
  });

  final String fullName;
  final String email;
  final String phone;
  final String password;
  final String referralCode;
  final bool isLoading;
  final String? error;

  /// A field is "touched" once the driver has focused then left it (or
  /// tried to submit). Error text only shows for touched fields, so a
  /// freshly-opened blank form doesn't greet them with four red boxes.
  final bool fullNameTouched;
  final bool emailTouched;
  final bool phoneTouched;
  final bool passwordTouched;

  bool get hasValidEmail => _emailRegex.hasMatch(email.trim());
  bool get hasValidPassword => password.length >= _minPasswordLength;
  bool get hasValidFullName => fullName.trim().length >= 2;
  bool get hasValidPhone => phone.replaceAll(RegExp(r'\s'), '').length >= 10;

  bool get canSubmit =>
      hasValidFullName && hasValidPhone && hasValidEmail && hasValidPassword;

  /// Why the button won't enable for this field, or null when it's fine
  /// or not yet touched.
  String? get fullNameError {
    if (!fullNameTouched || hasValidFullName) {
      return null;
    }
    return fullName.trim().isEmpty
        ? 'Enter your full name.'
        : 'Name must be at least 2 characters.';
  }

  String? get emailError {
    if (!emailTouched || hasValidEmail) {
      return null;
    }
    return email.trim().isEmpty
        ? 'Enter your email address.'
        : "That email doesn't look right.";
  }

  String? get phoneError {
    if (!phoneTouched || hasValidPhone) {
      return null;
    }
    return phone.trim().isEmpty
        ? 'Enter your phone number.'
        : 'Enter a valid phone number.';
  }

  String? get passwordError {
    if (!passwordTouched || hasValidPassword) {
      return null;
    }
    return password.isEmpty
        ? 'Enter a password.'
        : 'Password must be at least 8 characters.';
  }

  /// Every reason the button is currently disabled, for a driver who's
  /// touched nothing yet and wants the whole picture at a glance (e.g.
  /// after pasting in a password manager and tapping Continue early).
  List<String> get blockingReasons => <String>[
    if (!hasValidFullName) 'your full name',
    if (!hasValidEmail) 'a valid email',
    if (!hasValidPhone) 'a valid phone number',
    if (!hasValidPassword) 'a password of at least 8 characters',
  ];

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
    bool? fullNameTouched,
    bool? emailTouched,
    bool? phoneTouched,
    bool? passwordTouched,
  }) {
    return SignUpState(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      referralCode: referralCode ?? this.referralCode,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      fullNameTouched: fullNameTouched ?? this.fullNameTouched,
      emailTouched: emailTouched ?? this.emailTouched,
      phoneTouched: phoneTouched ?? this.phoneTouched,
      passwordTouched: passwordTouched ?? this.passwordTouched,
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

  /// Called on blur (focus lost). Errors for a field only render once
  /// it's been touched, so opening the form doesn't show four errors
  /// at once.
  void touchFullName() => state = state.copyWith(fullNameTouched: true);
  void touchEmail() => state = state.copyWith(emailTouched: true);
  void touchPhone() => state = state.copyWith(phoneTouched: true);
  void touchPassword() => state = state.copyWith(passwordTouched: true);

  /// Reveal every field's error at once — used when the driver taps the
  /// disabled Continue button instead of methodically tabbing through
  /// fields (e.g. after autofill leaves one field looking filled but
  /// invalid).
  void touchAll() => state = state.copyWith(
    fullNameTouched: true,
    emailTouched: true,
    phoneTouched: true,
    passwordTouched: true,
  );

  /// Sends the phone OTP via Termii, then lets the page navigate to the
  /// OTP screen. In dev mode no SMS goes out — the screen accepts the
  /// hardcoded [kDevOtpCode]. A real send failure keeps the driver on
  /// this screen with an error instead of stranding them on an OTP page
  /// no code will ever arrive for.
  Future<bool> requestOtp() async {
    if (!state.canSubmit) return false;
    locator<MixpanelService>().track(AnalyticsEvents.driverSignupStarted);
    state = state.copyWith(isLoading: true, clearError: true);
    if (!otpDevModeEnabled()) {
      try {
        await locator<OtpService>().send(state.normalizedPhone);
      } on OtpSendException catch (e) {
        state = state.copyWith(isLoading: false, error: e.message);
        return false;
      }
    }
    // Success: stay loading until the OTP page is on screen; the page
    // calls [endLoading] once navigation settles.
    return true;
  }

  /// Called by pages after navigation completes, so the button never
  /// flashes back to idle while the route transition is running.
  void endLoading() => state = state.copyWith(isLoading: false);

  /// Completes sign-up via `complete_driver_signup` — one atomic,
  /// idempotent RPC (mirrors the rider app's `complete_passenger_signup`)
  /// instead of two separate raw inserts. The old two-insert version
  /// could leave a driver with a live auth account and no `profiles` /
  /// `drivers` row if the second insert never ran (network blip, app
  /// kill, anything) — a "half-created account" that then made every
  /// retry fail on Supabase Auth's own "already registered" for the
  /// synthetic email. Being idempotent, this is now always safe to
  /// re-run: a driver stuck mid-signup just lands here again and it
  /// finishes cleanly.
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

      await _supabase.client.rpc<dynamic>(
        'complete_driver_signup',
        params: <String, dynamic>{
          'p_full_name': state.fullName.trim(),
          'p_email': trimmedEmail,
          'p_phone_e164': state.normalizedPhone,
          'p_referred_by': trimmedReferral.isEmpty ? null : trimmedReferral,
        },
      );

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
      final String message = e.message.toLowerCase();
      final String friendly;
      if (message.contains('signup_conflict')) {
        // A genuine residual race (see the RPC) — safe to just retry.
        friendly = 'Something changed while signing you up. Please try again.';
      } else if (message.contains('name_too_short')) {
        friendly = 'Enter your full name.';
      } else if (message.contains('phone_invalid')) {
        friendly = 'Enter a valid phone number.';
      } else {
        friendly = 'Something went wrong. Please try again.';
      }
      state = state.copyWith(isLoading: false, error: friendly);
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
}

final StateNotifierProvider<SignUpController, SignUpState>
    signUpControllerProvider =
    StateNotifierProvider<SignUpController, SignUpState>(
  (Ref _) => SignUpController(),
);
