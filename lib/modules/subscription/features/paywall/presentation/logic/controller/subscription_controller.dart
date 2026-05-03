import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/subscription_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';

class SubscriptionState {
  const SubscriptionState({
    this.subscription,
    this.plans = const <SubscriptionPlan>[],
    this.isLoading = false,
    this.error,
  });

  final Subscription? subscription;
  final List<SubscriptionPlan> plans;
  final bool isLoading;
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
  bool get unlocksMarketplace =>
      subscription?.status.unlocksMarketplace ?? false;

  SubscriptionState copyWith({
    Subscription? subscription,
    List<SubscriptionPlan>? plans,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSubscription = false,
  }) {
    return SubscriptionState(
      subscription:
          clearSubscription ? null : (subscription ?? this.subscription),
      plans: plans ?? this.plans,
      isLoading: isLoading ?? this.isLoading,
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
        error: 'Could not load your subscription.',
      );
    }
  }
}

final StateNotifierProvider<SubscriptionController, SubscriptionState>
    subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>(
  (Ref _) => SubscriptionController(locator<SubscriptionRepository>()),
);
