import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/subscription_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/errors/error_messages.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';

class SubscriptionState {
  const SubscriptionState({
    this.subscription,
    this.plans = const <SubscriptionPlan>[],
    this.isLoading = false,
    this.isMutating = false,
    this.error,
  });

  final Subscription? subscription;
  final List<SubscriptionPlan> plans;
  final bool isLoading;
  final bool isMutating;
  final String? error;

  SubscriptionPlan? get featuredPlan {
    if (plans.isEmpty) return null;
    if (subscription?.planId != null) {
      for (final SubscriptionPlan p in plans) {
        if (p.id == subscription!.planId) return p;
      }
    }
    return plans.first;
  }

  bool get isTrialing => subscription?.isTrialing ?? false;
  bool get isPaused => subscription?.isPaused ?? false;
  bool get unlocksMarketplace =>
      subscription?.status.unlocksMarketplace ?? false;
  bool get canPause => subscription?.status.canPause ?? false;

  SubscriptionState copyWith({
    Subscription? subscription,
    List<SubscriptionPlan>? plans,
    bool? isLoading,
    bool? isMutating,
    String? error,
    bool clearError = false,
    bool clearSubscription = false,
  }) {
    return SubscriptionState(
      subscription:
          clearSubscription ? null : (subscription ?? this.subscription),
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController(this._repo) : super(const SubscriptionState());

  final SubscriptionRepository _repo;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final List<SubscriptionPlan> plans = await _repo.listActivePlans();
      final Subscription? sub = await _repo.getMySubscription();
      state = state.copyWith(
        subscription: sub,
        clearSubscription: sub == null,
        plans: plans,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: "Couldn't load your subscription. Pull down to retry.",
      );
    }
  }

  /// Returns true on success. Friendly errors land on `state.error`.
  Future<bool> pause() async {
    if (state.isMutating) return false;
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repo.pauseMine();
      await refresh();
      if (!mounted) return false;
      state = state.copyWith(isMutating: false);
      return true;
    } catch (e, s) {
      AppLogger.e('Pause subscription failed', error: e, stackTrace: s);
      if (!mounted) return false;
      state = state.copyWith(
        isMutating: false,
        error: humaniseError(
          e,
          fallback: "Couldn't pause right now. Try again in a moment.",
        ),
      );
      return false;
    }
  }

  Future<bool> resume() async {
    if (state.isMutating) return false;
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repo.resumeMine();
      await refresh();
      if (!mounted) return false;
      state = state.copyWith(isMutating: false);
      return true;
    } catch (e, s) {
      AppLogger.e('Resume subscription failed', error: e, stackTrace: s);
      if (!mounted) return false;
      state = state.copyWith(
        isMutating: false,
        error: humaniseError(
          e,
          fallback: "Couldn't resume right now. Try again in a moment.",
        ),
      );
      return false;
    }
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final StateNotifierProvider<SubscriptionController, SubscriptionState>
    subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>(
  (Ref _) => SubscriptionController(locator<SubscriptionRepository>()),
);
