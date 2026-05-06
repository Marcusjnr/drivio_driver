import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';
import 'package:drivio_driver/modules/dash/features/drive_shell/presentation/logic/controller/drive_shell_controller.dart';
import 'package:drivio_driver/modules/trip/features/ride_request/presentation/logic/controller/ride_request_controller.dart';

/// Bottom-sheet body shown in [ShellMode.bidding]. Reads the active
/// `requestId` from the shell state and delegates to the existing
/// `RideRequestController` family. Decline simply asks the shell to
/// exit bidding mode (no route pop).
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

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _RouteRow(state: state),
          const SizedBox(height: 14),
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
          const SizedBox(height: 10),
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

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
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
                variant: DrivioButtonVariant.danger,
                onPressed: onDecline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DrivioButton(
                label: 'Bid · ${NairaFormatter.format(state.priceNaira)}',
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
        return Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Bid placed · waiting for passenger',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            DrivioButton(
              label: 'Withdraw',
              variant: DrivioButtonVariant.ghost,
              onPressed: controller.withdraw,
            ),
          ],
        );
      case BidPhase.won:
        return DrivioButton(
          label: 'You won! Loading trip…',
          disabled: true,
          onPressed: () {},
        );
      case BidPhase.lost:
        return DrivioButton(
          label: 'Closing…',
          disabled: true,
          onPressed: () {},
        );
    }
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.state});
  final RideRequestState state;

  @override
  Widget build(BuildContext context) {
    final String pickup = state.request?.pickupAddress ?? 'Pickup';
    final String dropoff = state.request?.dropoffAddress ?? 'Dropoff';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 12,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 6),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: context.blue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.blue.withValues(alpha: 0.2),
                    width: 3,
                  ),
                ),
              ),
              SizedBox(
                height: 28,
                child: VerticalDivider(
                    color: context.borderStrong, thickness: 2),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: context.text,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('PICKUP',
                  style:
                      AppTextStyles.eyebrow.copyWith(color: context.textDim)),
              const SizedBox(height: 1),
              Text(
                pickup,
                style: TextStyle(
                  fontSize: 14,
                  color: context.text,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Text(
                'DROP-OFF · ${state.distanceKm.toStringAsFixed(1)} KM · ${state.durationMin} MIN',
                style:
                    AppTextStyles.eyebrow.copyWith(color: context.textDim),
              ),
              const SizedBox(height: 1),
              Text(
                dropoff,
                style: TextStyle(
                  fontSize: 14,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'YOUR FARE · YOU DECIDE',
                style: AppTextStyles.eyebrow.copyWith(color: context.accent),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (state.suggestedWindow != null) ...<Widget>[
                    // Driver's pricing profile boosted the suggestion
                    // because this request landed in their peak/night
                    // window. Surface it so the higher number doesn't
                    // surprise them.
                    Pill(
                      text: state.suggestedWindow == PricingWindow.peak
                          ? 'PEAK · ${state.suggestedMultiplier.toStringAsFixed(1)}×'
                          : 'NIGHT · ${state.suggestedMultiplier.toStringAsFixed(1)}×',
                      tone: state.suggestedWindow == PricingWindow.peak
                          ? PillTone.amber
                          : PillTone.blue,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    'Suggested ${NairaFormatter.format(state.suggestedNaira)}',
                    style: TextStyle(fontSize: 11, color: context.textDim),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 14),
          _VariantSwitcher(
            active: state.variant,
            disabled: state.phase != BidPhase.composing,
            onTap: widget.onVariantChanged,
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 12),
          _SentimentBar(score: state.sentimentScore),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('You keep',
                  style: TextStyle(fontSize: 12, color: context.textDim)),
              Text(
                NairaFormatter.format(state.netToYou),
                style: TextStyle(
                  fontSize: 12,
                  color: context.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
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
              color: context.textDim,
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
              cursorColor: context.accent,
              style: AppTextStyles.priceHero.copyWith(color: context.text),
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
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? context.surface3 : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    v.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? context.text : context.textDim,
                      fontWeight: FontWeight.w600,
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
    final List<int> deltas = const <int>[500, 100, -100, -500];
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
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: context.surface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          d > 0 ? '+$d' : '$d',
                          style: TextStyle(
                            color: context.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
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
            activeTrackColor: context.accent,
            inactiveTrackColor: context.surface3,
            thumbColor: context.text,
            trackHeight: 6,
          ),
          child: Slider(
            value: state.priceNaira.toDouble().clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / 100).round(),
            onChanged: state.phase == BidPhase.composing
                ? (double v) => onChanged(v.round())
                : null,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(NairaFormatter.format(min.round()),
                style: TextStyle(fontSize: 11, color: context.textMuted)),
            Text('Suggested',
                style: TextStyle(fontSize: 11, color: context.textMuted)),
            Text(NairaFormatter.format(max.round()),
                style: TextStyle(fontSize: 11, color: context.textMuted)),
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
                    color: active ? context.accent : context.surface2,
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? context.accentInk : context.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        NairaFormatter.format(o.value),
                        style: TextStyle(
                          fontSize: 11,
                          color: active
                              ? context.accentInk.withValues(alpha: 0.85)
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

class _SentimentBar extends StatelessWidget {
  const _SentimentBar({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final List<String> emojis = const <String>['😟', '🤔', '👍', '🔥', '😬'];
    final List<String> labels = const <String>[
      "Below market — you'll likely get it",
      'A touch low — still competitive',
      'Right on — fair price',
      'Aggressive — expect fewer bites',
      'Too high — riders may skip',
    ];
    final int idx = (score + 2).clamp(0, 4);
    final PillTone tone = idx < 3
        ? PillTone.accent
        : idx == 3
            ? PillTone.amber
            : PillTone.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: <Widget>[
          Text(emojis[idx], style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  labels[idx],
                  style: TextStyle(
                    fontSize: 13,
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nearby drivers: ₦2.8k – ₦4.2k',
                  style: TextStyle(fontSize: 11, color: context.textDim),
                ),
              ],
            ),
          ),
          Pill(
            text: idx == 2
                ? 'FAIR'
                : idx < 2
                    ? 'LOW'
                    : 'HIGH',
            tone: tone,
          ),
        ],
      ),
    );
  }
}
