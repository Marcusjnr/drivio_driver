/// Motion duration tokens per brand spec §9.2.
///
/// Personality is **calm + considered** — slightly slower than default,
/// no springs or elasticity. Curves pair with these durations:
///   - In:  `Curves.easeOutQuart`
///   - Out: `Curves.easeInQuart`
///
/// Never use bounce / elastic / spring — Drivio is not a candy app
/// (anti-pattern §9.3).
class AppDurations {
  AppDurations._();

  /// 160ms. Tap feedback, ink ripple.
  static const Duration fast = Duration(milliseconds: 160);

  /// 280ms. Standard transitions, button-state, hover.
  static const Duration base = Duration(milliseconds: 280);

  /// 400ms. Sheet open/close, banner enter.
  static const Duration slow = Duration(milliseconds: 400);

  /// 1800ms. Halo glow under hero elements (pulse, brand mark).
  static const Duration breathe = Duration(milliseconds: 1800);

  /// 1500ms. Live-dot pulse, splash radar.
  static const Duration ping = Duration(milliseconds: 1500);
}
