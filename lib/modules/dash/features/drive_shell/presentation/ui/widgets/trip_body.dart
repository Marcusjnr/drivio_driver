import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/passenger_rating.dart';
import 'package:drivio_driver/modules/commons/types/trip.dart';
import 'package:drivio_driver/modules/commons/utils/navigation_launcher.dart';
import 'package:drivio_driver/modules/dash/features/drive_shell/presentation/logic/controller/drive_shell_controller.dart';
import 'package:drivio_driver/modules/trip/features/active_trip/presentation/logic/controller/active_trip_controller.dart';
import 'package:drivio_driver/modules/trip/features/active_trip/presentation/logic/controller/passenger_rating_controller.dart';
import 'package:drivio_driver/modules/trip/features/call/presentation/ui/call_sheet.dart';
import 'package:drivio_driver/modules/trip/features/chat/presentation/logic/controller/unread_chat_controller.dart';

/// Bottom-sheet body shown in any trip-like shell mode — SCR-023 through
/// SCR-027.
///
/// Each non-terminal state follows the same shape: coral eyebrow →
/// Marcellus headline → locked-fare → the state's primary action. The
/// mockups keep Call / Navigate / Cancel out of the hero, so they live
/// in a quiet utility row + a Cancel link beneath the main buttons.
class TripBody extends ConsumerWidget {
  const TripBody({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActiveTripState state = ref.watch(
      activeTripControllerProvider(tripId),
    );
    final ActiveTripController c = ref.read(
      activeTripControllerProvider(tripId).notifier,
    );

    if (state.isLoading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final Trip? trip = state.trip;
    if (trip == null) {
      return BottomSheetCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: <Widget>[
              Text(
                state.error ?? 'Trip unavailable.',
                style: AppTextStyles.bodySm.copyWith(color: context.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              DrivioButton(
                label: 'Close',
                onPressed: () =>
                    ref.read(driveShellControllerProvider.notifier).exitTrip(),
              ),
            ],
          ),
        ),
      );
    }

    final bool isCompleted = trip.state == TripState.completed;
    final bool isCancelled = trip.state == TripState.cancelled;

    return BottomSheetCard(
      child: isCompleted
          ? _CompletedBody(
              trip: trip,
              onContinue: () =>
                  ref.read(driveShellControllerProvider.notifier).exitTrip(),
            )
          : isCancelled
          ? _CancelledBody(
              trip: trip,
              onContinue: () =>
                  ref.read(driveShellControllerProvider.notifier).exitTrip(),
            )
          : _InTripBody(
              state: state,
              controller: c,
              unreadChats: ref.watch(unreadChatControllerProvider(trip.id)),
            ),
    );
  }
}

class _InTripBody extends StatelessWidget {
  const _InTripBody({
    required this.state,
    required this.controller,
    required this.unreadChats,
  });

  final ActiveTripState state;
  final ActiveTripController controller;
  final int unreadChats;

  @override
  Widget build(BuildContext context) {
    final Trip trip = state.trip!;
    final TripState s = trip.state;
    final _NavTarget? navTarget = _navTargetFor(trip);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Eyebrow.
        Text(
          _eyebrow(s),
          style: AppTextStyles.eyebrow.copyWith(color: context.coral),
        ),
        const SizedBox(height: 10),

        // Headline (Marcellus).
        Text(
          _headline(trip),
          style: AppTextStyles.screenTitleSm.copyWith(color: context.text),
        ),

        // Optional sub-line.
        if (_sub(trip) != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            _sub(trip)!,
            style: AppTextStyles.bodySm.copyWith(
              color: context.textDim,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Locked fare — big coral on assignment, a bordered row after.
        if (s == TripState.assigned)
          _LockedFareBig(naira: trip.fareNaira)
        else
          _LockedFareRow(naira: trip.fareNaira),

        if (state.error != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            state.error!,
            style: AppTextStyles.bodySm.copyWith(color: context.red),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 18),

        // Primary action row — matches the mockup's button layout.
        _PrimaryActions(
          state: state,
          controller: controller,
          unreadChats: unreadChats,
        ),

        // Quiet utility row — Call, Chat (where not already primary),
        // Navigate. Keeps the actions the mockup hides out of the hero
        // without losing them.
        const SizedBox(height: 12),
        _UtilityRow(trip: trip, navTarget: navTarget, unreadChats: unreadChats),

        // Cancel — a low-emphasis link, last.
        const SizedBox(height: 4),
        TextButton(
          onPressed: state.isAdvancing
              ? null
              : () => _showCancelReasonSheet(context, controller),
          child: Text(
            'Cancel trip',
            style: AppTextStyles.captionSm.copyWith(color: context.textMuted),
          ),
        ),
      ],
    );
  }

