/// Which time-of-day modifier (if any) is active for a given request.
enum PricingWindow { peak, night }

/// Driver's preference for trip length when filtering the marketplace
/// feed. Stored in the `preferences` jsonb on `driver_pricing_profile`
/// so it travels with the rest of the pricing config.
enum TripLengthPreference {
  /// No filter — every open request is shown.
  any,

  /// Only requests whose expected distance is ≤ short threshold (5 km).
  short,

  /// Only requests whose expected distance is ≥ long threshold (8 km).
  long;

  String get wire {
    switch (this) {
      case TripLengthPreference.any:
        return 'any';
      case TripLengthPreference.short:
        return 'short';
      case TripLengthPreference.long:
        return 'long';
    }
  }

  String get label {
    switch (this) {
      case TripLengthPreference.any:
        return 'Any trip length';
      case TripLengthPreference.short:
        return 'Short trips only';
      case TripLengthPreference.long:
        return 'Long trips only';
    }
  }

  static TripLengthPreference fromWire(Object? wire) {
    switch (wire) {
      case 'short':
        return TripLengthPreference.short;
      case 'long':
        return TripLengthPreference.long;
      case 'any':
      default:
        return TripLengthPreference.any;
    }
  }
}

class PricingProfile {
  const PricingProfile({
    required this.baseMinor,
    required this.perKmMinor,
    required this.peakMultiplier,
    required this.peakEnabled,
    required this.nightMultiplier,
    required this.nightEnabled,
    this.maxPickupKm = _kDefaultMaxPickupKm,
    this.tripLength = TripLengthPreference.any,
  });

  static const double _kDefaultMaxPickupKm = 5.0;

  // Trip-length thresholds in metres. Mirrored from the UI labels.
  static const int kShortTripMaxM = 5000;
  static const int kLongTripMinM = 8000;

  final int baseMinor;
  final int perKmMinor;
  final double peakMultiplier;
  final bool peakEnabled;
  final double nightMultiplier;
  final bool nightEnabled;

  /// Hard ceiling on pickup-leg distance from the driver. Requests
  /// whose pickup is farther than this are hidden client-side from the
  /// marketplace feed. Stored in the `preferences` jsonb.
  final double maxPickupKm;

  /// Driver-selected trip-length filter. `any` means no filter.
  /// Stored in the `preferences` jsonb.
  final TripLengthPreference tripLength;

  int get baseNaira => baseMinor ~/ 100;
  int get perKmNaira => perKmMinor ~/ 100;

  /// Compute the suggested fare in minor units for a given distance using
  /// this profile. Base + per-km only — no time-of-day modifier applied.
  /// Use [suggestFor] when you have the request's `createdAt` and want
  /// peak/night multipliers layered in.
  int suggestForDistance(int distanceMeters) {
    final double km = distanceMeters / 1000;
    return baseMinor + (perKmMinor * km).round();
  }

  /// Round a fare in minor units to the nearest ₦100. Used everywhere
  /// the driver sees a "suggestion" so we present an opinionated,
  /// recognisable number rather than a noisy haversine-derived figure
  /// like ₦2,168.60.
  static int roundToNearestNaira100(int minorUnits) {
    // Nearest ₦100 = nearest 10,000 minor units (1 ₦ = 100 minor).
    return (minorUnits / 10000).round() * 10000;
  }

  /// Computes the full suggested fare for a request, layering on the
  /// peak / night multiplier if the toggle is enabled AND the request's
  /// local hour falls in the corresponding window.
  ///
  /// Time windows match what the pricing UI advertises to the driver:
  ///   * Peak: 06:00–08:59 and 17:00–19:59 (inclusive start, exclusive end).
  ///   * Night: 22:00–04:59.
  ///
  /// Windows are evaluated against the device's local time, which for
  /// the target market (Nigeria, WAT, no DST) matches the driver's
  /// mental model of "5 PM is peak."
  int suggestFor(int distanceMeters, DateTime requestedAt) {
    final int base = suggestForDistance(distanceMeters);
    final int hour = requestedAt.toLocal().hour;
    final double mult = _activeMultiplier(hour);
    if (mult == 1.0) return base;
    return (base * mult).round();
  }

