import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/profile_repository.dart';
import 'package:drivio_driver/modules/commons/data/profile_summary_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/commons/types/driver_rating.dart';
import 'package:drivio_driver/modules/commons/types/profile.dart';
import 'package:drivio_driver/modules/commons/types/profile_summary.dart';
import 'package:drivio_driver/modules/commons/types/vehicle.dart';
import 'package:drivio_driver/modules/commons/data/driver_rating_repository.dart';
import 'package:drivio_driver/modules/dash/features/add_vehicle/presentation/logic/data/vehicle_repository.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

class ProfileHubState {
  const ProfileHubState({
    this.profile,
    this.summary = ProfileSummary.empty,
    this.activeVehicle,
    this.documentsByKind = const <DocumentKind, Document>{},
    this.topReview,
    this.isLoading = true,
    this.error,
  });

  final Profile? profile;
  final ProfileSummary summary;

  /// The driver's `status='active'` vehicle, if any. Null when no
  /// vehicle exists or none are active. Used in VEHICLE group.
  final Vehicle? activeVehicle;

  /// Most recent document per kind, looked up by `documents.kind`.
  /// Lets the UI render real status next to "Driver's licence",
  /// "Vehicle registration" etc. without a per-row fetch.
  final Map<DocumentKind, Document> documentsByKind;

  /// Top (most recent) review used as the preview card on the hub.
  /// Null when the driver has no reviews yet.
  final DriverRating? topReview;

  final bool isLoading;
  final String? error;

  ProfileHubState copyWith({
    Profile? profile,
    ProfileSummary? summary,
    Vehicle? activeVehicle,
    bool clearActiveVehicle = false,
    Map<DocumentKind, Document>? documentsByKind,
    DriverRating? topReview,
    bool clearTopReview = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ProfileHubState(
      profile: profile ?? this.profile,
      summary: summary ?? this.summary,
      activeVehicle:
          clearActiveVehicle ? null : (activeVehicle ?? this.activeVehicle),
      documentsByKind: documentsByKind ?? this.documentsByKind,
      topReview: clearTopReview ? null : (topReview ?? this.topReview),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the profile-hub bottom sheet's data. Loads everything in
/// parallel on mount; supports an explicit refresh from pull-to-refresh.
class ProfileHubController extends StateNotifier<ProfileHubState> {
  ProfileHubController({
    required ProfileRepository profile,
    required ProfileSummaryRepository summary,
    required VehicleRepository vehicles,
    required KycRepository kyc,
    required DriverRatingRepository ratings,
  })  : _profile = profile,
        _summary = summary,
        _vehicles = vehicles,
        _kyc = kyc,
        _ratings = ratings,
        super(const ProfileHubState()) {
    _hydrate();
  }

  final ProfileRepository _profile;
  final ProfileSummaryRepository _summary;
  final VehicleRepository _vehicles;
  final KycRepository _kyc;
  final DriverRatingRepository _ratings;

  Future<void> refresh() => _hydrate();

  Future<void> _hydrate() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<dynamic> r = await Future.wait<dynamic>(<Future<dynamic>>[
        _profile.getMyProfile(),
        _summary.getMyProfileSummary(),
        _vehicles.listMyVehicles(),
        _kyc.loadSnapshot(),
        _ratings.listMyRecent(limit: 1),
      ]);
      if (!mounted) return;

      final List<Vehicle> mine = r[2] as List<Vehicle>;
      final Vehicle? active = mine
          .where((Vehicle v) => v.status == VehicleStatus.active)
          .cast<Vehicle?>()
          .firstWhere((Vehicle? _) => true, orElse: () => null);

      final KycSnapshot snap = r[3] as KycSnapshot;
      // Latest doc per kind — the snapshot returns full history; we
      // care about the most recent record per kind for the row label.
      final Map<DocumentKind, Document> latest =
          <DocumentKind, Document>{};
      for (final Document d in snap.documents) {
        final Document? prev = latest[d.kind];
        if (prev == null || d.createdAt.isAfter(prev.createdAt)) {
          latest[d.kind] = d;
        }
      }

      final List<DriverRating> reviews = r[4] as List<DriverRating>;

      state = state.copyWith(
        profile: r[0] as Profile?,
        summary: r[1] as ProfileSummary,
        activeVehicle: active,
        clearActiveVehicle: active == null,
        documentsByKind: latest,
        topReview: reviews.isEmpty ? null : reviews.first,
        clearTopReview: reviews.isEmpty,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load your profile: $e',
      );
    }
  }
}

final StateNotifierProvider<ProfileHubController, ProfileHubState>
    profileHubControllerProvider =
    StateNotifierProvider<ProfileHubController, ProfileHubState>(
  (Ref _) => ProfileHubController(
    profile: locator<ProfileRepository>(),
    summary: locator<ProfileSummaryRepository>(),
    vehicles: locator<VehicleRepository>(),
    kyc: locator<KycRepository>(),
    ratings: locator<DriverRatingRepository>(),
  ),
);
