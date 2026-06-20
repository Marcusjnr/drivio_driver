import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/dash/features/drive_shell/presentation/logic/controller/drive_shell_controller.dart';
import 'package:drivio_driver/modules/trip/features/ride_request/presentation/logic/controller/ride_request_controller.dart';

/// Bottom-sheet body shown in [ShellMode.bidding].
///
///   • composing / submitting → the bid composer (SCR-019/020/021):
///     route, YOUR PRICE, the price input (type / slider / chips), the
///     you-keep line, Decline / Submit.
///   • waiting → the "Bid in." waiting sheet (SCR-022): a dark sheet
///     with a depleting coral ring, the countdown, and Withdraw.
class BiddingBody extends ConsumerWidget {
  const BiddingBody({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RideRequestState state =
        ref.watch(rideRequestControllerProvider(requestId));
    final RideRequestController c =
        ref.read(rideRequestControllerProvider(requestId).notifier);

    if (state.isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.request == null) {
      return _ErrorPanel(
        message: state.error ?? 'Could not load this request.',
        onClose: () =>
            ref.read(driveShellControllerProvider.notifier).exitBidding(),
      );
    }

    // SCR-022 — once the bid is placed, the composer gives way to the
    // dark waiting sheet. won/lost are brief transitional states the
    // shell navigates away from, so they ride the same waiting visual.
    final bool waiting = state.phase == BidPhase.waiting ||
        state.phase == BidPhase.won ||
        state.phase == BidPhase.lost;
    if (waiting) {
      return _WaitingBody(state: state, onWithdraw: c.withdraw);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Handle(),
          const SizedBox(height: 14),
          _RouteRow(state: state),
          const SizedBox(height: 16),
          _FareCard(
            state: state,
            onPriceChanged: c.setPriceNaira,
            onVariantChanged: c.setVariant,
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: AppTextStyles.bodySm.copyWith(color: context.red),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 14),
          _ActionRow(
            state: state,
            controller: c,
            onDecline: () =>
                ref.read(driveShellControllerProvider.notifier).exitBidding(),
          ),
        ],
      ),
    );
  }
}

/// Centered charcoal-teal drag handle, used by the bidding sheets which
/// don't go through BottomSheetCard.
class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: context.text.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}

/// SCR-022 — "Bid in." waiting sheet. Dark charcoal-teal body with a
/// depleting coral ring around the countdown.
class _WaitingBody extends StatelessWidget {
  const _WaitingBody({required this.state, required this.onWithdraw});

