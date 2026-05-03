/// One review left by a passenger after a completed trip. Mirrors a
/// row in `public.driver_ratings`. The `passengerName` is denormalised
/// at read time by `list_my_recent_driver_ratings` so the UI never has
/// to do a second lookup.
class DriverRating {
  const DriverRating({
    required this.id,
    required this.tripId,
    required this.passengerId,
    required this.passengerName,
    required this.rating,
    required this.tags,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final String tripId;
  final String passengerId;
  final String passengerName;
  final int rating; // 1..5
  final List<String> tags;
  final String? comment;
  final DateTime createdAt;

  factory DriverRating.fromJson(Map<String, dynamic> json) {
    return DriverRating(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      passengerId: json['passenger_id'] as String,
      passengerName:
          (json['passenger_name'] as String?)?.trim().isNotEmpty == true
              ? json['passenger_name'] as String
              : 'Passenger',
      rating: (json['rating'] as num).toInt(),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((Object? t) => t as String)
              .toList(growable: false) ??
          const <String>[],
      comment: (json['comment'] as String?)?.trim().isEmpty == true
          ? null
          : json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Aggregated rating snapshot for the calling driver. Returned by the
/// `get_my_driver_rating_summary` RPC. All fields are optional —
/// nulls mean "no ratings yet" and the UI falls back to a neutral
/// placeholder.
class DriverRatingSummary {
  const DriverRatingSummary({
    this.average,
    this.count = 0,
    this.average30d,
    this.count30d = 0,
    this.fiveCount = 0,
    this.fourCount = 0,
    this.threeCount = 0,
    this.twoCount = 0,
    this.oneCount = 0,
  });

  /// Lifetime average. Null when [count] is 0.
  final double? average;
  final int count;

  /// Average for the trailing 30 days. Null when [count30d] is 0.
  final double? average30d;
  final int count30d;

  final int fiveCount;
  final int fourCount;
  final int threeCount;
  final int twoCount;
  final int oneCount;

  /// Distribution as a percentage (0..100) for each star bucket. Used
  /// to render the horizontal bars on the reviews page.
  List<int> get distributionPercent {
    if (count == 0) return const <int>[0, 0, 0, 0, 0];
    int pct(int n) => (n * 100 / count).round();
    return <int>[
      pct(fiveCount),
      pct(fourCount),
      pct(threeCount),
      pct(twoCount),
      pct(oneCount),
    ];
  }

  static const DriverRatingSummary empty = DriverRatingSummary();

  factory DriverRatingSummary.fromJson(Map<String, dynamic> json) {
    return DriverRatingSummary(
      average: (json['rating_avg'] as num?)?.toDouble(),
      count: (json['rating_count'] as num?)?.toInt() ?? 0,
      average30d: (json['rating_avg_30d'] as num?)?.toDouble(),
      count30d: (json['rating_count_30d'] as num?)?.toInt() ?? 0,
      fiveCount: (json['five_count'] as num?)?.toInt() ?? 0,
      fourCount: (json['four_count'] as num?)?.toInt() ?? 0,
      threeCount: (json['three_count'] as num?)?.toInt() ?? 0,
      twoCount: (json['two_count'] as num?)?.toInt() ?? 0,
      oneCount: (json['one_count'] as num?)?.toInt() ?? 0,
    );
  }
}
