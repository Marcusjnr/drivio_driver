import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/pricing_profile.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/driver_tab_bar.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/location_gate_sheet.dart';
import 'package:drivio_driver/modules/dash/features/pricing/presentation/logic/controller/pricing_controller.dart';

/// SCR-033 — Pricing strategy.
///
/// Pared down to the single driver-owned default: the per-km rate. Base
/// fare is admin-set per state, surcharges (peak/night) and trip
/// preferences are no longer surfaced — and the fare suggestion is
/// base + per-km only, with no time-of-day multiplier (see
/// `ride_request_controller`).
class PricingPage extends ConsumerStatefulWidget {
  const PricingPage({super.key});

  @override
  ConsumerState<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends ConsumerState<PricingPage>
    with WidgetsBindingObserver {
  /// Whether the location gate SHEET is up. It opens when the driver
  /// taps a stepper while the page is unbanded (no location, no known
  /// state) — not automatically, so the tab itself stays quiet.
  bool _gateOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A grant made in system Settings only shows up on resume — re-check
    // silently so the gate clears without the driver tapping anything.
    if (state == AppLifecycleState.resumed) {
      ref.read(pricingControllerProvider.notifier).recheckLocation();
    }
  }

  Future<void> _allow() async {
    setState(() => _gateOpen = false);
    await ref.read(pricingControllerProvider.notifier).allowLocation();
  }

  @override
  Widget build(BuildContext context) {
    final PricingState state = ref.watch(pricingControllerProvider);
    final PricingController c = ref.read(pricingControllerProvider.notifier);

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ScreenScaffold(
          bottomBar: const DriverTabBar(active: DriverTab.pricing),
          child: state.isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _Body(
                  state: state,
                  controller: c,
                  // Unbanded (no location, no known state): the rate
                  // reads ₦0 and the steppers open the location gate
                  // instead of editing.
                  onLockedTap: state.needsLocation
                      ? () => setState(() => _gateOpen = true)
                      : null,
                ),
        ),
        if (state.needsLocation && _gateOpen && !state.isLoading)
          LocationGateSheet(
            permission: state.permission,
            askTitle: 'Allow location\nto set your rate.',
            askBody:
                'Fares are priced per state, so we need your location to '
                'show the right per-km range for your area.',
            onAllow: _allow,
            onOpenSettings: () {
              setState(() => _gateOpen = false);
              c.openLocationSettings();
            },
            onDismiss: () => setState(() => _gateOpen = false),
          ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.controller,
    this.onLockedTap,
  });

  final PricingState state;
  final PricingController controller;

  /// Non-null while the page is unbanded (no location permission AND no
  /// known state). The rate shows as ₦0 and any stepper tap fires this
  /// instead of editing — it opens the location gate sheet.
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    final bool locked = onLockedTap != null;
    final PricingProfile profile =
        state.profile ?? PricingProfile.platformDefault;
    // While locked we deliberately show ₦0, not the seeded national
    // default — a number here reads as "your rate", and we don't know
    // the right band for this driver yet.
    final int perKmNaira = locked ? 0 : profile.perKmNaira;
    // Hard per-km limits for this driver's state. Null = state has the
    // cap disabled (warn_pct 0), in which case the steppers are free.
    final ({int low, int high})? bounds =
        locked ? null : controller.perKmBounds;

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

          // YOUR RATE — per-km only. Base fare is set by Drivio per state
          // and is not the driver's to change, so it is not surfaced here
          // at all.
          _SectionGroup(
            title: 'YOUR RATE',
            children: <Widget>[
              _NumberRow(
                icon: Icons.straighten_rounded,
                label: 'Per km',
                value: perKmNaira,
                step: 50,
                min: bounds == null ? null : bounds.low ~/ 100,
                max: bounds == null ? null : bounds.high ~/ 100,
                onChanged: locked
                    ? (int _) => onLockedTap!()
                    : (int v) => controller.setPerKmMinor(v * 100),
                isLast: true,
              ),
            ],
          ),

          if (bounds != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'You can set ${NairaFormatter.format(bounds.low ~/ 100)}'
              '–${NairaFormatter.format(bounds.high ~/ 100)} per km '
              'in your area.',
              style: AppTextStyles.captionSm.copyWith(color: context.textDim),
            ),
          ],

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
    this.min,
    this.max,
  });

  final IconData icon;
  final String label;
  final int value;
  final int step;
  final ValueChanged<int> onChanged;
  final bool isLast;

  /// Hard bounds (naira). The steppers stop dead at these — the band is
  /// enforced server-side, so letting the driver step past it would only
  /// produce a value the server silently corrects.
  final int? min;
  final int? max;

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
            enabled: min == null || value > min!,
            onTap: () {
              final int next = value - step;
              onChanged(next < (min ?? 0) ? (min ?? 0) : next);
            },
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
            enabled: max == null || value < max!,
            onTap: () {
              final int next = value + step;
              onChanged(max != null && next > max! ? max! : next);
            },
          ),
        ],
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final VoidCallback onTap;

  /// A stepper at the edge of the allowed band dims and stops responding,
  /// so the limit is visible rather than a value that silently snaps back.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
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
      ),
    );
  }
}
