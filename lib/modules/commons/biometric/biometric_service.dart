import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'package:drivio_driver/modules/commons/logging/app_logger.dart';

class BiometricCheckResult {
  const BiometricCheckResult({
    required this.canCheck,
    required this.types,
  });

  final bool canCheck;
  final List<BiometricType> types;

  bool get hasFaceId => types.contains(BiometricType.face);
  bool get hasFingerprint =>
      types.contains(BiometricType.fingerprint) ||
      types.contains(BiometricType.strong) ||
      types.contains(BiometricType.weak);
}

class BiometricAuthResult {
  const BiometricAuthResult._({
    required this.success,
    this.errorCode,
    this.errorMessage,
  });

  const BiometricAuthResult.success() : this._(success: true);
  const BiometricAuthResult.failure({String? code, String? message})
      : this._(success: false, errorCode: code, errorMessage: message);

  final bool success;
  final String? errorCode;
  final String? errorMessage;
}

/// Thin wrapper around `local_auth` for fingerprint and Face ID prompts.
/// The platform decides which biometric to show; we only supply the
/// reason string and listen for success or failure.
///
/// Ported from kalabash_mobile_v2's `BiometricService` so both apps
/// behave identically, with its Logger swapped for [AppLogger].
class BiometricService {
  BiometricService(this._auth);

  final LocalAuthentication _auth;

  Future<BiometricCheckResult> check() async {
    try {
      final bool supported = await _auth.isDeviceSupported();
      final bool canCheck = supported && await _auth.canCheckBiometrics;
      if (!canCheck) {
        return const BiometricCheckResult(
          canCheck: false,
          types: <BiometricType>[],
        );
      }
      final List<BiometricType> types = await _auth.getAvailableBiometrics();
      return BiometricCheckResult(canCheck: true, types: types);
    } on PlatformException catch (e) {
      AppLogger.w('Biometric check failed: ${e.code} ${e.message}');
      return const BiometricCheckResult(
        canCheck: false,
        types: <BiometricType>[],
      );
    }
  }

  Future<BiometricAuthResult> authenticate({required String reason}) async {
    try {
      final bool ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (ok) {
        return const BiometricAuthResult.success();
      }
      return const BiometricAuthResult.failure(
        message: 'Authentication failed.',
      );
    } on PlatformException catch (e) {
      AppLogger.w('Biometric auth failed: ${e.code} ${e.message}');
      return BiometricAuthResult.failure(
        code: e.code,
        message: e.message ?? 'Authentication failed.',
      );
    }
  }
}
