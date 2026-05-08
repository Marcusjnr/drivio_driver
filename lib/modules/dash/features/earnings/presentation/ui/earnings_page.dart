import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/wallet.dart';
import 'package:drivio_driver/modules/dash/features/earnings/presentation/logic/controller/wallet_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/driver_tab_bar.dart';

class EarningsPage extends ConsumerStatefulWidget {
  const EarningsPage({super.key});

  @override
  ConsumerState<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends ConsumerState<EarningsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(walletControllerProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final WalletState state = ref.watch(walletControllerProvider);
    final WalletController c = ref.read(walletControllerProvider.notifier);

    // Build the chart data + axis labels per the active period.
    //   * Week: 7 daily bars, single-letter day initials
    //   * Month: 30 daily bars, day-of-month digits but only every 5th
    //     to keep the axis legible
    //   * Year: 12 monthly bars labelled with the month initial
    final (List<int> bars, List<String> labels) = _chartData(state);
    final int highlight = bars.isEmpty ? -1 : bars.length - 1;

    return ScreenScaffold(
      bottomBar: const DriverTabBar(active: DriverTab.earnings),
      child: RefreshIndicator(
        onRefresh: c.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Earnings',
                    style: AppTextStyles.h1.copyWith(color: context.text),
                  ),
                  _SegmentedTabs(
                    period: state.period,
                    onPeriodChanged: c.setPeriod,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BalanceCard(state: state),
              const SizedBox(height: 18),
              Text(
                state.period.sectionLabel,
                style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: AppRadius.base,
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              NairaFormatter.format(state.periodNetNaira),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: context.accent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${state.periodTripCount} trip${state.periodTripCount == 1 ? '' : 's'} in ${state.period.tripFooterSuffix}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textDim,
                              ),
                            ),
                          ],
                        ),
                        const Pill(text: 'live · realtime', tone: PillTone.accent),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 80,
                      child: AnimatedOpacity(
                        // Faint loading state during a period switch so
                        // the chart doesn't blink when the new bars
                        // arrive a frame later.
                        opacity: state.isPeriodLoading ? 0.4 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: _Bars(values: bars, highlight: highlight),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children:
                          List<Widget>.generate(labels.length, (int i) {
                        final bool active = i == highlight;
                        return Expanded(
                          child: Center(
                            child: Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: active
                                    ? context.accent
                                    : context.textMuted,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'RECENT ACTIVITY',
                    style:
                        AppTextStyles.eyebrow.copyWith(color: context.textDim),
                  ),
                  if (state.entries.length > 8)
                    Text(
                      'showing ${state.entries.length > 20 ? 20 : state.entries.length}',
                      style: TextStyle(fontSize: 11, color: context.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (state.isLoading && state.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.entries.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: AppRadius.md,
                    border: Border.all(color: context.border),
                  ),
                  child: Center(
                    child: Text(
                      'No transactions yet. Complete a trip to see your first credit.',
                      textAlign: TextAlign.center,
                      style:
                          AppTextStyles.bodySm.copyWith(color: context.textDim),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: AppRadius.md,
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0;
                          i < state.entries.length && i < 20;
                          i++) ...<Widget>[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: context.border,
                          ),
                        _LedgerRow(entry: state.entries[i]),
                      ],
                    ],
                  ),
                ),
              if (state.error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  state.error!,
                  style: AppTextStyles.bodySm.copyWith(color: context.red),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'YOUR BUSINESS',
                style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  _MetricCard(
                    label: 'Avg fare',
                    value: state.periodTripCount > 0
                        ? NairaFormatter.format(
                            state.summary!.tripCreditsNaira ~/
                                state.periodTripCount,
                          )
                        : NairaFormatter.format(0),
                    delta: state.period.tripFooterSuffix,
                  ),
                  _MetricCard(
                    label: 'Trips',
                    value: state.periodTripCount.toString(),
                    delta: state.period.tripFooterSuffix,
                  ),
                  _MetricCard(
                    label: 'Win rate',
                    value: state.acceptance?.winRate == null
                        ? '—'
                        : '${(state.acceptance!.winRate! * 100).round()}%',
                    delta: state.acceptance == null
                        ? state.period.tripFooterSuffix
                        : '${state.acceptance!.bidsWon}/${state.acceptance!.bidsSubmitted} bids',
                  ),
                  _MetricCard(
                    label: 'Cancel rate',
                    value: state.acceptance?.cancelRate == null
                        ? '—'
                        : '${(state.acceptance!.cancelRate! * 100).round()}%',
                    delta: state.acceptance == null
                        ? state.period.tripFooterSuffix
                        : '${state.acceptance!.tripsCancelledByDriver}/${state.acceptance!.tripsAssigned} trips',
                    deltaPositive: (state.acceptance?.cancelRate ?? 0) <= 0.05,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.state});
  final WalletState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            context.accent.withValues(alpha: 0.18),
            context.accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppRadius.lg,
        border: Border.all(color: context.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'WALLET BALANCE',
            style: AppTextStyles.eyebrow.copyWith(color: context.accent),
          ),
          const SizedBox(height: 4),
          Text(
            NairaFormatter.format(state.balanceNaira),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              color: context.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.wallet == null
                ? 'No payouts yet'
                : 'Updated ${_relativeTime(state.wallet!.updatedAt)}',
            style: TextStyle(fontSize: 12, color: context.textDim),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: DrivioButton(
                  label: 'Withdraw',
                  variant: DrivioButtonVariant.accent,
                  disabled: state.balanceNaira < 5000,
                  onPressed: () {
                    AppNotifier.info(
                      message:
                          "Withdrawals run via Paystack — coming soon.",
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DrivioButton(
                  label: 'History',
                  variant: DrivioButtonVariant.ghost,
                  onPressed: () {
                    // Scrolls into view by virtue of being on the same page.
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime then) {
    final Duration delta = DateTime.now().difference(then);
    if (delta.inSeconds < 30) return 'just now';
    if (delta.inMinutes < 1) return '${delta.inSeconds}s ago';
    if (delta.inHours < 1) return '${delta.inMinutes} min ago';
    if (delta.inDays < 1) return '${delta.inHours} h ago';
    if (delta.inDays < 7) return '${delta.inDays} d ago';
    return '${then.year}-${then.month.toString().padLeft(2, '0')}-${then.day.toString().padLeft(2, '0')}';
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final bool credit = entry.kind.isCredit;
    final Color tone = credit ? context.accent : context.red;
    final String sign = credit ? '+' : '−';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _emojiFor(entry.kind),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _labelFor(entry.kind),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.description ?? _fmtTime(entry.createdAt),
                  style: TextStyle(fontSize: 11, color: context.textDim),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '$sign${NairaFormatter.format(entry.amountMinor ~/ 100)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _fmtTime(entry.createdAt),
                style: TextStyle(fontSize: 10, color: context.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _emojiFor(LedgerKind kind) {
    switch (kind) {
      case LedgerKind.tripCredit:
        return '🚗';
      case LedgerKind.payoutDebit:
        return '🏦';
      case LedgerKind.refund:
        return '↩️';
      case LedgerKind.adjustment:
        return '⚖️';
      case LedgerKind.subscriptionDebit:
        return '💳';
      case LedgerKind.unknown:
        return '•';
    }
  }

  static String _labelFor(LedgerKind kind) {
    switch (kind) {
      case LedgerKind.tripCredit:
        return 'Trip credit';
      case LedgerKind.payoutDebit:
        return 'Payout';
      case LedgerKind.refund:
        return 'Refund';
      case LedgerKind.adjustment:
        return 'Adjustment';
      case LedgerKind.subscriptionDebit:
        return 'Subscription';
      case LedgerKind.unknown:
        return 'Activity';
    }
  }

  static String _fmtTime(DateTime t) {
    final DateTime now = DateTime.now();
    final Duration d = now.difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}

/// Stateless period switcher. The controller owns the active period;
/// this widget just renders the segments and forwards taps so the
/// chart and headline numbers all stay in sync.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.period, required this.onPeriodChanged});

  final EarningsPeriod period;
  final ValueChanged<EarningsPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    const List<({String label, EarningsPeriod period})> tabs =
        <({String label, EarningsPeriod period})>[
      (label: 'Week', period: EarningsPeriod.week),
      (label: 'Month', period: EarningsPeriod.month),
      (label: 'Year', period: EarningsPeriod.year),
    ];
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final ({String label, EarningsPeriod period}) t in tabs)
            GestureDetector(
              onTap: () => onPeriodChanged(t.period),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      t.period == period ? context.surface3 : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  t.label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: t.period == period
                        ? context.text
                        : context.textDim,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Resolves the chart's bar values + axis labels from the active
/// period's data. Empty windows return placeholder bars so the layout
/// is stable.
(List<int>, List<String>) _chartData(WalletState state) {
  const List<String> dayInitials = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const List<String> monthInitials = <String>[
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
  ];
  switch (state.period) {
    case EarningsPeriod.week:
      if (state.daily.isEmpty) {
        return (List<int>.filled(7, 0), dayInitials);
      }
      return (
        state.daily.map((DailyEarning d) => d.netNaira).toList(),
        state.daily
            .map((DailyEarning d) => dayInitials[(d.day.weekday - 1) % 7])
            .toList(),
      );
    case EarningsPeriod.month:
      if (state.daily.isEmpty) {
        return (List<int>.filled(30, 0), List<String>.filled(30, ''));
      }
      // Showing 30 axis labels would be unreadable; show every 5th
      // day's day-of-month, blank the rest.
      final List<String> labels = <String>[];
      for (int i = 0; i < state.daily.length; i++) {
        final int isLast = i == state.daily.length - 1 ? 1 : 0;
        labels.add(
          (i % 5 == 0 || isLast == 1) ? '${state.daily[i].day.day}' : '',
        );
      }
      return (
        state.daily.map((DailyEarning d) => d.netNaira).toList(),
        labels,
      );
    case EarningsPeriod.year:
      if (state.monthly.isEmpty) {
        return (List<int>.filled(12, 0), monthInitials);
      }
      return (
        state.monthly.map((MonthlyEarning m) => m.netNaira).toList(),
        state.monthly
            .map((MonthlyEarning m) => monthInitials[(m.month.month - 1) % 12])
            .toList(),
      );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.values, required this.highlight});
  final List<int> values;
  final int highlight;

  @override
  Widget build(BuildContext context) {
    // Use only positive values for the scale: net-zero or net-debit days
    // (e.g. payouts) collapse to a flat baseline rather than rendering as
    // negative heights or NaN.
    final int max = values.fold<int>(
      0,
      (int acc, int v) => v > acc ? v : acc,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(values.length, (int i) {
        final double h = max <= 0
            ? 0.04 // baseline so the bar is still visible
            : ((values[i] / max).clamp(0.04, 1.0)).toDouble();
        final bool active = i == highlight;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FractionallySizedBox(
              heightFactor: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: active ? context.accent : context.surface4,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.delta,
    this.deltaPositive = true,
  });

  final String label;
  final String value;
  final String delta;
  final bool deltaPositive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.metricVal.copyWith(color: context.text),
          ),
          const SizedBox(height: 4),
          Text(
            delta,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: deltaPositive ? context.accent : context.amber,
            ),
          ),
        ],
      ),
    );
  }
}