  final RideRequestState state;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      decoration: const BoxDecoration(
        color: AppColors.charcoalTeal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.ivory.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Bid in.',
            style: AppTextStyles.screenTitle.copyWith(color: AppColors.ivory),
          ),
          const SizedBox(height: 22),
          // Depleting coral ring + countdown.
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: state.progressPct.clamp(0.0, 1.0),
                    strokeWidth: 3,
                    backgroundColor: AppColors.ivory.withValues(alpha: 0.10),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppColors.coral),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _fmtClock(state.secondsLeft),
                      style: AppTextStyles.metricVal.copyWith(
                        fontSize: 34,
                        color: AppColors.ivory,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'BID IN',
                      style: AppTextStyles.eyebrow
                          .copyWith(color: AppColors.coral),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '${NairaFormatter.format(state.priceNaira)} · '
            '${state.distanceKm.toStringAsFixed(1)} km',
            style: AppTextStyles.body.copyWith(
              color: AppColors.ivory,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.phase == BidPhase.won
                ? 'You won — loading your trip…'
                : state.phase == BidPhase.lost
                    ? 'Another driver was picked.'
                    : 'Waiting for the rider to choose.',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.ivory.withValues(alpha: 0.72),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (state.phase == BidPhase.waiting)
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: onWithdraw,
                child: Text(
                  'Withdraw bid',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.ivory.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _fmtClock(int seconds) {
    if (seconds <= 0) return '00:00';
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message,
            style: AppTextStyles.bodySm.copyWith(color: context.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          DrivioButton(label: 'Close', onPressed: onClose),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.state,
    required this.controller,
    required this.onDecline,
  });

  final RideRequestState state;
  final RideRequestController controller;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    switch (state.phase) {
      case BidPhase.composing:
        return Row(
          children: <Widget>[
            Expanded(
              child: DrivioButton(
                label: 'Decline',
                variant: DrivioButtonVariant.ghost,
                onPressed: onDecline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DrivioButton(
                label: 'Submit bid',
                disabled: !state.canSubmit,
                onPressed: controller.submitBid,
              ),
            ),
          ],
        );
      case BidPhase.submitting:
        return DrivioButton(
          label: 'Submitting…',
          disabled: true,
          onPressed: () {},
        );
      case BidPhase.waiting:
      case BidPhase.won:
      case BidPhase.lost:
        // Handled by the dedicated waiting sheet; nothing here.
        return const SizedBox.shrink();
    }
  }
}

/// Pickup (coral disc) → drop-off (teal square) rail, then a chip row
/// with distance · duration per SCR-019.
class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.state});
  final RideRequestState state;

  @override
  Widget build(BuildContext context) {
    final String pickup = state.request?.pickupAddress ?? 'Pickup';
    final String dropoff = state.request?.dropoffAddress ?? 'Dropoff';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 12,
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 5),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: context.coral,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(
                    height: 26,
                    child: VerticalDivider(
                        color: context.borderStrong, thickness: 2),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: context.teal,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    pickup,
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.text,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    dropoff,
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.text,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            _MetaChip(label: '${state.distanceKm.toStringAsFixed(1)} KM'),
            const SizedBox(width: 8),
            _MetaChip(label: '~${state.durationMin} MIN'),
          ],
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.border),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono.copyWith(
          color: context.textDim,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FareCard extends StatefulWidget {
  const _FareCard({
    required this.state,
    required this.onPriceChanged,
    required this.onVariantChanged,
  });

  final RideRequestState state;
  final ValueChanged<int> onPriceChanged;
  final ValueChanged<PricingVariant> onVariantChanged;

  @override
  State<_FareCard> createState() => _FareCardState();
}

class _FareCardState extends State<_FareCard> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.state.priceNaira.toString());
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(_FareCard old) {
    super.didUpdateWidget(old);
    final String incoming = widget.state.priceNaira.toString();
    if (incoming != _ctrl.text && !_focus.hasFocus) {
      _ctrl.text = incoming;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RideRequestState state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // YOUR PRICE eyebrow. (Surcharges removed — no peak/night pill.)
        Text(
          'YOUR PRICE',
          style: AppTextStyles.eyebrow.copyWith(color: context.coral),
        ),
        const SizedBox(height: 8),
        Center(
          child: _PriceField(
            controller: _ctrl,
            focusNode: _focus,
            editable: state.variant == PricingVariant.type &&
                state.phase == BidPhase.composing,
            onChanged: (String value) {
              final int? n = int.tryParse(value);
              if (n != null) widget.onPriceChanged(n);
            },
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Suggested ${NairaFormatter.format(state.suggestedNaira)}',
            style: AppTextStyles.bodySm.copyWith(color: context.textDim),
          ),
        ),
        const SizedBox(height: 16),
        _VariantSwitcher(
          active: state.variant,
          disabled: state.phase != BidPhase.composing,
          onTap: widget.onVariantChanged,
        ),
        const SizedBox(height: 12),
        if (state.variant == PricingVariant.type)
          _TypeKeys(
            priceNaira: state.priceNaira,
            onChanged: widget.onPriceChanged,
            disabled: state.phase != BidPhase.composing,
          ),
        if (state.variant == PricingVariant.slider)
          _SliderVariant(state: state, onChanged: widget.onPriceChanged),
        if (state.variant == PricingVariant.chips)
          _ChipsVariant(state: state, onChanged: widget.onPriceChanged),
        const SizedBox(height: 14),
        // "You keep" — equals the bid price exactly (no commission math,
        // brand anti-pattern §12.7).
        Center(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
              children: <InlineSpan>[
                const TextSpan(text: 'You keep '),
                TextSpan(
                  text: NairaFormatter.format(state.netToYou),
                  style: AppTextStyles.bodySm.copyWith(
                    color: context.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.focusNode,
    required this.editable,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool editable;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: editable ? () => focusNode.requestFocus() : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            '₦',
            style: AppTextStyles.priceHero.copyWith(
              color: context.coral,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          IntrinsicWidth(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: editable,
              onChanged: onChanged,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              textAlign: TextAlign.center,
              cursorColor: context.coral,
              style: AppTextStyles.priceHero.copyWith(color: context.coral),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantSwitcher extends StatelessWidget {
  const _VariantSwitcher({
    required this.active,
    required this.onTap,
    this.disabled = false,
  });
  final PricingVariant active;
  final ValueChanged<PricingVariant> onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: context.surface2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: PricingVariant.values.map((PricingVariant v) {
            final bool isActive = v == active;
            return Expanded(
              child: GestureDetector(
                onTap: disabled ? null : () => onTap(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? context.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isActive
                        ? Border.all(color: context.border)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    v.name.toUpperCase(),
                    style: AppTextStyles.micro.copyWith(
                      color: isActive ? context.text : context.textDim,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TypeKeys extends StatelessWidget {
  const _TypeKeys({
    required this.priceNaira,
    required this.onChanged,
    this.disabled = false,
  });
  final int priceNaira;
  final ValueChanged<int> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    const List<int> deltas = <int>[-500, -100, 100, 500];
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Row(
        children: deltas
            .map((int d) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap:
                          disabled ? null : () => onChanged(priceNaira + d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: context.surface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          d > 0 ? '+$d' : '$d',
                          style: AppTextStyles.caption.copyWith(
                            color: context.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _SliderVariant extends StatelessWidget {
  const _SliderVariant({required this.state, required this.onChanged});
  final RideRequestState state;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final double min = (state.suggestedNaira * 0.6).roundToDouble();
    final double max = (state.suggestedNaira * 1.6).roundToDouble();
    return Column(
      children: <Widget>[
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: context.coral,
            inactiveTrackColor: context.surface3,
            thumbColor: context.coral,
            trackHeight: 6,
            overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: state.priceNaira.toDouble().clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / 100).round().clamp(1, 1000),
            onChanged: state.phase == BidPhase.composing
                ? (double v) => onChanged(v.round())
                : null,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '60%',
              style: AppTextStyles.mono
                  .copyWith(fontSize: 11, color: context.textMuted),
            ),
            Text(
              'Suggested ${NairaFormatter.format(state.suggestedNaira)}',
              style: AppTextStyles.captionSm.copyWith(color: context.textMuted),
            ),
            Text(
              '160%',
              style: AppTextStyles.mono
                  .copyWith(fontSize: 11, color: context.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChipsVariant extends StatelessWidget {
  const _ChipsVariant({required this.state, required this.onChanged});
  final RideRequestState state;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<_ChipOption> opts = <_ChipOption>[
      _ChipOption('−15%', (state.suggestedNaira * 0.85).round()),
      _ChipOption('Suggested', state.suggestedNaira),
      _ChipOption('+15%', (state.suggestedNaira * 1.15).round()),
      _ChipOption('+30%', (state.suggestedNaira * 1.3).round()),
    ];
    final bool disabled = state.phase != BidPhase.composing;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Row(
        children: opts.map((_ChipOption o) {
          final bool active = state.priceNaira == o.value;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: disabled ? null : () => onChanged(o.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? context.coral : context.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? Colors.transparent : context.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    children: <Widget>[
                      Text(
                        o.label,
                        style: AppTextStyles.caption.copyWith(
                          color: active ? context.coralInk : context.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        NairaFormatter.format(o.value),
                        style: AppTextStyles.captionSm.copyWith(
                          color: active
                              ? context.coralInk.withValues(alpha: 0.85)
                              : context.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChipOption {
  _ChipOption(this.label, this.value);
  final String label;
  final int value;
}
