import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pay_with_paystack/pay_with_paystack.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:drivio_driver/modules/commons/config/env.dart';
import 'package:drivio_driver/modules/commons/data/subscription_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
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

class PaystackActivationController
    extends StateNotifier<PaystackActivationState> {
  PaystackActivationController(this._subs, this._supabase)
      : super(const PaystackActivationState());

  final SubscriptionRepository _subs;
  final SupabaseModule _supabase;
  final Uuid _uuid = const Uuid();

  /// Triggers the Paystack checkout (or dev-mode shortcut), then activates
  /// the driver's subscription. Returns true on success.
  Future<bool> activate({
    required BuildContext context,
    required SubscriptionPlan plan,
  }) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      state = state.copyWith(
        error: 'Session expired. Please sign in again.',
      );
      return false;
    }

    state = state.copyWith(
      isProcessing: true,
      clearError: true,
      completed: false,
    );

    final String reference = 'drivio_${user.id.substring(0, 8)}_'
        '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 6)}';
    state = state.copyWith(lastReference: reference);

    // Dev-mode: skip the real Paystack call entirely.
    if (!Env.hasRealPaystackKey) {
      return _completeViaRpc();
    }

    // Real Paystack: open hosted checkout via plugin.
    try {
      await PayWithPayStack().now(
        context: context,
        secretKey: Env.paystackSecretKey,
        customerEmail: user.email ?? '',
        reference: reference,
        currency: plan.currency,
        paymentChannel: const <String>['card', 'bank_transfer'],
        amount: plan.priceMinor.toDouble(),
        callbackUrl: 'https://drivio.app/paystack/callback',
        transactionCompleted: (dynamic _) async {
          await _completeViaRpc();
        },
        transactionNotCompleted: (String reason) {
          state = state.copyWith(
            isProcessing: false,
            error: reason.isEmpty ? 'Payment was cancelled.' : reason,
          );
        },
      );
      // The plugin returns synchronously; outcome handled by callbacks above.
      return state.completed;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: "Couldn't start checkout. Try again in a moment.",
      );
      return false;
    }
  }

  Future<bool> _completeViaRpc() async {
    try {
      await _subs.activateSubscriptionDevMode();
      state = state.copyWith(isProcessing: false, completed: true);
      return true;
    } catch (_) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Payment succeeded but activation failed. Contact support.',
      );
      return false;
    }
  }
}

final StateNotifierProvider<PaystackActivationController,
        PaystackActivationState> paystackActivationControllerProvider =
    StateNotifierProvider<PaystackActivationController,
        PaystackActivationState>(
  (Ref _) => PaystackActivationController(
    locator<SubscriptionRepository>(),
    locator<SupabaseModule>(),
  ),
);