  // ── Per-state copy ────────────────────────────────────────────────────

  static String _eyebrow(TripState s) {
    switch (s) {
      case TripState.assigned:
        return 'ASSIGNED';
      case TripState.enRoute:
        return 'EN ROUTE';
      case TripState.arrived:
        return 'ARRIVED';
      case TripState.inProgress:
        return 'IN PROGRESS';
      case TripState.completed:
        return 'COMPLETE';
      case TripState.cancelled:
        return 'CANCELLED';
    }
  }

  static String _headline(Trip trip) {
    switch (trip.state) {
      case TripState.assigned:
        // "Kemi · 8 Marina Rd" when we know the rider; just the address
        // otherwise.
        final String? addr = trip.pickupAddress;
        if (trip.hasRiderName) {
          return addr == null
              ? _cap(trip.riderFirstName)
              : '${_cap(trip.riderFirstName)} · $addr';
        }
        return addr ?? 'Head to your pickup';
      case TripState.enRoute:
        return 'On your way to pickup.';
      case TripState.arrived:
        return "${_cap(trip.riderFirstName)} knows you're here.";
      case TripState.inProgress:
        final String to = trip.dropoffAddress ?? 'the drop-off';
        return 'On your way to $to.';
      case TripState.completed:
        return 'Trip complete.';
      case TripState.cancelled:
        return 'Trip cancelled.';
    }
  }

  static String? _sub(Trip trip) {
    switch (trip.state) {
      case TripState.assigned:
        return 'Look for ${trip.riderFirstName} at the pickup point.';
      case TripState.enRoute:
        return trip.pickupAddress == null
            ? '${_cap(trip.riderFirstName)} is waiting.'
            : '${_cap(trip.riderFirstName)} at ${trip.pickupAddress}';
      case TripState.arrived:
        return 'Waiting up to 5 minutes.';
      case TripState.inProgress:
        final int min = trip.durationMin;
        return min > 0 ? '≈ $min min trip' : null;
      case TripState.completed:
      case TripState.cancelled:
        return null;
    }
  }

  /// Capitalise the first letter — "your rider" → "Your rider", and a
  /// lowercase name token → title case — for sentence-leading use.
  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Future<void> _showCancelReasonSheet(
    BuildContext context,
    ActiveTripController c,
  ) async {
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => const _CancelReasonSheet(),
    );
    if (reason != null) {
      await c.cancel(reason: reason);
    }
  }

  /// During pre-pickup states the navigate target is the pickup; during
  /// in_progress it's the dropoff. Arrived/terminal have none.
  _NavTarget? _navTargetFor(Trip trip) {
    switch (trip.state) {
      case TripState.assigned:
      case TripState.enRoute:
        return _NavTarget(
          label: 'Pickup',
          lat: trip.pickupLat,
          lng: trip.pickupLng,
        );
      case TripState.arrived:
        return null;
      case TripState.inProgress:
        return _NavTarget(
          label: 'Drop-off',
          lat: trip.dropoffLat,
          lng: trip.dropoffLng,
        );
      case TripState.completed:
      case TripState.cancelled:
        return null;
    }
  }
}

