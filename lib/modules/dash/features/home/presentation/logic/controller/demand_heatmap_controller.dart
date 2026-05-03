import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/demand_heatmap_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/demand_cell.dart';

class DemandHeatmapState {
  const DemandHeatmapState({
    this.cells = const <DemandCell>[],
    this.visible = false,
    this.lastFetchedAt,
    this.error,
  });

  final List<DemandCell> cells;

  /// Toggle controlled by the driver via the map's heatmap button.
  /// Hidden by default so the map starts clean.
  final bool visible;

  final DateTime? lastFetchedAt;
  final String? error;

  /// Maximum request count among loaded cells — used to normalise the
  /// per-cell colour intensity in the overlay renderer.
  int get maxCount {
    if (cells.isEmpty) return 0;
    int m = 0;
    for (final DemandCell c in cells) {
      if (c.requestCount > m) m = c.requestCount;
    }
    return m;
  }

  DemandHeatmapState copyWith({
    List<DemandCell>? cells,
    bool? visible,
    DateTime? lastFetchedAt,
    String? error,
    bool clearError = false,
  }) {
    return DemandHeatmapState(
      cells: cells ?? this.cells,
      visible: visible ?? this.visible,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the demand-heatmap overlay. Spec says refresh every 5 min;
/// we also re-fetch on toggle-on so the first paint after a long
/// hide window isn't stale.
class DemandHeatmapController extends StateNotifier<DemandHeatmapState> {
  DemandHeatmapController(this._repo) : super(const DemandHeatmapState()) {
    _ticker = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        if (state.visible) _hydrate();
      },
    );
  }

  final DemandHeatmapRepository _repo;
  Timer? _ticker;

  /// Show the overlay and pull a fresh snapshot. Subsequent ticks
  /// from the 5-minute timer keep it current while it's visible.
  Future<void> show() async {
    state = state.copyWith(visible: true);
    await _hydrate();
  }

  void hide() {
    state = state.copyWith(visible: false);
  }

  Future<void> toggle() async {
    if (state.visible) {
      hide();
    } else {
      await show();
    }
  }

  Future<void> _hydrate() async {
    try {
      final List<DemandCell> cells = await _repo.getHeatmap();
      if (!mounted) return;
      state = state.copyWith(
        cells: cells,
        lastFetchedAt: DateTime.now(),
        clearError: true,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(error: 'Could not refresh heatmap.');
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final StateNotifierProvider<DemandHeatmapController, DemandHeatmapState>
    demandHeatmapControllerProvider =
    StateNotifierProvider<DemandHeatmapController, DemandHeatmapState>(
  (Ref _) =>
      DemandHeatmapController(locator<DemandHeatmapRepository>()),
);
