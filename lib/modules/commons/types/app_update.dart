import 'package:flutter/foundation.dart';

/// One update channel row from `app_versions`, scoped to this app,
/// platform, and flavor. Same semantics as Kalabash's Remote Config
/// envelope: `minVersion` gates the blocking screen, `latestVersion`
/// the dismissable nudge, `forceUpdate` is the ops kill switch.
@immutable
class UpdateChannel {
  const UpdateChannel({
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.updateUrl,
  });

  factory UpdateChannel.fromJson(Map<String, dynamic> json) {
    return UpdateChannel(
      minVersion: (json['min_version'] as String?) ?? '0.0.0',
      latestVersion: (json['latest_version'] as String?) ?? '0.0.0',
      forceUpdate: (json['force_update'] as bool?) ?? false,
      updateUrl: (json['update_url'] as String?) ?? '',
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
  /// strings compare as 0.0.0, which fails open (never blocks).
  static UpdateCheck evaluate({
    required String currentVersion,
    required UpdateChannel channel,
  }) {
    if (channel.updateUrl.trim().isEmpty) return UpdateCheck.none;

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

/// Compares dotted numeric versions ("1.2.10" vs "1.3"). Build metadata
/// after `+` is ignored, missing segments count as 0, and non-numeric
/// segments count as 0 so a malformed remote value can never lock a
/// driver out. Returns <0, 0, or >0 like [Comparable.compareTo].
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .trim()
      .split('.')
      .map((String s) => int.tryParse(s) ?? 0)
      .toList(growable: false);

  final List<int> pa = parse(a);
  final List<int> pb = parse(b);
  final int len = pa.length > pb.length ? pa.length : pb.length;
  for (int i = 0; i < len; i++) {
    final int va = i < pa.length ? pa[i] : 0;
    final int vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}
