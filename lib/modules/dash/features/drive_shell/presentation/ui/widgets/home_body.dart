import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/coach_tip.dart';
import 'package:drivio_driver/modules/commons/types/dashboard_summary.dart';
import 'package:drivio_driver/modules/commons/types/ride_request.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/coach_tip_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/dashboard_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/home_controller.dart';
import 'package:drivio_driver/modules/marketplace/features/feed/presentation/logic/controller/marketplace_controller.dart';
import 'package:drivio_driver/modules/marketplace/features/feed/presentation/ui/widgets/request_feed.dart';

/// Bottom-sheet body shown in [ShellMode.idle] — SCR-016 / SCR-017 /
/// SCR-018.
///
/// Three states, one sheet:
///   • Offline → "OFFLINE" eyebrow, "You're offline." headline, the
///     stat strip, and the coral "Go online" button.
///   • Online, no requests → "LIVE" eyebrow with a live dot, "Looking
///     for requests…" headline, stat strip, coach tip, "Go offline".
///   • Online, requests waiting → the request feed (its own
///     "REQUESTS NEARBY · N" header), then "Go offline".
///
/// The go-online / go-offline control now lives *in the sheet* per the
/// mockups; [onToggleOnline] is the shell's gated handler (KYC / vehicle
/// / subscription / location checks all run there).
class HomeBody extends ConsumerWidget {
  const HomeBody({
    super.key,
    required this.onToggleOnline,
    this.isToggling = false,
  });

  final VoidCallback onToggleOnline;
  final bool isToggling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HomeState state = ref.watch(homeControllerProvider);
    final DashboardState dash = ref.watch(dashboardControllerProvider);
    final DashboardSummary summary = dash.summary;
    final bool tileNotReady = !dash.hasEverLoaded;
    final bool online = state.isOnline;
    final List<RideRequest> requests = ref.watch(visibleRequestsProvider);
    final bool hasRequests = online && requests.isNotEmpty;

    return BottomSheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // ── Header: eyebrow + headline (or the requests header) ───────
          if (hasRequests)
            const RequestFeed()
          else ...<Widget>[
            _StatusHeader(online: online),
            const SizedBox(height: 16),
            _StatStrip(
              summary: summary,
              notReady: tileNotReady,
              error: dash.error,
              onRetry: () =>
                  ref.read(dashboardControllerProvider.notifier).refresh(),
            ),
            if (online) const _CoachTipSlot(),
          ],

          const SizedBox(height: 18),

          // ── The toggle — coral when offline (the action), ghost when
          // online (a quiet exit). ─────────────────────────────────────
          if (online)
            DrivioButton(
              label: isToggling ? 'Going offline…' : 'Go offline',
              variant: DrivioButtonVariant.ghost,
              disabled: isToggling,
              onPressed: onToggleOnline,
            )
          else
            DrivioButton(
              label: isToggling ? 'Going online…' : 'Go online',
              disabled: isToggling,
              onPressed: onToggleOnline,
            ),
        ],
      ),
    );
  }
}

/// Eyebrow + Marcellus headline. Offline = quiet; online = a coral
/// "LIVE" eyebrow with a pulsing dot and the "Looking for requests…"
/// headline.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (online)
          Row(
            children: <Widget>[
              LiveDot(color: context.coral),
              const SizedBox(width: 8),
              Text(
                'LIVE',
                style: AppTextStyles.eyebrow.copyWith(color: context.coral),
              ),
            ],
          )
        else
          Text(
            'OFFLINE',
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
          ),
        const SizedBox(height: 8),
        Text(
          online ? 'Looking for requests…' : "You're offline.",
          style: AppTextStyles.screenTitle.copyWith(color: context.text),
        ),
        if (!online) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Tap “Go online” to start receiving requests.',
            style: AppTextStyles.bodySm.copyWith(
              color: context.textDim,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Three equal columns — TODAY (earnings) · TRIPS · RATING — per the
/// SCR-016 / SCR-017 mockups.
class _StatStrip extends StatelessWidget {
  const _StatStrip({
    required this.summary,
    required this.notReady,
    required this.error,
    required this.onRetry,
  });

  final DashboardSummary summary;
  final bool notReady;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String today =
        notReady ? '—' : NairaFormatter.format(summary.earningsNaira);
    final String trips =
        notReady ? '—' : summary.tripsCompleted.toString();

    // Real driver rating from `driver_ratings` (avg, via the dashboard
    // RPC). Until the driver has any ratings, show an honest "New"
    // rather than a fabricated number — and drop the star, since there's
    // nothing to score yet.
    final bool hasRating = !notReady && summary.rating != null;
    final String rating = notReady
        ? '—'
        : hasRating
            ? summary.rating!
                .toStringAsFixed(1)
                .replaceAll(RegExp(r'\.0$'), '')
            : 'New';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _Stat(label: 'TODAY', value: today)),
            _StatDivider(),
            Expanded(child: _Stat(label: 'TRIPS', value: trips)),
            _StatDivider(),
            Expanded(
              child: _Stat(
                label: 'RATING',
                value: rating,
                showStar: hasRating,
              ),
            ),
          ],
        ),
        if (error != null && notReady) ...<Widget>[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRetry,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    error!,
                    style: AppTextStyles.captionSm
                        .copyWith(color: context.butter),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'TAP TO RETRY',
                  style:
                      AppTextStyles.eyebrow.copyWith(color: context.butter),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.border,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.showStar = false,
  });

  final String label;
  final String value;
  final bool showStar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTextStyles.eyebrow.copyWith(
            color: context.textDim,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            if (showStar) ...<Widget>[
              Icon(DrivioIcons.star, size: 16, color: context.butter),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.metricVal.copyWith(
                  color: showStar ? context.butter : context.text,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Slot that renders the top coach tip if one's active, or collapses to
/// nothing.
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
          // Coral eyebrow strip stands in for the old emoji — a small
          // tone-coloured square keeps the row anchored without emoji.
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: palette.text,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
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
          border: context.butter.withValues(alpha: 0.4),
          tint: context.butter.withValues(alpha: 0.08),
          text: context.butter,
        );
      case CoachTipSeverity.win:
        return (
          border: context.coral.withValues(alpha: 0.4),
          tint: context.coral.withValues(alpha: 0.08),
          text: context.coral,
        );
      case CoachTipSeverity.info:
        return (
          border: context.teal.withValues(alpha: 0.4),
          tint: context.teal.withValues(alpha: 0.08),
          text: context.teal,
        );
    }
  }
}