  /// Resolve which (if any) modifier applies at the given local hour.
  /// Peak takes precedence over night where the windows would touch
  /// (they don't currently overlap, but this keeps the rule explicit).
  double _activeMultiplier(int hour) {
    final bool inPeak =
        (hour >= 6 && hour < 9) || (hour >= 17 && hour < 20);
    final bool inNight = hour >= 22 || hour < 5;
    if (peakEnabled && inPeak) return peakMultiplier;
    if (nightEnabled && inNight) return nightMultiplier;
    return 1.0;
  }

  /// Which time-window currently applies for [requestedAt], or null if
  /// neither modifier is active. Used by UI to badge the suggested
  /// price (e.g. "PEAK · 1.5×").
  PricingWindow? activeWindow(DateTime requestedAt) {
    final int hour = requestedAt.toLocal().hour;
    final bool inPeak =
        (hour >= 6 && hour < 9) || (hour >= 17 && hour < 20);
    final bool inNight = hour >= 22 || hour < 5;
    if (peakEnabled && inPeak) return PricingWindow.peak;
    if (nightEnabled && inNight) return PricingWindow.night;
    return null;
  }

  /// True if [tripLength] would accept a trip with the given expected
  /// distance. `any` always accepts. Null distance is permissive — we
  /// never hide a request just because the dispatcher didn't precompute
  /// a distance.
  bool acceptsDistance(int? expectedDistanceMeters) {
    if (expectedDistanceMeters == null) return true;
    switch (tripLength) {
      case TripLengthPreference.any:
        return true;
      case TripLengthPreference.short:
        return expectedDistanceMeters <= kShortTripMaxM;
      case TripLengthPreference.long:
        return expectedDistanceMeters >= kLongTripMinM;
    }
  }

  PricingProfile copyWith({
    int? baseMinor,
    int? perKmMinor,
    double? peakMultiplier,
    bool? peakEnabled,
    double? nightMultiplier,
    bool? nightEnabled,
    double? maxPickupKm,
    TripLengthPreference? tripLength,
  }) {
    return PricingProfile(
      baseMinor: baseMinor ?? this.baseMinor,
      perKmMinor: perKmMinor ?? this.perKmMinor,
      peakMultiplier: peakMultiplier ?? this.peakMultiplier,
      peakEnabled: peakEnabled ?? this.peakEnabled,
      nightMultiplier: nightMultiplier ?? this.nightMultiplier,
      nightEnabled: nightEnabled ?? this.nightEnabled,
      maxPickupKm: maxPickupKm ?? this.maxPickupKm,
      tripLength: tripLength ?? this.tripLength,
    );
  }

  factory PricingProfile.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> prefs =
        (json['preferences'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    return PricingProfile(
      baseMinor: (json['base_minor'] as num).toInt(),
      perKmMinor: (json['per_km_minor'] as num).toInt(),
      peakMultiplier: (json['peak_multiplier'] as num).toDouble(),
      peakEnabled: json['peak_enabled'] as bool,
      nightMultiplier: (json['night_multiplier'] as num).toDouble(),
      nightEnabled: json['night_enabled'] as bool,
      maxPickupKm: (prefs['max_pickup_km'] as num?)?.toDouble() ??
          _kDefaultMaxPickupKm,
      tripLength: TripLengthPreference.fromWire(prefs['trip_length']),
    );
  }

  /// Serialise the prefs portion only — used by the repository when
  /// patching the `preferences` jsonb without touching the columnar
  /// fields.
  Map<String, dynamic> get preferencesJson => <String, dynamic>{
        'max_pickup_km': maxPickupKm,
        'trip_length': tripLength.wire,
      };

  static const PricingProfile platformDefault = PricingProfile(
    baseMinor: 60000,    // ₦600
    perKmMinor: 20000,   // ₦200/km
    peakMultiplier: 1.5,
    peakEnabled: true,
    nightMultiplier: 1.2,
    nightEnabled: false,
    maxPickupKm: _kDefaultMaxPickupKm,
    tripLength: TripLengthPreference.any,
  );
}
