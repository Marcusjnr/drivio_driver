import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/subscription_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/errors/error_messages.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/types/subscription.dart';

/// How the driver arrived at the Pick a Plan screen. Drives the CTA copy
/// ("Continue · pay X today" vs "Queue switch") and the back-button policy
/// (no back button on hard-expired entries).
enum PickPlanIntent {
  /// New driver picking their first tier at trial end (or any time during
  /// trial — drivers can pick early to lock in a tier).
  trialChoice,

  /// Driver whose subscription expired and is re-subscribing.
  reactivation,

  /// Driver on an active tier switching to a different one. Confirms a
  /// queued switch (`pending_plan_id`); takes effect at next renewal.
  tierSwitch,
}

/// Recommendation produced from the driver's recent activity. The reason
/// string is shown verbatim in the recommendation banner.
@immutable
class PlanRecommendation {
  const PlanRecommendation({
    required this.tierCode,
    required this.reason,
    required this.activeDays,
    required this.observedDays,
  });

  final String tierCode;
  final String reason;
  final int activeDays;
  final int observedDays;

  /// Tier code → human framing. The reason is one sentence, italicised
  /// in the banner. We keep the phrasing literary, never salesy.
  static PlanRecommendation fromActivity({
    required int activeDays,
    required int observedDays,
  }) {
    if (observedDays <= 0) {
      return const PlanRecommendation(
        tierCode: 'drivio_pro_monthly',
        reason: 'Most drivers on Drivio start with Monthly — the cheapest '
            'per-day rate, and you can switch anytime.',
        activeDays: 0,
        observedDays: 0,
      );
    }
    final double ratio = activeDays / observedDays;
    if (ratio >= 0.9) {
      return PlanRecommendation(
        tierCode: 'drivio_pro_monthly',
        reason:
            'You bid on $activeDays of $observedDays days. **Monthly** is your cheapest option.',
        activeDays: activeDays,
        observedDays: observedDays,
      );
    }
    if (ratio >= 0.6) {
      return PlanRecommendation(
        tierCode: 'drivio_pro_weekly',
        reason:
            'You bid on $activeDays of $observedDays days. **Weekly fits your pattern.**',
        activeDays: activeDays,
        observedDays: observedDays,
      );
    }
    return PlanRecommendation(
      tierCode: 'drivio_pro_daily',
      reason:
          'You bid on $activeDays of $observedDays days. **Daily** lets you only pay on days you drive.',
      activeDays: activeDays,
      observedDays: observedDays,
    );
  }
}

