/// One admin-configured short-distance fare uplift.
///
/// Ranges are half-open `[fromKm, toKm)` — a 2.0 km trip belongs to a
/// 2–3 band, not a 1–2 band — which is exactly how the server's
/// `short_trip_uplift_pct` resolves them.
class ShortTripRate {
  const ShortTripRate({
    required this.fromKm,
    required this.toKm,
    required this.pct,
  });

  final int fromKm;
  final int toKm;
  final int pct;

  factory ShortTripRate.fromJson(Map<String, dynamic> json) {
    return ShortTripRate(
      fromKm: (json['from_km'] as num?)?.toInt() ?? 0,
      toKm: (json['to_km'] as num?)?.toInt() ?? 0,
      pct: (json['pct'] as num?)?.toInt() ?? 0,
    );
  }
}

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
    this.shortTripRates = const <ShortTripRate>[],
  });

  final int baseMinor;
  final int perKmMinor;
  final int warnPct;

  /// Distance bands that earn more than the plain base + per-km fare.
  /// Empty = every distance is priced normally.
  final List<ShortTripRate> shortTripRates;

  double get _warnFraction => warnPct / 100.0;

  /// Per-km at/above which a profile rate is "too high".
  int get highPerKmMinor => (perKmMinor * (1 + _warnFraction)).round();

  /// Per-km at/below which a profile rate is "too low".
  int get lowPerKmMinor => (perKmMinor * (1 - _warnFraction)).round();

  /// The short-trip uplift that applies to a trip of [distanceMeters],
  /// as a percentage. 0 = price normally.
  ///
  /// Mirrors the server's `short_trip_uplift_pct` exactly — including the
  /// rule that trips shorter than the lowest band inherit that band,
  /// since the shortest rides are the most underpriced of all and must
  /// not fall through the gap below the first range.
  int shortTripPctFor(int distanceMeters) {
    if (shortTripRates.isEmpty) return 0;
    final double km = distanceMeters / 1000.0;

    int lowestFrom = shortTripRates.first.fromKm;
    for (final ShortTripRate r in shortTripRates) {
      if (r.fromKm < lowestFrom) lowestFrom = r.fromKm;
    }
    if (km < lowestFrom) {
      for (final ShortTripRate r in shortTripRates) {
        if (r.fromKm == lowestFrom) return r.pct;
      }
      return 0;
    }

    for (final ShortTripRate r in shortTripRates) {
      if (km >= r.fromKm && km < r.toKm) return r.pct;
    }
    // Outside every band (a gap, or longer than the last one).
    return 0;
  }

  /// Market fare for a trip of [distanceMeters] = base + per-km × km,
  /// lifted by any short-trip rate for that distance.
  ///
  /// The uplift is applied HERE, to the mid, rather than to the band
  /// edges — that way the driver's suggested price rises along with
  /// their floor and ceiling, instead of the band merely widening.
  int marketFareMinorFor(int distanceMeters) {
    final double km = distanceMeters / 1000.0;
    final int raw = (baseMinor + perKmMinor * km).round();
    final int pct = shortTripPctFor(distanceMeters);
    if (pct <= 0) return raw;
    return (raw * (1 + pct / 100.0)).round();
  }

  factory StatePriceGuidance.fromRpc(Map<String, dynamic> json) {
    final Object? rates = json['short_trip_rates'];
    return StatePriceGuidance(
      baseMinor: (json['base_minor'] as num?)?.toInt() ?? 0,
      perKmMinor: (json['per_km_minor'] as num?)?.toInt() ?? 0,
      warnPct: (json['warn_pct'] as num?)?.toInt() ?? 0,
      shortTripRates: rates is List
          ? rates
              .whereType<Map<String, dynamic>>()
              .map(ShortTripRate.fromJson)
              .toList()
          : const <ShortTripRate>[],
    );
  }
}
