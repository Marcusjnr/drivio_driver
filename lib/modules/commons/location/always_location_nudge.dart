import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether to nudge the driver toward "Allow all the time"
/// background location, and remembers that we asked.
///
/// Why this exists: since Android 11 (API 30) the OS no longer lets an
/// app pop the "Allow all the time" dialog in-app — the only path to
/// background location is the system Settings screen. So after the driver
/// goes online with merely "while in use", we show a one-time rationale
/// and deep-link them to Settings. "Always" isn't required for tracking
/// while the app is backgrounded (a foreground-started location service
/// keeps running); it adds the reboot-restart capability.
///
/// iOS is excluded: there the significant-location manager calls
/// `requestAlwaysAuthorization`, which DOES surface the system upgrade
/// prompt, so no Settings detour is needed.
class AlwaysLocationNudge {
  AlwaysLocationNudge._();

  static const String _prefKey = 'presence_always_nudge_shown';

  /// True when we should show the nudge: Android only, the driver has
  /// foreground-but-not-background location, and we haven't asked before.
  static Future<bool> shouldShow() async {
    if (!Platform.isAndroid) {
      return false;
    }
    final LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always) {
      return false; // already granted — nothing to nudge.
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) ?? false) {
      return false; // asked once already.
    }
    return true;
  }

  /// Remember that we've shown the nudge so it never auto-appears again.
  static Future<void> markShown() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Open the app's system settings page, from which the driver taps
  /// Permissions → Location → "Allow all the time".
  static Future<bool> openSettings() => Geolocator.openAppSettings();
}