/// The mockup's button layout per state. Primary is always coral and
/// drives `advance()`; the ghost slot carries Chat (assigned/arrived)
/// or Safety (in-progress). En-route is a single full-width primary.
class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.state,
    required this.controller,
    required this.unreadChats,
  });

  final ActiveTripState state;
  final ActiveTripController controller;
  final int unreadChats;

  @override
  Widget build(BuildContext context) {
    final Trip trip = state.trip!;
    final String cta = state.isAdvancing ? 'Updating…' : _ctaLabel(trip.state);
    final DrivioButton primary = DrivioButton(
      label: cta,
      disabled: state.isAdvancing,
      onPressed: controller.advance,
    );

    switch (trip.state) {
      case TripState.enRoute:
        return primary;
      case TripState.assigned:
      case TripState.arrived:
        return Row(
          children: <Widget>[
            Expanded(
              child: _UnreadBadge(
                count: unreadChats,
                child: DrivioButton(
                  label: 'Chat',
                  variant: DrivioButtonVariant.ghost,
                  onPressed: () =>
                      AppNavigation.push(AppRoutes.chat, arguments: trip.id),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: primary),
          ],
        );
      case TripState.inProgress:
        return Row(
          children: <Widget>[
            Expanded(
              child: DrivioButton(
                label: 'Safety',
                variant: DrivioButtonVariant.ghost,
                onPressed: () =>
                    AppNavigation.push(AppRoutes.safety, arguments: trip.id),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: primary),
          ],
        );
      case TripState.completed:
      case TripState.cancelled:
        return primary;
    }
  }

  /// Mockup-aligned labels (the controller's own advanceLabel differs:
  /// "I'm on my way" / "Complete trip"). The action is identical —
  /// `advance()` — only the wording matches the mockups here.
  static String _ctaLabel(TripState s) {
    switch (s) {
      case TripState.assigned:
        return 'Start drive';
      case TripState.enRoute:
        return "I've arrived";
      case TripState.arrived:
        return 'Start trip';
      case TripState.inProgress:
        return 'End trip';
      case TripState.completed:
        return 'Back online';
      case TripState.cancelled:
        return 'Back to home';
    }
  }
}

/// Quiet row of secondary actions kept out of the hero: Call, Chat
/// (only when it isn't already a primary button), and Navigate.
class _UtilityRow extends ConsumerWidget {
  const _UtilityRow({
    required this.trip,
    required this.navTarget,
    required this.unreadChats,
  });

  final Trip trip;
  final _NavTarget? navTarget;
  final int unreadChats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Chat is a primary button on assigned/arrived — only surface it
    // here on en-route / in-progress so it's always reachable.
    final bool chatInUtility =
        trip.state == TripState.enRoute || trip.state == TripState.inProgress;

    final List<Widget> actions = <Widget>[
      _UtilityAction(
        icon: DrivioIcons.phone,
        label: 'Call',
        onTap: () => showCallSheet(context, ref, tripId: trip.id),
      ),
      if (chatInUtility)
        _UtilityAction(
          icon: DrivioIcons.chat,
          label: 'Chat',
          badgeCount: unreadChats,
          onTap: () => AppNavigation.push(AppRoutes.chat, arguments: trip.id),
        ),
      if (navTarget != null)
        _UtilityAction(
          icon: DrivioIcons.mapTrifold,
          label: 'Navigate',
          onTap: () async {
            final bool ok = await NavigationLauncher.openDriving(
              destLat: navTarget!.lat,
              destLng: navTarget!.lng,
              destLabel: navTarget!.label,
            );
            if (!ok) {
              AppNotifier.error(
                message:
                    "Couldn't open a maps app. Install Google Maps or Apple Maps.",
              );
            }
          },
        ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (int i = 0; i < actions.length; i++) ...<Widget>[
          if (i > 0) Container(width: 1, height: 22, color: context.border),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

class _UtilityAction extends StatelessWidget {
  const _UtilityAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _UnreadBadge(
              count: badgeCount,
              top: -7,
              right: -9,
              child: Icon(icon, size: 18, color: context.text),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.captionSm.copyWith(
                color: context.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coral count bubble pinned to the top-right of [child]. Renders the
/// bare child when [count] is zero.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({
    required this.count,
    required this.child,
    this.top = -6,
    this.right = -4,
  });

  final int count;
  final Widget child;
  final double top;
  final double right;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned(
          top: top,
          right: right,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              color: context.coral,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: context.bg, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              count > 9 ? '9+' : '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: context.coralInk,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "LOCKED FARE" + big coral number (SCR-023).
class _LockedFareBig extends StatelessWidget {
  const _LockedFareBig({required this.naira});
  final int naira;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'LOCKED FARE',
          style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
        ),
        const SizedBox(height: 6),
        Text(
          NairaFormatter.format(naira),
          style: AppTextStyles.priceHero.copyWith(
            fontSize: 40,
            letterSpacing: -1.2,
            color: context.coral,
          ),
        ),
      ],
    );
  }
}

/// Bordered "Locked fare … ₦2,400" row (SCR-024/025/026).
class _LockedFareRow extends StatelessWidget {
  const _LockedFareRow({required this.naira});
  final int naira;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'Locked fare',
            style: AppTextStyles.bodySm.copyWith(
              color: context.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            NairaFormatter.format(naira),
            style: AppTextStyles.h3.copyWith(color: context.coral),
          ),
        ],
      ),
    );
  }
}

