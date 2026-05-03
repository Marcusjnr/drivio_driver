import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/pricing_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';

class PricingState {
  const PricingState({
    this.profile,
    this.isLoading = true,
    this.isSaving = false,
    this.error,
    this.lastSavedAt,
  });

  final PricingProfile? profile;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final DateTime? lastSavedAt;

  PricingState copyWith({
    PricingProfile? profile,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
    DateTime? lastSavedAt,
  }) {
    return PricingState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }
}

/// Local-edit + debounced-save controller. Edits update the in-memory
/// `profile` immediately; a 500ms debounce timer flushes the pending
/// patch to the server. Multiple edits inside the window collapse into
/// a single round-trip.
class PricingController extends StateNotifier<PricingState> {
  PricingController(this._repo) : super(const PricingState()) {
    _hydrate();
  }

  final PricingRepository _repo;
  Timer? _debounce;
  final Map<String, dynamic> _pendingPatch = <String, dynamic>{};

  Future<void> _hydrate() async {
    try {
      final PricingProfile p = await _repo.getOrCreateMyProfile();
      if (!mounted) return;
      state = state.copyWith(profile: p, isLoading: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        profile: PricingProfile.platformDefault,
        error: 'Could not load pricing — using platform defaults.',
      );
    }
  }

  void setBaseMinor(int v) => _apply(
        next: (PricingProfile p) => p.copyWith(baseMinor: v),
        serverFields: <String, dynamic>{'base_minor': v},
      );

  void setPerKmMinor(int v) => _apply(
        next: (PricingProfile p) => p.copyWith(perKmMinor: v),
        serverFields: <String, dynamic>{'per_km_minor': v},
      );

  void setPeakMultiplier(double v) => _apply(
        next: (PricingProfile p) => p.copyWith(peakMultiplier: v),
        serverFields: <String, dynamic>{'peak_multiplier': v},
      );

  void setPeakEnabled(bool v) => _apply(
        next: (PricingProfile p) => p.copyWith(peakEnabled: v),
        serverFields: <String, dynamic>{'peak_enabled': v},
      );

  void setNightMultiplier(double v) => _apply(
        next: (PricingProfile p) => p.copyWith(nightMultiplier: v),
        serverFields: <String, dynamic>{'night_multiplier': v},
      );

  void setNightEnabled(bool v) => _apply(
        next: (PricingProfile p) => p.copyWith(nightEnabled: v),
        serverFields: <String, dynamic>{'night_enabled': v},
      );

  void setMaxPickupKm(double v) => _apply(
        next: (PricingProfile p) => p.copyWith(maxPickupKm: v),
        serverFields: <String, dynamic>{'max_pickup_km': v},
      );

  void setTripLength(TripLengthPreference v) => _apply(
        next: (PricingProfile p) => p.copyWith(tripLength: v),
        serverFields: <String, dynamic>{'trip_length': v.wire},
      );

  /// Update local state immediately, queue the server patch, and arm
  /// the debounce. The same instance method handles every editable
  /// field — each setter just provides the in-memory transform plus
  /// the wire-side keys to flush.
  void _apply({
    required PricingProfile Function(PricingProfile) next,
    required Map<String, dynamic> serverFields,
  }) {
    final PricingProfile current =
        state.profile ?? PricingProfile.platformDefault;
    state = state.copyWith(profile: next(current));

    _pendingPatch.addAll(serverFields);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _flush);
  }

  Future<void> _flush() async {
    if (_pendingPatch.isEmpty) return;
    final Map<String, dynamic> patch =
        Map<String, dynamic>.from(_pendingPatch);
    _pendingPatch.clear();
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final PricingProfile saved = await _repo.updateMyProfile(
        baseMinor: patch['base_minor'] as int?,
        perKmMinor: patch['per_km_minor'] as int?,
        peakMultiplier: patch['peak_multiplier'] as double?,
        peakEnabled: patch['peak_enabled'] as bool?,
        nightMultiplier: patch['night_multiplier'] as double?,
        nightEnabled: patch['night_enabled'] as bool?,
        maxPickupKm: patch['max_pickup_km'] as double?,
        tripLength: patch['trip_length'] == null
            ? null
            : TripLengthPreference.fromWire(patch['trip_length']),
      );
      if (!mounted) return;
      state = state.copyWith(
        profile: saved,
        isSaving: false,
        lastSavedAt: DateTime.now(),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isSaving: false,
        error: 'Could not save — your edits will retry on the next change.',
      );
      // Re-queue the patch so the next edit retries everything.
      _pendingPatch.addAll(patch);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<PricingController, PricingState>
    pricingControllerProvider =
    StateNotifierProvider<PricingController, PricingState>(
  (Ref _) => PricingController(locator<PricingRepository>()),
);
