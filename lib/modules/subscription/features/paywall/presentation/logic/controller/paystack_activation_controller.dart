import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/analytics/analytics_events.dart';
import 'package:drivio_driver/modules/commons/analytics/mixpanel_service.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/payments/paystack_checkout.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';

class PaystackActivationState {
  const PaystackActivationState({
    this.isProcessing = false,
    this.error,
    this.lastReference,
    this.completed = false,
  });

  final bool isProcessing;
  final String? error;
  final String? lastReference;
  final bool completed;

  PaystackActivationState copyWith({
    bool? isProcessing,
    String? error,
    String? lastReference,
    bool? completed,
    bool clearError = false,
  }) {
    return PaystackActivationState(
      isProcessing: isProcessing ?? this.isProcessing,
      error: clearError ? null : (error ?? this.error),
      lastReference: lastReference ?? this.lastReference,
      completed: completed ?? this.completed,
    );
  }
}

/// Drives subscription purchase via server-side Paystack:
/// `paystack-initialize` (prices the plan server-side + opens hosted
/// checkout) → WebView → `paystack-verify` (confirms with Paystack and
/// activates the subscription). The secret key never touches the app, and
/// the subscription only activates after the server confirms the payment.
class PaystackActivationController
    extends StateNotifier<PaystackActivationState> {
  PaystackActivationController(this._supabase)
    : super(const PaystackActivationState());

  final SupabaseModule _supabase;
  late final PaystackCheckout _checkout = PaystackCheckout(_supabase);

  /// Runs the Paystack checkout for [plan], then activates the driver's
  /// subscription server-side. Returns true on a verified payment.
  Future<bool> activate({
    required BuildContext context,
    required SubscriptionPlan plan,
  }) async {
    if (_supabase.auth.currentUser == null) {
      state = state.copyWith(error: 'Session expired. Please sign in again.');
      return false;
    }

    state = state.copyWith(
      isProcessing: true,
      clearError: true,
      completed: false,
    );

    final MixpanelService mp = locator<MixpanelService>();
    final Map<String, dynamic> planProps = <String, dynamic>{
      'subscription_plan': plan.interval.tierName.toLowerCase(),
      'subscription_amount': plan.priceNaira,
    };
    mp.track(
      AnalyticsEvents.subscriptionPaymentInitiated,
      properties: planProps,
    );

    final PaystackResult result = await _checkout.run(
      context: context,
      purpose: 'subscription',
      planCode: plan.code,
    );

    switch (result.outcome) {
      case PaystackOutcome.success:
        mp.track(
          AnalyticsEvents.subscriptionPurchased,
          properties: planProps,
        );
        state = state.copyWith(
          isProcessing: false,
          completed: true,
          lastReference: result.reference,
        );
        return true;
      case PaystackOutcome.cancelled:
        state = state.copyWith(
          isProcessing: false,
          lastReference: result.reference,
        );
        return false;
      case PaystackOutcome.failed:
      case PaystackOutcome.error:
        state = state.copyWith(
          isProcessing: false,
          lastReference: result.reference,
          error: result.message ?? 'Payment failed. Try again.',
        );
        return false;
    }
  }
}

final StateNotifierProvider<
  PaystackActivationController,
  PaystackActivationState
>
paystackActivationControllerProvider =
    StateNotifierProvider<
      PaystackActivationController,
      PaystackActivationState
    >((Ref _) => PaystackActivationController(locator<SupabaseModule>()));
