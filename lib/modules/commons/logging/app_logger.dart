import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Project-wide logger. Single instance; pass through `AppLogger.d` /
/// `AppLogger.i` / `AppLogger.w` / `AppLogger.e` from anywhere.
///
/// Output is silenced in release builds so we don't ship verbose logs
/// to production drivers — debug + profile only.
///
/// Usage:
/// ```dart
/// AppLogger.i('Sub gate fired', data: <String, dynamic>{
///   'driver_id': uid,
///   'status': sub.status.toString(),
/// });
/// ```
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    filter: _ReleaseFilter(),
    printer: PrettyPrinter(
      methodCount: 0,           // hide stack on info/debug — too noisy
      errorMethodCount: 8,      // full stack on errors
      lineLength: 100,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Verbose detail — request payloads, intermediate values.
  static void d(String message, {Map<String, dynamic>? data}) {
    _logger.d(_format(message, data));
  }

  /// Notable lifecycle event — controller hydrate, RPC call, sign-in.
  static void i(String message, {Map<String, dynamic>? data}) {
    _logger.i(_format(message, data));
  }

  /// Recoverable issue — retry triggered, fallback used, soft failure.
  static void w(String message,
      {Map<String, dynamic>? data, Object? error, StackTrace? stackTrace}) {
    _logger.w(_format(message, data), error: error, stackTrace: stackTrace);
  }

  /// Hard failure — RPC threw, parsing crashed, state corrupted.
  static void e(String message,
      {Map<String, dynamic>? data, Object? error, StackTrace? stackTrace}) {
    _logger.e(_format(message, data), error: error, stackTrace: stackTrace);
  }

  static String _format(String message, Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return message;
    final String pairs = data.entries
        .map((MapEntry<String, dynamic> e) => '${e.key}=${e.value}')
        .join(' · ');
    return '$message  ›  $pairs';
  }
}

/// Strip everything in release builds. We still want logs in profile
/// mode for on-device diagnostics, but production drivers never see
/// verbose output.
class _ReleaseFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) return false;
    return event.level.value >= level!.value;
  }
}
