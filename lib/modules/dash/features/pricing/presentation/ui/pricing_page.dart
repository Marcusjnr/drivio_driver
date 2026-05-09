import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/driver_tab_bar.dart';
import 'package:drivio_driver/modules/dash/features/pricing/presentation/logic/controller/pricing_controller.dart';

class PricingPage extends ConsumerWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PricingState state = ref.watch(pricingControllerProvider);
    final PricingController c =
        ref.read(pricingControllerProvider.notifier);

    return ScreenScaffold(
      bottomBar: const DriverTabBar(active: DriverTab.pricing),
      child: state.isLoading
          ? const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: CircularProgressIndicator(),
            ))
          : _Body(state: state, controller: c),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.controller});

  final PricingState state;
  final PricingController controller;

  @override
  Widget build(BuildContext context) {
    final PricingProfile profile =
        state.profile ?? PricingProfile.platformDefault;
    final int baseNaira = profile.baseNaira;
    final int perKmNaira = profile.perKmNaira;

    // Preview an 8 km off-peak trip using the EXACT path the bid composer
    // takes — base + per-km × km in minor units, then nearest-₦100 round.
    // Mirroring the helper on PricingProfile guarantees the headline
    // here is whatever number a real request would surface in the
    // bidding sheet for an 8 km off-peak trip.
    const int kPreviewDistanceM = 8000;
    final int rawMinor = profile.suggestForDistance(kPreviewDistanceM);
    final int previewMinor = PricingProfile.roundToNearestNaira100(rawMinor);
    final int previewNaira = previewMinor ~/ 100;
    // Same trip with each surcharge layered in. Only shown when the
    // toggle is on, so disabled multipliers stay out of the way.
    final int peakNaira = PricingProfile.roundToNearestNaira100(
            (rawMinor * profile.peakMultiplier).round()) ~/
        100;
    final int nightNaira = PricingProfile.roundToNearestNaira100(
            (rawMinor * profile.nightMultiplier).round()) ~/
        100;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Pricing strategy',
                      style: AppTextStyles.h1.copyWith(color: context.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'The fare Drivio suggests is built from these.',
                      style: AppTextStyles.caption
                          .copyWith(color: context.textDim),
                    ),
                  ],
                ),
              ),
              _SaveStatusPill(state: state),
            ],
          ),
          const SizedBox(height: 16),
          // Live preview: ₦base + ₦perKm × 8 km. Mirrors the formula the
          // ride request controller will use to seed bid suggestions, so the
          // driver can validate by eye before saving.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  context.accent.withValues(alpha: 0.1),
                  context.accent.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: AppRadius.base,
              border: Border.all(color: context.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PREVIEW · 8 KM TRIP, OFF-PEAK',
                  style: AppTextStyles.eyebrow.copyWith(color: context.accent),
                ),
                const SizedBox(height: 4),
                Text(
                  NairaFormatter.format(previewNaira),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: context.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${NairaFormatter.format(baseNaira)} base + '
                  '${NairaFormatter.format(perKmNaira)}/km × 8 km'
                  ' = ${NairaFormatter.format(baseNaira + perKmNaira * 8)}'
                  '${(baseNaira + perKmNaira * 8) == previewNaira ? '' : ' → ${NairaFormatter.format(previewNaira)}'}',
                  style: TextStyle(fontSize: 12, color: context.textDim),
                ),
                if (profile.peakEnabled || profile.nightEnabled) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    height: 1,
                    color: context.accent.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 8),
                  if (profile.peakEnabled)
                    _SurchargeLine(
                      label: 'PEAK',
                      labelColor: context.amber,
                      multiplier: profile.peakMultiplier,
                      amountNaira: peakNaira,
                    ),
                  if (profile.peakEnabled && profile.nightEnabled)
                    const SizedBox(height: 4),
                  if (profile.nightEnabled)
                    _SurchargeLine(
                      label: 'NIGHT',
                      labelColor: context.blue,
                      multiplier: profile.nightMultiplier,
                      amountNaira: nightNaira,
                    ),
                ],
              ],
            ),
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.red.withValues(alpha: 0.08),
                borderRadius: AppRadius.sm,
                border: Border.all(color: context.red.withValues(alpha: 0.25)),
              ),
              child: Text(
                state.error!,
                style: TextStyle(fontSize: 12, color: context.red),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _SectionGroup(
            title: 'BASE FARE',
            children: <Widget>[
              _NumberRow(
                label: 'Minimum per trip',
                value: baseNaira,
                step: 100,
                onChanged: (int v) => controller.setBaseMinor(v * 100),
              ),
              _NumberRow(
                label: 'Price per km',
                value: perKmNaira,
                step: 20,
                unit: '/km',
                onChanged: (int v) => controller.setPerKmMinor(v * 100),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionGroup(
            title: 'PEAK HOURS',
            children: <Widget>[
              _ToggleRow(
                label: 'Auto peak (6–9am, 5–8pm)',
                sub: 'Drivio boosts suggestions during busy hours.',
                value: profile.peakEnabled,
                onChanged: controller.setPeakEnabled,
              ),
              _PeakSlider(
                value: profile.peakMultiplier,
                onChanged: controller.setPeakMultiplier,
              ),
              _ToggleRow(
                label: 'Late night surcharge (10pm–5am)',
                sub:
                    '+${((profile.nightMultiplier - 1) * 100).round()}% auto-applied on suggested fare.',
                value: profile.nightEnabled,
                onChanged: controller.setNightEnabled,
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionGroup(
            title: 'TRIP PREFERENCES',
            children: <Widget>[
              FieldRow(
                label: 'Preferred trip length',
                value: profile.tripLength.label,
                divider: false,
                onTap: () =>
                    AppNavigation.push(AppRoutes.preferredTripLength),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: AppRadius.md,
              border: Border.all(color: context.borderStrong),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 12, color: context.textDim, height: 1.5),
                      children: <InlineSpan>[
                        const TextSpan(text: 'These numbers only '),
                        TextSpan(
                          text: 'suggest',
                          style: TextStyle(
                              color: context.text,
                              fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                            text:
                                ' a fare — you can always counter-offer on the request screen.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reflects the debounced-save state machine: SAVING while a flush is
/// in flight, SAVED briefly after a successful flush, otherwise no chip.
class _SaveStatusPill extends StatelessWidget {
  const _SaveStatusPill({required this.state});

  final PricingState state;

  @override
  Widget build(BuildContext context) {
    if (state.isSaving) {
      return const Pill(text: 'SAVING…', tone: PillTone.neutral);
    }
    if (state.lastSavedAt != null) {
      return const Pill(text: 'SAVED', tone: PillTone.accent);
    }
    return const SizedBox.shrink();
  }
}

class _SectionGroup extends StatelessWidget {
  const _SectionGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: context.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 100,
    this.unit = '',
    this.isLast = false,
  });

  final String label;
  final int value;
  final int step;
  final String unit;
  final ValueChanged<int> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: context.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: context.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _StepperBtn(
            icon: DrivioIcons.minus,
            onTap: () => onChanged((value - step).clamp(0, 999999)),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              '${NairaFormatter.format(value)}$unit',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: context.text,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _StepperBtn(
            icon: DrivioIcons.plus,
            onTap: () => onChanged(value + step),
          ),
        ],
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: context.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 14, color: context.text),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: context.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textDim,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: context.accent,
          ),
        ],
      ),
    );
  }
}

class _PeakSlider extends StatelessWidget {
  const _PeakSlider({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.border)),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Peak multiplier',
                style: TextStyle(
                  fontSize: 14,
                  color: context.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)}×',
                style: TextStyle(
                  fontSize: 14,
                  color: context.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: context.accent,
              inactiveTrackColor: context.surface3,
              thumbColor: context.text,
            ),
            child: Slider(
              value: value.clamp(1.0, 2.5),
              min: 1,
              max: 2.5,
              divisions: 15,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('1.0×', style: TextStyle(fontSize: 11, color: context.textMuted)),
              Text('1.5×', style: TextStyle(fontSize: 11, color: context.textMuted)),
              Text('2.5×', style: TextStyle(fontSize: 11, color: context.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row in the preview block showing a surcharge variant: a coloured
/// label pill on the left ("PEAK · 1.5×"), the resulting fare on the
/// right. Only rendered for surcharges the driver has enabled.
class _SurchargeLine extends StatelessWidget {
  const _SurchargeLine({
    required this.label,
    required this.labelColor,
    required this.multiplier,
    required this.amountNaira,
  });

  final String label;
  final Color labelColor;
  final double multiplier;
  final int amountNaira;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: labelColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$label · ${multiplier.toStringAsFixed(1)}×',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: labelColor,
            ),
          ),
        ),
        const Spacer(),
        Text(
          NairaFormatter.format(amountNaira),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.text,
          ),
        ),
      ],
    );
  }
}
