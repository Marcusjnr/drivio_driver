import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/coach_tip.dart';
import 'package:drivio_driver/modules/commons/types/dashboard_summary.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/coach_tip_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/dashboard_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/home_controller.dart';
import 'package:drivio_driver/modules/marketplace/features/feed/presentation/ui/widgets/request_feed.dart';

/// Bottom-sheet body shown in [ShellMode.idle].
class HomeBody extends ConsumerWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeState state = ref.watch(homeControllerProvider);
    final DashboardState dash = ref.watch(dashboardControllerProvider);
    final DashboardSummary summary = dash.summary;
    // Distinguish "first load is still pending" from "loaded and
    // genuinely zero today". Without this, a transient cold-start
    // failure shows ₦0/0/0h for a full minute with no signal.
    final bool tileNotReady = !dash.hasEverLoaded;

    return BottomSheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "TODAY'S EARNINGS",
                      style: AppTextStyles.eyebrow
                          .copyWith(color: context.textDim),
                    ),
                    const SizedBox(height: 2),
                    // Loading placeholder is "—" rather than ₦0 so the
                    // first paint after sign-in doesn't flash a real-
                    // looking zero before the RPC resolves.
                    Text(
                      tileNotReady
                          ? '—'
                          : NairaFormatter.format(summary.earningsNaira),
                      style: AppTextStyles.displayLg.copyWith(
                        color: context.accent,
                      ),
                    ),
                    if (dash.error != null && tileNotReady) ...<Widget>[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => ref
                            .read(dashboardControllerProvider.notifier)
                            .refresh(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                dash.error!,
                                style: AppTextStyles.captionSm.copyWith(
                                  fontSize: 11,
                                  color: context.amber,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TAP TO RETRY',
                              style: AppTextStyles.eyebrow
                                  .copyWith(color: context.amber),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (tileNotReady)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: context.accent.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniMetric(
                  value: tileNotReady
                      ? '—'
                      : summary.tripsCompleted.toString(),
                  label: 'Trips',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  value: tileNotReady
                      ? '—'
                      : '${_fmtHours(summary.onlineHours)}h',
                  label: 'Online',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  // Falls back to the home controller's seed when no
                  // ratings exist yet, so the tile is never blank.
                  value: tileNotReady
                      ? '—'
                      : (summary.rating ?? state.rating)
                          .toStringAsFixed(1)
                          .replaceAll(RegExp(r'\.0$'), ''),
                  label: 'Rating',
                  showStar: true,
                ),
              ),
            ],
          ),
          // DRV-074: surface the highest-priority coaching tip just
          // below the metrics. Sits between the tile and the request
          // feed so it catches the eye without burying the requests.
          const _CoachTipSlot(),
          if (state.isOnline) ...<Widget>[
            const SizedBox(height: 14),
            const RequestFeed(),
          ],
        ],
      ),
    );
  }

  /// Hours: integer when round (`5h`), one decimal otherwise (`5.2h`).
  /// Avoids `5.0h` which reads worse than `5h`.
  static String _fmtHours(double h) {
    if (h == h.roundToDouble()) return h.toStringAsFixed(0);
    return h.toStringAsFixed(1);
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.value,
    required this.label,
    this.showStar = false,
  });

  final String value;
  final String label;
  final bool showStar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: AppRadius.md,
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (showStar) ...<Widget>[
                Icon(DrivioIcons.star, size: 14, color: context.amber),
                const SizedBox(width: 2),
              ],
              Text(
                value,
                style: AppTextStyles.h2.copyWith(
                  color: showStar ? context.amber : context.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.eyebrow.copyWith(
              color: context.textDim,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Slot that renders the top coach tip if one's active, or collapses
/// to nothing. Splitting it out keeps the parent build leaner and
/// avoids rebuilding the rest of the bottom sheet when a tip
/// dismisses.
class _CoachTipSlot extends ConsumerWidget {
  const _CoachTipSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CoachTipState state = ref.watch(coachTipControllerProvider);
    if (state.isLoading || state.visible.isEmpty) {
      return const SizedBox.shrink();
    }
    final CoachTip tip = state.visible.first;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _CoachTipCard(
        tip: tip,
        onDismiss: () =>
            ref.read(coachTipControllerProvider.notifier).dismiss(tip.code),
        onCta: tip.hasCta
            ? () => AppNavigation.push(tip.ctaRoute!)
            : null,
      ),
    );
  }
}

class _CoachTipCard extends StatelessWidget {
  const _CoachTipCard({
    required this.tip,
    required this.onDismiss,
    this.onCta,
  });

  final CoachTip tip;
  final VoidCallback onDismiss;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final ({Color border, Color tint, Color text}) palette = _palette(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: palette.tint,
        borderRadius: AppRadius.md,
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(tip.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tip.title,
                  style: AppTextStyles.caption.copyWith(
                    color: context.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tip.body,
                  style: AppTextStyles.captionSm.copyWith(
                    color: context.textDim,
                    height: 1.4,
                  ),
                ),
                if (onCta != null) ...<Widget>[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onCta,
                    child: Text(
                      '${tip.ctaLabel} →',
                      style: AppTextStyles.captionSm.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: context.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  ({Color border, Color tint, Color text}) _palette(BuildContext context) {
    switch (tip.severity) {
      case CoachTipSeverity.warning:
        return (
          border: context.amber.withValues(alpha: 0.4),
          tint: context.amber.withValues(alpha: 0.08),
          text: context.amber,
        );
      case CoachTipSeverity.win:
        return (
          border: context.accent.withValues(alpha: 0.4),
          tint: context.accent.withValues(alpha: 0.08),
          text: context.accent,
        );
      case CoachTipSeverity.info:
        return (
          border: context.blue.withValues(alpha: 0.4),
          tint: context.blue.withValues(alpha: 0.08),
          text: context.blue,
        );
    }
  }
}

