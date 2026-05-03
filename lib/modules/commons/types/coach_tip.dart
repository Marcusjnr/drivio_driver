/// Severity bucket the UI uses to theme a tip card. Maps to the
/// `severity` column returned by `get_my_coach_tips`.
enum CoachTipSeverity {
  info,
  warning,
  win;

  static CoachTipSeverity fromWire(String? wire) {
    switch (wire) {
      case 'warning':
        return CoachTipSeverity.warning;
      case 'win':
        return CoachTipSeverity.win;
      case 'info':
      default:
        return CoachTipSeverity.info;
    }
  }
}

/// One coaching tip. `code` is the stable rule identifier — analytics
/// can dedupe on it ("don't fire `low_win_rate` twice an hour"). The
/// optional CTA pair lets the client render a tap-action that the
/// router knows how to resolve.
class CoachTip {
  const CoachTip({
    required this.code,
    required this.severity,
    required this.emoji,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.ctaRoute,
  });

  final String code;
  final CoachTipSeverity severity;
  final String emoji;
  final String title;
  final String body;
  final String? ctaLabel;
  final String? ctaRoute;

  bool get hasCta => ctaLabel != null && ctaRoute != null;

  factory CoachTip.fromJson(Map<String, dynamic> json) {
    return CoachTip(
      code: json['code'] as String,
      severity: CoachTipSeverity.fromWire(json['severity'] as String?),
      emoji: (json['emoji'] as String?) ?? '💡',
      title: json['title'] as String,
      body: json['body'] as String,
      ctaLabel: json['cta_label'] as String?,
      ctaRoute: json['cta_route'] as String?,
    );
  }
}
