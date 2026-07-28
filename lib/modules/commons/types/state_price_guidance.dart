/// The admin-set pricing reference for a driver's state: the default base
/// fare + per-km, plus [warnPct] — the symmetric percentage a driver's
/// price may sit away from the default before the app warns them.
///
/// Source: the `get_state_pricing_default(p_state)` RPC (falls back to the
/// national 'default' row when the state is unknown). Used two ways:
///  * Pricing screen — driver's profile per-km vs [perKmMinor].
///  * Bid composer — bid total vs the market fare for the trip
///    ([marketFareMinorFor]).
class StatePriceGuidance {
  const StatePriceGuidance({
    required this.baseMinor,
    required this.perKmMinor,
    required this.warnPct,
  });

  final int baseMinor;
  final int perKmMinor;
  final int warnPct;

  double get _warnFraction => warnPct / 100.0;

  /// Per-km at/above which a profile rate is "too high".
  int get highPerKmMinor => (perKmMinor * (1 + _warnFraction)).round();

  /// Per-km at/below which a profile rate is "too low".
  int get lowPerKmMinor => (perKmMinor * (1 - _warnFraction)).round();

  /// Market fare for a trip of [distanceMeters] = base + per-km × km.
  int marketFareMinorFor(int distanceMeters) {
    final double km = distanceMeters / 1000.0;
    return (baseMinor + perKmMinor * km).round();
  }

  factory StatePriceGuidance.fromRpc(Map<String, dynamic> json) {
    return StatePriceGuidance(
      baseMinor: (json['base_minor'] as num?)?.toInt() ?? 0,
      perKmMinor: (json['per_km_minor'] as num?)?.toInt() ?? 0,
      warnPct: (json['warn_pct'] as num?)?.toInt() ?? 0,
    );
  }
}
