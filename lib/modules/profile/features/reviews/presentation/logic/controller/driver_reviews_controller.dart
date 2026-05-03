import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/driver_rating_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/driver_rating.dart';

class DriverReviewsState {
  const DriverReviewsState({
    this.summary = DriverRatingSummary.empty,
    this.reviews = const <DriverRating>[],
    this.isLoading = true,
    this.error,
  });

  final DriverRatingSummary summary;
  final List<DriverRating> reviews;
  final bool isLoading;
  final String? error;

  DriverReviewsState copyWith({
    DriverRatingSummary? summary,
    List<DriverRating>? reviews,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DriverReviewsState(
      summary: summary ?? this.summary,
      reviews: reviews ?? this.reviews,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Loads the driver's aggregated rating summary + recent reviews in
/// parallel. Single round-trip on mount; explicit pull-to-refresh
/// re-runs both.
class DriverReviewsController extends StateNotifier<DriverReviewsState> {
  DriverReviewsController(this._repo) : super(const DriverReviewsState()) {
    _hydrate();
  }

  final DriverRatingRepository _repo;

  Future<void> refresh() => _hydrate();

  Future<void> _hydrate() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[
        _repo.getMySummary(),
        _repo.listMyRecent(),
      ]);
      if (!mounted) return;
      state = state.copyWith(
        summary: r[0] as DriverRatingSummary,
        reviews: r[1] as List<DriverRating>,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load reviews.',
      );
    }
  }
}

final StateNotifierProvider<DriverReviewsController, DriverReviewsState>
    driverReviewsControllerProvider =
    StateNotifierProvider<DriverReviewsController, DriverReviewsState>(
  (Ref _) =>
      DriverReviewsController(locator<DriverRatingRepository>()),
);
