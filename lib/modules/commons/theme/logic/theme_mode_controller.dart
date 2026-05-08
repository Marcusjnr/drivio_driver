import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Driver-app theme mode. Default: dark — drivers spend most of the day
/// in mixed lighting and dark surfaces with mint accents read better
/// behind a windscreen.
///
/// User-selected mode is persisted via SharedPreferences and restored
/// asynchronously on app boot. The dark default is the source-of-truth
/// initial value so the first frame always matches the brand without
/// waiting on disk I/O.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.dark) {
    _restore();
  }

  static const String _kPrefKey = 'drivio_driver_theme_mode';

  Future<void> _restore() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_kPrefKey);
      final ThemeMode? next = _deserialize(raw);
      if (next != null && next != state) {
        state = next;
      }
    } catch (_) {
      // Persisted value missing or corrupt — keep the dark default.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefKey, _serialize(mode));
    } catch (_) {
      // Best-effort persistence; failure here is silent — the in-memory
      // state still reflects the user's choice this session.
    }
  }

  Future<void> toggle() => setMode(
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      );

  Future<void> followSystem() => setMode(ThemeMode.system);

  static String _serialize(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode? _deserialize(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }
}

final StateNotifierProvider<ThemeModeController, ThemeMode> themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (Ref ref) => ThemeModeController(),
);
