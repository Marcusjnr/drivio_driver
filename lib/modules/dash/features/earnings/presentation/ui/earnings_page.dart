import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/wallet.dart';
import 'package:drivio_driver/modules/dash/features/earnings/presentation/logic/controller/wallet_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/driver_tab_bar.dart';

/// SCR-031 / SCR-032 — Earnings.
///
/// Layout follows the mockups: Marcellus title, a full-width
/// WEEK/MONTH/YEAR segment control, a coral earnings hero, a 2×2 metric
/// grid (avg fare / trips / accept rate / cancel rate), and a bar chart
/// with a y-axis. The wallet balance card is kept on top and the
/// transaction ledger below (per product decision — the mockups omit
/// both, but we don't want to strand withdrawals or history).
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
    final _Hero hero = _heroFor(state);

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
              Text(
                'Earnings',
                style: AppTextStyles.screenTitle.copyWith(color: context.text),
              ),
              const SizedBox(height: 16),
              _SegmentedTabs(
                period: state.period,
                onPeriodChanged: c.setPeriod,
              ),
              const SizedBox(height: 18),

              // Wallet balance (kept on top per decision).
              _BalanceCard(state: state),
              const SizedBox(height: 22),

              // Earnings hero.
              Text(
                hero.eyebrow,
                style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
              ),
              const SizedBox(height: 6),
              Text(
                NairaFormatter.format(hero.net),
                style: AppTextStyles.priceHero.copyWith(
                  fontSize: 48,
                  letterSpacing: -1.4,
                  color: context.coral,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hero.sub,
                style: AppTextStyles.bodySm.copyWith(color: context.textDim),
              ),
              const SizedBox(height: 18),

              // Metric grid.
              _MetricGrid(state: state),
              const SizedBox(height: 18),

              // Chart.
              _ChartCard(state: state),
              const SizedBox(height: 22),

              // Ledger (kept below per decision).
              _LedgerSection(state: state),

              if (state.error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  state.error!,
                  style: AppTextStyles.bodySm.copyWith(color: context.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Hero figure per period. Week shows *today*; month/year show the
  /// period total — matching SCR-031 ("TODAY") and SCR-032 ("THIS MONTH").
  _Hero _heroFor(WalletState s) {
    String plural(int n) => n == 1 ? 'trip' : 'trips';
    switch (s.period) {
      case EarningsPeriod.week:
        final DailyEarning? today =
            s.daily.isNotEmpty ? s.daily.last : null;
        final int net = today?.netNaira ?? 0;
        final int trips = today?.tripCount ?? 0;
        return _Hero(
          eyebrow: 'TODAY',
          net: net,
          sub: 'Today, across $trips ${plural(trips)}',
        );
      case EarningsPeriod.month:
        return _Hero(
          eyebrow: 'THIS MONTH',
          net: s.periodNetNaira,
          sub: 'This month, across ${s.periodTripCount} '
              '${plural(s.periodTripCount)}',
        );
      case EarningsPeriod.year:
        return _Hero(
          eyebrow: 'THIS YEAR',
          net: s.periodNetNaira,
          sub: 'This year, across ${s.periodTripCount} '
              '${plural(s.periodTripCount)}',
        );
    }
  }
}

class _Hero {
  const _Hero({required this.eyebrow, required this.net, required this.sub});
  final String eyebrow;
  final int net;
  final String sub;
}

/// Full-width WEEK / MONTH / YEAR segment control — coral fill on the
/// active segment, plain text otherwise.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.period, required this.onPeriodChanged});

  final EarningsPeriod period;
  final ValueChanged<EarningsPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    const List<({String label, EarningsPeriod period})> tabs =
        <({String label, EarningsPeriod period})>[
      (label: 'WEEK', period: EarningsPeriod.week),
      (label: 'MONTH', period: EarningsPeriod.month),
      (label: 'YEAR', period: EarningsPeriod.year),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          for (final ({String label, EarningsPeriod period}) t in tabs)
            Expanded(
              child: GestureDetector(
                onTap: () => onPeriodChanged(t.period),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutQuart,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: t.period == period
                        ? context.coral
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t.label,
                    style: AppTextStyles.buttonSm.copyWith(
                      color: t.period == period
                          ? context.coralInk
                          : context.textDim,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 2×2 metric grid: avg fare / trips / accept rate / cancel rate, each
/// with a leading icon, per the mockups.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.state});
  final WalletState state;

  @override
  Widget build(BuildContext context) {
    final int trips = state.periodTripCount;
    final String avgFare = trips > 0 && state.summary != null
        ? NairaFormatter.format(state.summary!.tripCreditsNaira ~/ trips)
        : NairaFormatter.format(0);
    final String accept = state.acceptance?.winRate == null
        ? '—'
        : '${(state.acceptance!.winRate! * 100).round()}%';
    final String cancel = state.acceptance?.cancelRate == null
        ? '—'
        : '${(state.acceptance!.cancelRate! * 100).round()}%';

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        _MetricCard(
          icon: DrivioIcons.card,
          label: 'AVG FARE',
          value: avgFare,
        ),
        _MetricCard(
          icon: DrivioIcons.car,
          label: 'TRIPS',
          value: trips.toString(),
        ),
        _MetricCard(
          icon: DrivioIcons.checkCircle,
          label: 'ACCEPT RATE',
          value: accept,
        ),
        _MetricCard(
          icon: Icons.cancel_outlined,
          label: 'CANCEL RATE',
          value: cancel,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: context.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: context.textDim),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style:
                      AppTextStyles.eyebrow.copyWith(color: context.textDim),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: AppTextStyles.metricVal.copyWith(color: context.text),
          ),
        ],
      ),
    );
  }
}

/// The bar chart card with a y-axis, per SCR-031/032.
class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.state});
  final WalletState state;

  @override
  Widget build(BuildContext context) {
    final (List<int> bars, List<String> labels) = _chartData(state);
    final int rawMax = bars.fold<int>(0, (int a, int v) => v > a ? v : a);
    final int niceMax = _niceMax(rawMax);
    // Four y-axis ticks: 0, 1/3, 2/3, max.
    final List<int> ticks = <int>[
      niceMax,
      (niceMax * 2 / 3).round(),
      (niceMax / 3).round(),
      0,
    ];
    final String header = state.period == EarningsPeriod.week
        ? 'THIS WEEK'
        : 'EARNINGS OVER TIME';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
            children: <Widget>[
              Text(
                header,
                style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
              ),
              Text(
                NairaFormatter.format(state.periodNetNaira),
                style: AppTextStyles.h3.copyWith(color: context.text),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedOpacity(
            opacity: state.isPeriodLoading ? 0.4 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: SizedBox(
              height: 132,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Y-axis tick labels.
                  SizedBox(
                    width: 30,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        for (final int t in ticks)
                          Text(
                            _compact(t),
                            style: AppTextStyles.micro.copyWith(
                              color: context.textMuted,
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Bars(values: bars, niceMax: niceMax),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const SizedBox(width: 38),
              Expanded(
                child: Row(
                  children: List<Widget>.generate(labels.length, (int i) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          labels[i],
                          style: AppTextStyles.micro.copyWith(
                            color: context.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Round a raw max up to a "nice" axis ceiling (1/2/3/4/5/6/8 × 10ⁿ).
  static int _niceMax(int m) {
    if (m <= 0) return 1000;
    int mag = 1;
    while (mag * 10 <= m) {
      mag *= 10;
    }
    for (final int f in const <int>[1, 2, 3, 4, 5, 6, 8, 10]) {
      final int cand = f * mag;
      if (cand >= m) return cand;
    }
    return 10 * mag;
  }

  /// Compact money labels for the y-axis: 20000 → "20K", 1.5M → "1.5M".
  static String _compact(int n) {
    if (n >= 1000000) {
      final double v = n / 1000000;
      return '${v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).round()}K';
    }
    return '$n';
  }
}

/// Resolves the chart's bar values + axis labels from the active period.
///   * week  → 7 daily bars, day initials
///   * month → ~5 weekly buckets (W1…Wn), daily summed in 7-day chunks
///   * year  → 12 monthly bars, month initials
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
        return (List<int>.filled(5, 0), <String>['W1', 'W2', 'W3', 'W4', 'W5']);
      }
      // Chunk the daily buckets into weeks of 7 and sum each — the
      // mockup shows weekly bars (W1…W5), not 30 daily slivers.
      final List<int> weekly = <int>[];
      final List<String> labels = <String>[];
      for (int i = 0; i < state.daily.length; i += 7) {
        final int end =
            (i + 7 < state.daily.length) ? i + 7 : state.daily.length;
        int sum = 0;
        for (int j = i; j < end; j++) {
          sum += state.daily[j].netNaira;
        }
        weekly.add(sum);
        labels.add('W${weekly.length}');
      }
      return (weekly, labels);
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
  const _Bars({required this.values, required this.niceMax});
  final List<int> values;
  final int niceMax;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(values.length, (int i) {
        final double h = niceMax <= 0
            ? 0.03
            : (values[i] / niceMax).clamp(0.03, 1.0).toDouble();
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FractionallySizedBox(
              heightFactor: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.teal,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _LedgerSection extends StatelessWidget {
  const _LedgerSection({required this.state});
  final WalletState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'RECENT ACTIVITY',
              style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
            ),
            if (state.entries.length > 8)
              Text(
                'showing ${state.entries.length > 20 ? 20 : state.entries.length}',
                style: AppTextStyles.captionSm
                    .copyWith(fontSize: 11, color: context.textMuted),
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
                style: AppTextStyles.bodySm.copyWith(color: context.textDim),
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
                  if (i > 0) Divider(height: 1, color: context.border),
                  _LedgerRow(entry: state.entries[i]),
                ],
              ],
            ),
          ),
      ],
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
            context.coral.withValues(alpha: 0.18),
            context.coral.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppRadius.lg,
        border: Border.all(color: context.coral.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'WALLET BALANCE',
            style: AppTextStyles.eyebrow.copyWith(color: context.coral),
          ),
          const SizedBox(height: 4),
          Text(
            NairaFormatter.format(state.balanceNaira),
            style: AppTextStyles.priceHero.copyWith(
              fontSize: 42,
              letterSpacing: -1.2,
              color: context.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.wallet == null
                ? 'No payouts yet'
                : 'Updated ${_relativeTime(state.wallet!.updatedAt)}',
            style: AppTextStyles.captionSm.copyWith(color: context.textDim),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: DrivioButton(
                  label: 'Withdraw',
                  disabled: state.balanceNaira < 5000,
                  onPressed: () {
                    AppNotifier.info(
                      message: 'Withdrawals run via Paystack — coming soon.',
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DrivioButton(
                  label: 'History',
                  variant: DrivioButtonVariant.ghost,
                  onPressed: () {},
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
    final Color tone = credit ? context.coral : context.red;
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
            child: Icon(_iconFor(entry.kind), size: 18, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _labelFor(entry.kind),
                  style: AppTextStyles.caption.copyWith(
                    color: context.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.description ?? _fmtTime(entry.createdAt),
                  style: AppTextStyles.captionSm
                      .copyWith(fontSize: 11, color: context.textDim),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '$sign${NairaFormatter.format(entry.amountMinor ~/ 100)}',
                style: AppTextStyles.bodySm.copyWith(
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

  static IconData _iconFor(LedgerKind kind) {
    switch (kind) {
      case LedgerKind.tripCredit:
        return DrivioIcons.car;
      case LedgerKind.payoutDebit:
        return DrivioIcons.wallet;
      case LedgerKind.refund:
        return DrivioIcons.refresh;
      case LedgerKind.adjustment:
        return DrivioIcons.edit;
      case LedgerKind.subscriptionDebit:
        return DrivioIcons.card;
      case LedgerKind.unknown:
        return DrivioIcons.info;
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
