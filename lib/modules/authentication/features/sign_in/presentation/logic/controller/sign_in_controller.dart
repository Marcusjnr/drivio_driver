import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/analytics/analytics_events.dart';
import 'package:drivio_driver/modules/commons/analytics/mixpanel_service.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/storage/secure_store.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';

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

  /// E.164-style phone string, and the basis of the synthetic email the
  /// Supabase auth record is keyed on.
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

/// Sign in with phone and password only.
///
/// There is no OTP here. A returning driver already proved they own the
/// number when they signed up, so a second SMS on every sign in only
/// cost them time and us credits. Sign-up still verifies by OTP.
class SignInController extends StateNotifier<SignInState> {
  SignInController() : super(const SignInState());

  void onPhoneChanged(String value) =>
      state = state.copyWith(phone: value, clearError: true);

  void onPasswordChanged(String value) =>
      state = state.copyWith(password: value, clearError: true);

  /// Signs in with what the driver typed. Returns true on success; the
  /// page then resolves the bootstrap route.
  Future<bool> signIn() async {
    if (!state.canSubmit) return false;
    return _authenticate(
      phoneE164: state.normalizedPhone,
      password: state.password,
      biometric: false,
    );
  }

  /// Signs in with credentials released by a biometric prompt. The phone
  /// and password come from the keystore, not the form, so the form does
  /// not need to be filled in.
  Future<bool> signInWithStoredCredentials({
    required String phoneE164,
    required String password,
  }) {
    return _authenticate(
      phoneE164: phoneE164,
      password: password,
      biometric: true,
    );
  }

  Future<bool> _authenticate({
    required String phoneE164,
    required String password,
    required bool biometric,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final SupabaseModule supabase = locator<SupabaseModule>();
    try {
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: _syntheticEmail(phoneE164),
        password: password,
      );
      final String? userId = res.session?.user.id;
      if (userId == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'That phone number or password is not right.',
        );
        return false;
      }

      // Keep the credentials the biometric prompt will replay next time.
      // Written on every success so a password changed elsewhere cannot
      // leave a stale one behind.
      final SecureStore store = locator<SecureStore>();
      await store.writeString(SecureKeys.userPhoneNumber, phoneE164);
      await store.writeString(SecureKeys.userPassword, password);

      final MixpanelService mp = locator<MixpanelService>();
      mp.identifyUser(userId);
      mp.track(
        AnalyticsEvents.signIn,
        properties: <String, dynamic>{
          'method': biometric ? 'biometric' : 'password',
        },
      );

      // Stay loading until the page has navigated; flipping to idle mid
      // transition reads as a failure.
      return true;
    } on AuthException catch (e) {
      AppLogger.w('signIn failed', data: <String, dynamic>{'msg': e.message});
      // A stored credential that no longer works must not keep failing
      // silently behind a fingerprint. Drop it and let them type.
      if (biometric) {
        await locator<SecureStore>().clearBiometricCredentials();
      }
      state = state.copyWith(
        isLoading: false,
        error: biometric
            ? 'Your saved sign in is out of date. Enter your password once '
                'to set it up again.'
            : 'That phone number or password is not right.',
      );
      return false;
    } catch (e, st) {
      AppLogger.w('signIn error', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        error: 'We could not reach Drivio just now. Check your connection '
            'and try again.',
      );
      return false;
    }
  }

  /// "+2348123354467" → "2348123354467@drivio.internal". Same mapping the
  /// OTP controller uses for sign-up, so one phone is always one auth
  /// record.
  String _syntheticEmail(String phoneE164) {
    final String digits = phoneE164.replaceAll(RegExp(r'\D'), '');
    return '$digits@drivio.internal';
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