@immutable
class PickPlanState {
  const PickPlanState({
    this.intent = PickPlanIntent.trialChoice,
    this.tiers = const <SubscriptionPlan>[],
    this.recommendation,
    this.selectedTierCode,
    this.currentTierCode,
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  /// Why the driver is here. Controls CTA copy and exit policy.
  final PickPlanIntent intent;

  /// The three tiers, ordered Daily → Weekly → Monthly. We always render
  /// in this order so the visual rhythm stays predictable.
  final List<SubscriptionPlan> tiers;

  /// Personalised tier recommendation. Null while loading or when no
  /// activity history exists.
  final PlanRecommendation? recommendation;

  /// Driver's current selection. Defaults to [recommendation.tierCode]
  /// once available, then to monthly as a safe fallback.
  final String? selectedTierCode;

  /// The tier the driver is currently subscribed to, if any. Used only
  /// in the [PickPlanIntent.tierSwitch] flow to label "CURRENT" and
  /// prevent picking the same tier.
  final String? currentTierCode;

  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  SubscriptionPlan? get selectedTier {
    if (selectedTierCode == null) return null;
    for (final SubscriptionPlan p in tiers) {
      if (p.code == selectedTierCode) return p;
    }
    return null;
  }

  bool get hasTiers => tiers.isNotEmpty;
  bool get canSubmit => selectedTier != null && !isSubmitting;

  PickPlanState copyWith({
    PickPlanIntent? intent,
    List<SubscriptionPlan>? tiers,
    PlanRecommendation? recommendation,
    String? selectedTierCode,
    String? currentTierCode,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    bool clearRecommendation = false,
    bool clearSelection = false,
    bool clearCurrentTier = false,
    bool clearError = false,
  }) {
    return PickPlanState(
      intent: intent ?? this.intent,
      tiers: tiers ?? this.tiers,
      recommendation:
          clearRecommendation ? null : (recommendation ?? this.recommendation),
      selectedTierCode:
          clearSelection ? null : (selectedTierCode ?? this.selectedTierCode),
      currentTierCode: clearCurrentTier
          ? null
          : (currentTierCode ?? this.currentTierCode),
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PickPlanController extends StateNotifier<PickPlanState> {
  PickPlanController(this._repo) : super(const PickPlanState());

  final SubscriptionRepository _repo;

  /// Loads the 3 active tiers + driver's recent activity, picks a
  /// recommendation, and pre-selects it.
  Future<void> hydrate({
    required PickPlanIntent intent,
    String? currentTierCode,
  }) async {
    state = state.copyWith(
      intent: intent,
      currentTierCode: currentTierCode,
      clearCurrentTier: currentTierCode == null,
      isLoading: true,
      clearError: true,
    );
    try {
      final List<SubscriptionPlan> plans = await _repo.listActivePlans();
      // Sort Daily → Weekly → Monthly. Renders predictably regardless of
      // the server's order.
      final List<SubscriptionPlan> ordered = <SubscriptionPlan>[
        ..._tierByInterval(plans, SubscriptionInterval.day),
        ..._tierByInterval(plans, SubscriptionInterval.week),
        ..._tierByInterval(plans, SubscriptionInterval.month),
      ];

      // Best-effort activity fetch. Failures fall through to the
      // "no history" recommendation (Monthly default).
      int activeDays = 0;
      int observedDays = 0;
      try {
        final Map<String, int> a = await _repo.getMyTrialActivity();
        activeDays = a['active_days'] ?? 0;
        observedDays = a['observed_days'] ?? 0;
      } catch (e, s) {
        AppLogger.w('Trial activity fetch failed', error: e, stackTrace: s);
      }

      final PlanRecommendation rec = PlanRecommendation.fromActivity(
        activeDays: activeDays,
        observedDays: observedDays,
      );

      // Pre-select the recommended tier — unless the driver is mid-switch
      // and we'd be pre-selecting their current tier (a no-op). In that
      // case, pick the next reasonable tier so they have a meaningful
      // initial choice.
      String? preselect = rec.tierCode;
      if (intent == PickPlanIntent.tierSwitch &&
          preselect == currentTierCode) {
        preselect = _nextReasonableTier(ordered, currentTierCode!);
      }

      state = state.copyWith(
        tiers: ordered,
        recommendation: rec,
        selectedTierCode: preselect,
        isLoading: false,
      );
    } catch (e, s) {
      AppLogger.e('Pick Plan hydrate failed', error: e, stackTrace: s);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: humaniseError(
          e,
          fallback: "Couldn't load plans. Pull down to retry.",
        ),
      );
    }
  }

  void selectTier(String code) {
    if (state.selectedTierCode == code) return;
    state = state.copyWith(selectedTierCode: code);
  }

  /// Queue a tier switch for the active subscription. Used by the
  /// [PickPlanIntent.tierSwitch] flow. Returns true on success.
  ///
  /// The new tier activates at the driver's next renewal anniversary;
  /// nothing is charged today. Errors are humanised onto state.error
  /// so the page can surface them inline.
  Future<bool> queueSwitch({
    required String subscriptionId,
    required String targetPlanCode,
  }) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.queueTierSwitch(
        subscriptionId: subscriptionId,
        targetPlanCode: targetPlanCode,
        reason: 'driver_initiated_via_pick_plan',
      );
      if (!mounted) return true;
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e, s) {
      AppLogger.e('Queue tier switch failed', error: e, stackTrace: s);
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        error: humaniseError(
          e,
          fallback: "Couldn't queue your switch. Try again in a moment.",
        ),
      );
      return false;
    }
  }

  /// Cancel a queued tier switch. Used by the Subscription Manage page's
  /// pending-switch banner. Returns true on success.
  Future<bool> cancelPendingSwitch({required String subscriptionId}) async {
    if (state.isSubmitting) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.cancelPendingTierSwitch(subscriptionId: subscriptionId);
      if (!mounted) return true;
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e, s) {
      AppLogger.e('Cancel pending switch failed', error: e, stackTrace: s);
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        error: humaniseError(
          e,
          fallback: "Couldn't cancel the switch. Try again in a moment.",
        ),
      );
      return false;
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  static Iterable<SubscriptionPlan> _tierByInterval(
    List<SubscriptionPlan> plans,
    SubscriptionInterval interval,
  ) sync* {
    for (final SubscriptionPlan p in plans) {
      if (p.interval == interval) yield p;
    }
  }

  /// When the driver's recommended tier IS their current tier (mid-switch
  /// flow), fall back to the next tier up — Daily → Weekly → Monthly →
  /// Daily (wrap). It's a sensible default that the driver can easily
  /// change.
  static String _nextReasonableTier(
    List<SubscriptionPlan> tiers,
    String currentCode,
  ) {
    final int idx = tiers.indexWhere((SubscriptionPlan p) => p.code == currentCode);
    if (idx == -1) return tiers.first.code;
    final int next = (idx + 1) % tiers.length;
    return tiers[next].code;
  }
}

final StateNotifierProvider<PickPlanController, PickPlanState>
    pickPlanControllerProvider =
    StateNotifierProvider<PickPlanController, PickPlanState>(
  (Ref ref) => PickPlanController(locator<SubscriptionRepository>()),
);
