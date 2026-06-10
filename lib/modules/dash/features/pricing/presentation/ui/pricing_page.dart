import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/driver_tab_bar.dart';
import 'package:drivio_driver/modules/dash/features/pricing/presentation/logic/controller/pricing_controller.dart';

/// SCR-033 — Pricing strategy.
///
/// Pared to the two defaults (base fare + per-km) and the live example,
/// per the mockup. Surcharges (peak/night) and trip preferences are no
/// longer surfaced — and the fare suggestion is base + per-km only, with
/// no time-of-day multiplier (see `ride_request_controller`).
class PricingPage extends ConsumerWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PricingState state = ref.watch(pricingControllerProvider);
    final PricingController c = ref.read(pricingControllerProvider.notifier);

    return ScreenScaffold(
      bottomBar: const DriverTabBar(active: DriverTab.pricing),
      child: state.isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: CircularProgressIndicator(),
              ),
            )
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

    // Example: an 8 km trip, via the exact path the bid composer takes —
    // base + per-km × km, then nearest-₦100 round. Mirrors
    // `suggestForDistance` so the headline here is the number a real
    // request would surface in the bidding sheet.
    const int kExampleKm = 8;
    final int rawMinor =
        profile.suggestForDistance(kExampleKm * 1000);
    final int exampleNaira =
        PricingProfile.roundToNearestNaira100(rawMinor) ~/ 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Pricing strategy',
                      style: AppTextStyles.screenTitle
                          .copyWith(color: context.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your defaults for the bid composer.',
                      style: AppTextStyles.bodySm
                          .copyWith(color: context.textDim),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _SaveStatusPill(state: state),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // DEFAULTS — base fare + per-km steppers.
          _SectionGroup(
            title: 'DEFAULTS',
            children: <Widget>[
              _NumberRow(
                icon: Icons.sell_outlined,
                label: 'Base fare',
                value: baseNaira,
                step: 100,
                onChanged: (int v) => controller.setBaseMinor(v * 100),
              ),
              _NumberRow(
                icon: Icons.straighten_rounded,
                label: 'Per km',
                value: perKmNaira,
                step: 50,
                onChanged: (int v) => controller.setPerKmMinor(v * 100),
                isLast: true,
              ),
            ],
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
                style: AppTextStyles.captionSm.copyWith(color: context.red),
              ),
            ),
          ],

          const SizedBox(height: 22),

          // Example — live preview of an 8 km trip's suggested fare.
          _ExampleCard(
            km: kExampleKm,
            suggestedNaira: exampleNaira,
            baseNaira: baseNaira,
            perKmNaira: perKmNaira,
          ),
        ],
      ),
    );
  }
}

/// The pale example box: "Example: 8 km would suggest ₦2,200" + formula.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.km,
    required this.suggestedNaira,
    required this.baseNaira,
    required this.perKmNaira,
  });

  final int km;
  final int suggestedNaira;
  final int baseNaira;
  final int perKmNaira;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.butter.withValues(alpha: 0.10),
        borderRadius: AppRadius.base,
        border: Border.all(color: context.butter.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTextStyles.body.copyWith(color: context.text),
              children: <InlineSpan>[
                TextSpan(text: 'Example: $km km would suggest '),
                TextSpan(
                  text: NairaFormatter.format(suggestedNaira),
                  style: AppTextStyles.body.copyWith(
                    color: context.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${NairaFormatter.format(baseNaira)} + '
            '${NairaFormatter.format(perKmNaira)} × $km km',
            textAlign: TextAlign.center,
            style: AppTextStyles.mono.copyWith(
              color: context.textMuted,
              fontSize: 12,
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
        Text(
          title,
          style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
        ),
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
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 100,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final int value;
  final int step;
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
          Icon(icon, size: 18, color: context.textDim),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySm.copyWith(
                color: context.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _StepperBtn(
            icon: DrivioIcons.minus,
            // Floor at 0 (no negative fares); increase is unbounded so
            // the driver can set any amount they choose.
            onTap: () => onChanged(value - step < 0 ? 0 : value - step),
          ),
          SizedBox(
            width: 84,
            child: Text(
              NairaFormatter.format(value),
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(color: context.text),
            ),
          ),
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: context.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: context.text),
      ),
    );
  }
}
