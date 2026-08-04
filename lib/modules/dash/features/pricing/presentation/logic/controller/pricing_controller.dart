import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/pricing_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/location/location_permission_service.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';
import 'package:drivio_driver/modules/commons/types/state_price_guidance.dart';

class PricingState {
  const PricingState({
    this.profile,
    this.guidance,
    this.isLoading = true,
    this.isSaving = false,
    this.error,
    this.lastSavedAt,
    this.permission = LocationPermState.unknown,
    this.needsLocation = false,
  });

  final PricingProfile? profile;

  /// The driver's state pricing reference (default per-km + warn %).
  /// Drives the hard per-km band. Null while loading, or when the lookup
  /// fails — the steppers are then unbounded client-side and the server
  /// clamps on save.
  final StatePriceGuidance? guidance;

  final bool isLoading;
  final bool isSaving;
  final String? error;
  final DateTime? lastSavedAt;

  /// Last observed location-permission state. Drives the copy on the
  /// location gate (ask again vs open settings).
  final LocationPermState permission;

  /// True when we cannot band the rate because the driver's state is
  /// unknown AND location permission is missing — i.e. a fresh onboard
  /// who has never granted location. The page swaps the rate controls
  /// for the location gate until this clears.
  final bool needsLocation;

  PricingState copyWith({
    PricingProfile? profile,
    StatePriceGuidance? guidance,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
    DateTime? lastSavedAt,
    LocationPermState? permission,
    bool? needsLocation,
  }) {
    return PricingState(
      profile: profile ?? this.profile,
      guidance: guidance ?? this.guidance,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      permission: permission ?? this.permission,
      needsLocation: needsLocation ?? this.needsLocation,
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
  final LocationPermissionService _perms = const LocationPermissionService();
  Timer? _debounce;
  final Map<String, dynamic> _pendingPatch = <String, dynamic>{};

  Future<void> _hydrate() async {
    try {
      final LocationPermState perm = await _perms.currentState();
      // Resolve the driver's state first so a brand-new profile seeds from
      // the local default (base fare + per-km) rather than the national
      // one. Best-effort: null just means "use the national default", and
      // it never overwrites a driver who has already set their price.
      final String? resolvedState = await _repo.resolveMyState();
      final PricingProfile p =
          await _repo.getOrCreateMyProfile(state: resolvedState);
      if (!mounted) return;

      // Fresh onboard with no location: the server has no state for this
      // driver and we have no way to find one, so any band we showed
      // would be the national default — the wrong ceiling for most
      // states. Gate the page on location instead of showing controls
      // banded against the wrong state.
      final bool stateKnown = (p.state ?? resolvedState) != null;
      if (!stateKnown && !perm.isUsable) {
        state = state.copyWith(
          profile: p,
          isLoading: false,
          permission: perm,
          needsLocation: true,
        );
        return;
      }

      state = state.copyWith(
        profile: p,
        isLoading: false,
        permission: perm,
        needsLocation: false,
      );
      // Load the state reference (default per-km + warn %) that the band
      // is computed from. The profile's stored state is the server's
      // truth (sticky across GPS failures) — prefer it over the live GPS
      // resolution, which returns null whenever there's no cached fix
      // and would silently band against the national default.
      final StatePriceGuidance? g =
          await _repo.getStateGuidance(state: p.state ?? resolvedState);
      if (!mounted || g == null) return;
      state = state.copyWith(guidance: g);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        profile: PricingProfile.platformDefault,
        error: 'Could not load pricing — using platform defaults.',
      );
    }
  }

  /// CTA on the location gate: pop the system prompt, and on a grant
  /// re-run the full hydrate so the fresh fix resolves the state, the
  /// server stamps it on the profile, and the band snaps to the right
  /// ceiling. On a refusal we just record the new permission state so
  /// the gate copy can escalate (denied → open settings).
  Future<void> allowLocation() async {
    final LocationPermState perm = await _perms.request();
    if (!mounted) return;
    state = state.copyWith(permission: perm);
    if (perm.isUsable) {
      state = state.copyWith(isLoading: true);
      await _hydrate();
    }
  }

  /// Re-check without prompting — called when the app resumes, so a
  /// grant made in system settings is picked up on return.
  Future<void> recheckLocation() async {
    if (!state.needsLocation) return;
    final LocationPermState perm = await _perms.currentState();
    if (!mounted) return;
    if (perm.isUsable) {
      state = state.copyWith(permission: perm, isLoading: true);
      await _hydrate();
    } else {
      state = state.copyWith(permission: perm);
    }
  }

  /// Deep-link for the settings-flavoured gate states.
  Future<void> openLocationSettings() {
    return state.permission == LocationPermState.serviceDisabled
        ? _perms.openLocationSettings()
        : _perms.openAppSettings();
  }

  /// Clamp a per-km edit into the state's allowed band. The band is a
  /// HARD limit, not advice: the server clamps to it on save and the
  /// rider is quoted a range that only holds because of it. Clamping in
  /// the setter means the driver simply cannot step past the edge,
  /// rather than entering a number the server silently corrects.
  ///
  /// Base fare has no setter — it is admin-owned per state and forced
  /// server-side, so there is nothing here for the driver to change.
  int _clampToBand(int value) {
    final StatePriceGuidance? g = state.guidance;
    if (g == null || g.warnPct <= 0) {
      return value;
    }
    return value.clamp(g.lowPerKmMinor, g.highPerKmMinor);
  }

  void setPerKmMinor(int v) {
    final int clamped = _clampToBand(v);
    _apply(
      next: (PricingProfile p) => p.copyWith(perKmMinor: clamped),
      serverFields: <String, dynamic>{'per_km_minor': clamped},
    );
  }

  /// Inclusive per-km bounds for the UI (slider min/max, helper text).
  /// Null when the state has no cap configured.
  ({int low, int high})? get perKmBounds {
    final StatePriceGuidance? g = state.guidance;
    if (g == null || g.warnPct <= 0) {
      return null;
    }
    return (low: g.lowPerKmMinor, high: g.highPerKmMinor);
  }

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
