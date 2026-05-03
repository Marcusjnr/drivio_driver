/// Snapshot of "today" tile metrics returned by the
/// `get_my_dashboard_today` RPC. Times are evaluated server-side in
/// Africa/Lagos so the day-boundary lines up with what a Nigerian
/// driver intuitively expects ("midnight resets the counters").
class DashboardSummary {
  const DashboardSummary({
    required this.earningsMinor,
    required this.tripsCompleted,
    required this.onlineSeconds,
    this.rating,
    this.ratingCount,
  });

  /// Sum of completed-trip fares today in minor units (kobo).
  final int earningsMinor;

  /// Count of trips that finished today (state = 'completed').
  final int tripsCompleted;

  /// Best-effort proxy for "time spent driving today" — currently the
  /// sum of completed-trip durations. Will be replaced by a proper
  /// online-session table once we wire `toggleOnline` to record
  /// start/end stamps.
  final int onlineSeconds;

  /// Aggregated driver rating. Null until the driver-ratings feature
  /// ships; UI falls back to a tasteful default.
  final double? rating;

  /// How many ratings contributed to [rating]. Null when [rating] is
  /// null.
  final int? ratingCount;

  int get earningsNaira => earningsMinor ~/ 100;

  /// Online time in fractional hours, rounded to one decimal — matches
  /// what the home tile renders ("5.2h").
  double get onlineHours {
    if (onlineSeconds <= 0) return 0;
    return (onlineSeconds / 3600 * 10).round() / 10;
  }

  static const DashboardSummary empty = DashboardSummary(
    earningsMinor: 0,
    tripsCompleted: 0,
    onlineSeconds: 0,
  );

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      earningsMinor: (json['earnings_minor'] as num?)?.toInt() ?? 0,
      tripsCompleted: (json['trips_completed'] as num?)?.toInt() ?? 0,
      onlineSeconds: (json['online_seconds'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt(),
    );
  }
}
