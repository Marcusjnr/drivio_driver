import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/driver_amenities_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';

class DriverAmenitiesState {
  const DriverAmenitiesState({
    this.options = const <AmenityOption>[],
    this.selected = const <String>{},
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<AmenityOption> options;
  final Set<String> selected;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  DriverAmenitiesState copyWith({
    List<AmenityOption>? options,
    Set<String>? selected,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return DriverAmenitiesState(
      options: options ?? this.options,
      selected: selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DriverAmenitiesController extends StateNotifier<DriverAmenitiesState> {
  DriverAmenitiesController(this._repo)
      : super(const DriverAmenitiesState(isLoading: true)) {
    _hydrate();
  }

  final DriverAmenitiesRepository _repo;

  Future<void> _hydrate() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<AmenityOption> options = await _repo.catalog();
      final List<String> mine = await _repo.myCodes();
      if (!mounted) return;
      state = state.copyWith(
        options: options,
        selected: mine.toSet(),
        isLoading: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Couldn\'t load amenities. Try again in a moment.',
      );
    }
  }

  void toggle(String code) {
    final Set<String> next = <String>{...state.selected};
    if (!next.remove(code)) next.add(code);
    state = state.copyWith(selected: next, clearError: true);
  }

  Future<bool> save() async {
    if (state.isSaving) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final List<String> saved =
          await _repo.setMyCodes(state.selected.toList(growable: false));
      if (!mounted) return false;
      state = state.copyWith(selected: saved.toSet(), isSaving: false);
      return true;
    } catch (_) {
      if (!mounted) return false;
      state = state.copyWith(
        isSaving: false,
        error: 'Couldn\'t save. Try again in a moment.',
      );
      return false;
    }
  }
}

final StateNotifierProvider<DriverAmenitiesController, DriverAmenitiesState>
    driverAmenitiesControllerProvider =
    StateNotifierProvider<DriverAmenitiesController, DriverAmenitiesState>(
  (Ref _) => DriverAmenitiesController(locator<DriverAmenitiesRepository>()),
);
