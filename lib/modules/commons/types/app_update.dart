import 'package:flutter/foundation.dart';
import 'package:version/version.dart';

/// One update channel row for this app's platform, read out of Firebase
/// Remote Config (see `UpdateRepository`): `minVersion` gates the
/// blocking screen, `latestVersion` the dismissable nudge, `forceUpdate`
/// is the ops kill switch.
@immutable
class UpdateChannel {
  const UpdateChannel({
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.updateUrl,
  });

  /// Expects the per-platform object out of the Remote Config envelope:
  /// `{"min": "1.4.0", "max": "1.6.2", "forceUpdate": false,
  /// "updateUrl": "https://..."}`.
  factory UpdateChannel.fromJson(Map<String, dynamic> json) {
    return UpdateChannel(
      minVersion: (json['min'] as String?) ?? '0.0.0',
      latestVersion: (json['max'] as String?) ?? '0.0.0',
      forceUpdate: (json['forceUpdate'] as bool?) ?? false,
      updateUrl: (json['updateUrl'] as String?) ?? '',
    );
  }

  final String minVersion;
  final String latestVersion;
  final bool forceUpdate;
  final String updateUrl;
}

/// Outcome of comparing the running build against its [UpdateChannel].
enum UpdateVerdict {
  /// Below `min` or the kill switch is on. Blocking screen, no way past.
  required,

  /// At or above `min` but below `latest`. Dismissable nudge.
  recommended,

  /// Current or ahead. Nothing to show.
  none,
}

@immutable
class UpdateCheck {
  const UpdateCheck({
    required this.verdict,
    required this.currentVersion,
    required this.updateUrl,
  });

  static const UpdateCheck none = UpdateCheck(
    verdict: UpdateVerdict.none,
    currentVersion: '',
    updateUrl: '',
  );

  final UpdateVerdict verdict;
  final String currentVersion;
  final String updateUrl;

  /// Applies the channel rules to [currentVersion]. Unparseable version
  /// strings compare as equal to everything (see [compareVersions]),
  /// which fails open — never blocks.
  static UpdateCheck evaluate({
    required String currentVersion,
    required UpdateChannel channel,
  }) {
    if (channel.updateUrl.trim().isEmpty) {
      return UpdateCheck.none;
    }

    if (channel.forceUpdate ||
        compareVersions(currentVersion, channel.minVersion) < 0) {
      return UpdateCheck(
        verdict: UpdateVerdict.required,
        currentVersion: currentVersion,
        updateUrl: channel.updateUrl,
      );
    }
    if (compareVersions(currentVersion, channel.latestVersion) < 0) {
      return UpdateCheck(
        verdict: UpdateVerdict.recommended,
        currentVersion: currentVersion,
        updateUrl: channel.updateUrl,
      );
    }
    return UpdateCheck.none;
  }
}

/// Compares two version strings via `package:version` (semver). Returns
/// <0, 0, or >0 like [Comparable.compareTo]. Either string failing to
/// parse compares as 0 (equal) — a malformed remote value, or a locally
/// installed build with a non-standard version string, must never lock
/// someone out.
int compareVersions(String a, String b) {
  final Version? va = _tryParse(a);
  final Version? vb = _tryParse(b);
  if (va == null || vb == null) {
    return 0;
  }
  return va.compareTo(vb);
}

Version? _tryParse(String raw) {
  try {
    return Version.parse(raw.trim());
  } catch (_) {
    return null;
  }
}
