import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:drivio_driver/modules/commons/logging/app_logger.dart';

/// Keys held in the OS keystore. Names mirror kalabash_mobile_v2 so the
/// two apps stay recognisable to anyone who works on both.
class SecureKeys {
  SecureKeys._();

  /// Driver opted in to biometric sign in.
  static const String enableLocalLogin = 'enableLocalLoginKey';

  /// Driver said no to the enable-biometrics offer, so stop offering.
  static const String biometricPromptDismissed = 'biometricPromptDismissedKey';

  /// Credentials the biometric prompt unlocks.
  static const String userPhoneNumber = 'userPhoneNumberKey';
  static const String userPassword = 'userPasswordKey';
}

/// Keychain (iOS) / EncryptedSharedPreferences (Android) wrapper.
///
/// Biometric sign in has to replay a real credential, because signing
/// out clears the Supabase session entirely and there is nothing left to
/// resume. Those credentials therefore live here, in hardware-backed
/// storage, and never in SharedPreferences.
class SecureStore {
  SecureStore(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> readString(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e, st) {
      AppLogger.w('secureStore.read failed', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> writeString(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e, st) {
      AppLogger.w('secureStore.write failed', error: e, stackTrace: st);
    }
  }

  Future<bool> readBool(String key) async =>
      (await readString(key))?.toLowerCase() == 'true';

  Future<void> writeBool(String key, bool value) =>
      writeString(key, value ? 'true' : 'false');

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e, st) {
      AppLogger.w('secureStore.delete failed', error: e, stackTrace: st);
    }
  }

  /// Wipe the biometric opt-in and everything it unlocks. Used when the
  /// driver turns biometrics off, and whenever a stored credential is
  /// found to be stale.
  Future<void> clearBiometricCredentials() async {
    await delete(SecureKeys.enableLocalLogin);
    await delete(SecureKeys.userPassword);
  }
}