class _NavTarget {
  const _NavTarget({required this.label, required this.lat, required this.lng});
  final String label;
  final double lat;
  final double lng;
}

/// DRV-058: pick a reason before cancelling.
class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet();

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
  String? _selected;

  static const List<_CancelReason> _reasons = <_CancelReason>[
    _CancelReason(
      wire: 'passenger_no_show',
      title: 'Passenger no-show',
      sub: "I waited and they didn't appear",
    ),
    _CancelReason(
      wire: 'unsafe_pickup',
      title: 'Unsafe pickup location',
      sub: 'I felt unsafe waiting there',
    ),
    _CancelReason(
      wire: 'vehicle_issue',
      title: 'Vehicle issue',
      sub: 'Flat tyre, breakdown, or other mechanical',
    ),
    _CancelReason(
      wire: 'personal_emergency',
      title: 'Personal emergency',
      sub: 'Something came up and I need to stop',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.text.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            Text(
              'Why are you cancelling?',
              style: AppTextStyles.h1.copyWith(color: context.text),
            ),
            const SizedBox(height: 6),
            Text(
              'The rider will see your reason. Frequent cancellations can lower your acceptance rate.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 16),
            ..._reasons.map((_CancelReason r) {
              final bool active = _selected == r.wire;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = r.wire),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: AppRadius.md,
                      border: Border.all(
                        color: active ? context.red : context.border,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active
                                  ? context.red
                                  : context.borderStrong,
                              width: 2,
                            ),
                            color: active ? context.red : Colors.transparent,
                          ),
                          alignment: Alignment.center,
                          child: active
                              ? Icon(
                                  DrivioIcons.check,
                                  size: 11,
                                  color: context.ivory,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                r.title,
                                style: AppTextStyles.caption.copyWith(
                                  color: context.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.sub,
                                style: AppTextStyles.captionSm.copyWith(
                                  color: context.textDim,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
            DrivioButton(
              label: 'Cancel trip',
              variant: DrivioButtonVariant.danger,
              disabled: _selected == null,
              onPressed: () => Navigator.of(context).pop(_selected),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Keep trip',
                style: AppTextStyles.bodySm.copyWith(color: context.textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelReason {
  const _CancelReason({
    required this.wire,
    required this.title,
    required this.sub,
  });
  final String wire;
  final String title;
  final String sub;
}

/// SCR-027 — Trip complete. Kept as a bottom-sheet body (per decision):
/// coral check disc, "Trip complete." headline, "+₦x" earned, a TRIP
/// RECAP card, a rating row, and Done.
class _CompletedBody extends ConsumerWidget {
  const _CompletedBody({required this.trip, required this.onContinue});
  final Trip trip;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PassengerRatingState rating = ref.watch(
      passengerRatingControllerProvider(trip.id),
    );
    final PassengerRatingController rc = ref.read(
      passengerRatingControllerProvider(trip.id).notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Coral check disc.
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.coral,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(DrivioIcons.check, size: 36, color: context.coralInk),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Trip complete.',
            style: AppTextStyles.screenTitle.copyWith(color: context.text),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '+${NairaFormatter.format(trip.fareNaira)}',
            style: AppTextStyles.priceHero.copyWith(
              fontSize: 44,
              letterSpacing: -1.2,
              color: context.coral,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _RecapCard(trip: trip),
        const SizedBox(height: 16),
        _RatingPanel(
          state: rating,
          controller: rc,
          riderLabel: trip.hasRiderName ? trip.riderFirstName : 'your rider',
        ),
        if (rating.error != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            rating.error!,
            style: AppTextStyles.bodySm.copyWith(color: context.red),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        DrivioButton(
          label: rating.isSubmitting ? 'Submitting…' : 'Done',
          disabled: rating.isSubmitting,
          onPressed: () async {
            // Done saves the rating (if one was given and not already saved),
            // then ends. If the save fails, stay put — the error shows above so
            // the driver can retry. Rating stays optional: no stars → just end.
            if (!rating.submitted && rating.canSubmit) {
              final bool ok = await rc.submit();
              if (!ok) return;
            }
            onContinue();
          },
        ),
      ],
    );
  }
}

/// TRIP RECAP card — pickup / drop-off / distance / duration.
class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final String distance = trip.distanceKm > 0
        ? '${trip.distanceKm.toStringAsFixed(1)} km'
        : '—';
    final String duration = trip.durationMin > 0
        ? '${trip.durationMin} min'
        : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'TRIP RECAP',
              style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
            ),
          ),
          const SizedBox(height: 6),
          _RecapRow(label: 'Pickup', value: trip.pickupAddress ?? '—'),
          _RecapRow(label: 'Drop-off', value: trip.dropoffAddress ?? '—'),
          _RecapRow(label: 'Distance', value: distance),
          _RecapRow(label: 'Duration', value: duration, last: true),
        ],
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({
    required this.label,
    required this.value,
    this.last = false,
  });
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: context.border)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.bodySm.copyWith(color: context.textDim),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySm.copyWith(
                color: context.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingPanel extends StatelessWidget {
  const _RatingPanel({
    required this.state,
    required this.controller,
    required this.riderLabel,
  });
  final PassengerRatingState state;
  final PassengerRatingController controller;
  final String riderLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          state.submitted ? 'You rated $riderLabel' : 'Rate $riderLabel',
          style: AppTextStyles.h2.copyWith(color: context.text),
          textAlign: TextAlign.center,
        ),
        if (state.submitted) ...<Widget>[
          const SizedBox(height: 8),
          Pill(text: 'Saved · ${state.rating}★', tone: PillTone.accent),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(5, (int i) {
            final int value = i + 1;
            final bool filled = value <= state.rating;
            return GestureDetector(
              onTap: state.submitted ? null : () => controller.setRating(value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Icon(
                  DrivioIcons.star,
                  size: 32,
                  color: filled ? context.butter : context.borderStrong,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: kPassengerRatingTags.map((String tag) {
            final bool selected = state.tags.contains(tag);
            return GestureDetector(
              onTap: state.submitted ? null : () => controller.toggleTag(tag),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: selected ? context.coral : context.surface2,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: selected ? Colors.transparent : context.border,
                  ),
                ),
                child: Text(
                  tag,
                  style: AppTextStyles.captionSm.copyWith(
                    color: selected ? context.coralInk : context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CancelledBody extends StatelessWidget {
  const _CancelledBody({required this.trip, required this.onContinue});
  final Trip trip;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Column(
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.close_rounded, size: 30, color: context.red),
              ),
              const SizedBox(height: 14),
              Text(
                'Trip cancelled',
                style: AppTextStyles.h1.copyWith(color: context.text),
              ),
              if (trip.cancellationReason != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  trip.cancellationReason!.replaceAll('_', ' '),
                  style: AppTextStyles.bodySm.copyWith(color: context.textDim),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        DrivioButton(label: 'Back to home', onPressed: onContinue),
      ],
    );
  }
}
