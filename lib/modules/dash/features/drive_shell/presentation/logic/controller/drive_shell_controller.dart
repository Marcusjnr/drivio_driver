import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the driver is currently doing inside the shell. Drives map markers,
/// top overlays, and which body the bottom sheet morphs to.
///
/// Two terminal states (`tripCompleted`, `tripCancelled`) keep the body on
/// screen briefly after the trip ends so the driver sees their earnings /
/// the cancellation reason before the shell flips back to idle.
enum ShellMode {
  idle,
  bidding,
  trip,
  tripCompleted,
  tripCancelled,
}

class DriveShellState {
  const DriveShellState({
    this.mode = ShellMode.idle,
    this.activeRequestId,
    this.activeTripId,
  });

  final ShellMode mode;

  /// Set when [mode] is [ShellMode.bidding].
  final String? activeRequestId;

  /// Set when [mode] is [ShellMode.trip], [tripCompleted], or [tripCancelled].
  final String? activeTripId;

  bool get isIdle => mode == ShellMode.idle;
  bool get isBidding => mode == ShellMode.bidding;
  bool get isTripLike =>
      mode == ShellMode.trip ||
      mode == ShellMode.tripCompleted ||
      mode == ShellMode.tripCancelled;

  DriveShellState copyWith({
    ShellMode? mode,
    String? activeRequestId,
    String? activeTripId,
    bool clearActiveRequestId = false,
    bool clearActiveTripId = false,
  }) {
    return DriveShellState(
      mode: mode ?? this.mode,
      activeRequestId: clearActiveRequestId
          ? null
          : (activeRequestId ?? this.activeRequestId),
      activeTripId:
          clearActiveTripId ? null : (activeTripId ?? this.activeTripId),
    );
  }
}

class DriveShellController extends StateNotifier<DriveShellState> {
  DriveShellController() : super(const DriveShellState());

  void enterBidding(String requestId) {
    state = state.copyWith(
      mode: ShellMode.bidding,
      activeRequestId: requestId,
    );
  }

  void exitBidding() {
    if (!state.isBidding) return;
    state = state.copyWith(
      mode: ShellMode.idle,
      clearActiveRequestId: true,
    );
  }

  void enterTrip(String tripId) {
    state = state.copyWith(
      mode: ShellMode.trip,
      activeTripId: tripId,
      clearActiveRequestId: true,
    );
  }

  /// Called by the trip controller when a trip transitions to a terminal
  /// state. Keeps the shell on the trip's terminal body until [exitTrip]
  /// fires (typically when the driver taps "Back online").
  void onTripCompleted() {
    if (state.mode == ShellMode.trip) {
      state = state.copyWith(mode: ShellMode.tripCompleted);
    }
  }

  void onTripCancelled() {
    if (state.mode == ShellMode.trip) {
      state = state.copyWith(mode: ShellMode.tripCancelled);
    }
  }

  void exitTrip() {
    if (!state.isTripLike) return;
    state = state.copyWith(
      mode: ShellMode.idle,
      clearActiveTripId: true,
    );
  }

  void resetToIdle() {
    state = state.copyWith(
      mode: ShellMode.idle,
      clearActiveRequestId: true,
      clearActiveTripId: true,
    );
  }
}

final StateNotifierProvider<DriveShellController, DriveShellState>
    driveShellControllerProvider =
    StateNotifierProvider<DriveShellController, DriveShellState>(
  (Ref _) => DriveShellController(),
);
