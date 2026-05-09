import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/passenger_rating_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/passenger_rating.dart';

class PassengerRatingState {
  const PassengerRatingState({
    this.tripId,
    this.rating = 0,
    this.tags = const <String>{},
    this.existing,
    this.isLoading = false,
    this.isSubmitting = false,
    this.submitted = false,
    this.error,
  });

  final String? tripId;
  final int rating;
  final Set<String> tags;
  final PassengerRating? existing;
  final bool isLoading;
  final bool isSubmitting;
  final bool submitted;
  final String? error;

  bool get canSubmit => rating >= 1 && rating <= 5 && !isSubmitting;

  PassengerRatingState copyWith({
    String? tripId,
    int? rating,
    Set<String>? tags,
    PassengerRating? existing,
    bool? isLoading,
    bool? isSubmitting,
    bool? submitted,
    String? error,
    bool clearError = false,
  }) {
    return PassengerRatingState(
      tripId: tripId ?? this.tripId,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
      existing: existing ?? this.existing,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitted: submitted ?? this.submitted,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PassengerRatingController extends StateNotifier<PassengerRatingState> {
  PassengerRatingController({
    required String tripId,
    required PassengerRatingRepository repo,
  })  : _repo = repo,
        super(PassengerRatingState(tripId: tripId, isLoading: true)) {
    _hydrate();
  }

  final PassengerRatingRepository _repo;

  Future<void> _hydrate() async {
    try {
      final PassengerRating? existing =
          await _repo.getMyRatingForTrip(state.tripId!);
      if (!mounted) return;
      state = state.copyWith(
        existing: existing,
        isLoading: false,
        rating: existing?.rating ?? 0,
        tags: existing?.tags.toSet() ?? const <String>{},
        submitted: existing != null,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  void setRating(int v) =>
      state = state.copyWith(rating: v.clamp(1, 5), clearError: true);

  void toggleTag(String tag) {
    final Set<String> next = Set<String>.from(state.tags);
    if (next.contains(tag)) {
      next.remove(tag);
    } else {
      next.add(tag);
    }
    state = state.copyWith(tags: next);
  }

  Future<bool> submit() async {
    if (!state.canSubmit || state.tripId == null) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.submit(
        tripId: state.tripId!,
        rating: state.rating,
        tags: state.tags.toList(growable: false),
      );
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false, submitted: true);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        error: "Couldn't submit your rating. Try again in a moment.",
      );
      return false;
    }
  }
}

final passengerRatingControllerProvider = StateNotifierProvider.autoDispose
    .family<PassengerRatingController, PassengerRatingState, String>(
  (Ref ref, String tripId) => PassengerRatingController(
    tripId: tripId,
    repo: locator<PassengerRatingRepository>(),
  ),
);
