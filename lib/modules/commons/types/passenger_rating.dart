/// Curated tag set for post-trip passenger ratings. Stored as text[] in
/// `passenger_ratings.tags`; new tags can be added in the future without
/// a migration since the column is unconstrained.
const List<String> kPassengerRatingTags = <String>[
  'Friendly',
  'On time',
  'Polite',
  'Late pickup',
  'Messy',
  'Unsafe',
  'No-show',
  'Other',
];

class PassengerRating {
  const PassengerRating({
    required this.rating,
    required this.tags,
    this.comment,
  });

  final int rating;
  final List<String> tags;
  final String? comment;

  factory PassengerRating.fromJson(Map<String, dynamic> json) {
    return PassengerRating(
      rating: (json['rating'] as num).toInt(),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((dynamic e) => e as String)
              .toList(growable: false) ??
          const <String>[],
      comment: json['comment'] as String?,
    );
  }
}
