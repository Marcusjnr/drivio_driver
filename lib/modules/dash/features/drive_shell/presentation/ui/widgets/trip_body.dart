import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/passenger_rating.dart';
import 'package:drivio_driver/modules/commons/types/trip.dart';
import 'package:drivio_driver/modules/commons/utils/navigation_launcher.dart';
import 'package:drivio_driver/modules/dash/features/drive_shell/presentation/logic/controller/drive_shell_controller.dart';
import 'package:drivio_driver/modules/trip/features/active_trip/presentation/logic/controller/active_trip_controller.dart';
import 'package:drivio_driver/modules/trip/features/active_trip/presentation/logic/controller/passenger_rating_controller.dart';

/// Bottom-sheet body shown in any trip-like shell mode.
class TripBody extends ConsumerWidget {
  const TripBody({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActiveTripState state =
        ref.watch(activeTripControllerProvider(tripId));
    final ActiveTripController c =
        ref.read(activeTripControllerProvider(tripId).notifier);

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
                onPressed: () => ref
                    .read(driveShellControllerProvider.notifier)
                    .exitTrip(),
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
              onContinue: () => ref
                  .read(driveShellControllerProvider.notifier)
                  .exitTrip(),
            )
          : isCancelled
              ? _CancelledBody(
                  trip: trip,
                  onContinue: () => ref
                      .read(driveShellControllerProvider.notifier)
                      .exitTrip(),
                )
              : _InTripBody(state: state, controller: c),
    );
  }
}

class _InTripBody extends StatelessWidget {
  const _InTripBody({required this.state, required this.controller});

  final ActiveTripState state;
  final ActiveTripController controller;

  @override
  Widget build(BuildContext context) {
    final Trip trip = state.trip!;
    final String stageLabel = _stageLabel(trip.state);
    final _NavTarget? navTarget = _navTargetFor(trip);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Avatar(name: 'Rider', variant: 3, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Rider',
                    style: AppTextStyles.body.copyWith(
                      color: context.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    stageLabel,
                    style: AppTextStyles.captionSm
                        .copyWith(color: context.textDim),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  'FARE · LOCKED',
                  style: AppTextStyles.eyebrow
                      .copyWith(color: context.textDim),
                ),
                Text(
                  NairaFormatter.format(trip.fareNaira),
                  style: AppTextStyles.h2.copyWith(color: context.accent),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: _ActionTile(
                icon: DrivioIcons.phone,
                label: 'Call',
                onTap: () =>
                    AppNavigation.push(AppRoutes.call, arguments: trip.id),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionTile(
                icon: DrivioIcons.chat,
                label: 'Message',
                onTap: () =>
                    AppNavigation.push(AppRoutes.chat, arguments: trip.id),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionTile(
                icon: DrivioIcons.shield,
                label: 'Safety',
                onTap: () =>
                    AppNavigation.push(AppRoutes.safety, arguments: trip.id),
              ),
            ),
          ],
        ),
        if (state.error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            state.error!,
            style: AppTextStyles.bodySm.copyWith(color: context.red),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 12),
        DrivioButton(
          label: state.isAdvancing ? 'Updating…' : state.advanceLabel,
          disabled: state.isAdvancing,
          onPressed: controller.advance,
        ),
        if (navTarget != null) ...<Widget>[
          const SizedBox(height: 8),
          DrivioButton(
            label: navTarget.label,
            variant: DrivioButtonVariant.ghost,
            onPressed: () async {
              final bool ok = await NavigationLauncher.openDriving(
                destLat: navTarget.lat,
                destLng: navTarget.lng,
                destLabel: navTarget.label,
              );
              if (!ok) {
                AppNotifier.error(
                  message: 'No maps app could open this destination.',
                );
              }
            },
          ),
        ],
        const SizedBox(height: 6),
        TextButton(
          onPressed: state.isAdvancing
              ? null
              : () => _showCancelReasonSheet(context, controller),
          child: Text(
            'Cancel trip',
            style: AppTextStyles.captionSm.copyWith(color: context.textDim),
          ),
        ),
      ],
    );
  }

  Future<void> _showCancelReasonSheet(
      BuildContext context, ActiveTripController c) async {
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

  static String _stageLabel(TripState s) {
    switch (s) {
      case TripState.assigned:
        return 'Assigned · head to pickup';
      case TripState.enRoute:
        return 'En route to pickup';
      case TripState.arrived:
        return 'Arrived · waiting';
      case TripState.inProgress:
        return 'Trip in progress';
      case TripState.completed:
        return 'Trip complete';
      case TripState.cancelled:
        return 'Trip cancelled';
    }
  }

  /// During pre-pickup states, the navigate button targets the pickup.
  /// During in_progress, it targets the dropoff. Other states have no
  /// useful navigation target.
  _NavTarget? _navTargetFor(Trip trip) {
    switch (trip.state) {
      case TripState.assigned:
      case TripState.enRoute:
        return _NavTarget(
          label: 'Navigate to pickup',
          lat: trip.pickupLat,
          lng: trip.pickupLng,
        );
      case TripState.arrived:
        // Already at pickup; nothing to navigate to.
        return null;
      case TripState.inProgress:
        return _NavTarget(
          label: 'Navigate to dropoff',
          lat: trip.dropoffLat,
          lng: trip.dropoffLng,
        );
      case TripState.completed:
      case TripState.cancelled:
        return null;
    }
  }
}

class _NavTarget {
  const _NavTarget({
    required this.label,
    required this.lat,
    required this.lng,
  });
  final String label;
  final double lat;
  final double lng;
}

/// DRV-058: pick a reason before cancelling. Returns the wire reason
/// string via Navigator.pop, or null if the driver dismissed.
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
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: context.borderStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Text(
              'Why are you cancelling?',
              style: AppTextStyles.h2.copyWith(color: context.text),
            ),
            const SizedBox(height: 4),
            Text(
              "The rider will see your reason. Frequent cancellations can lower your acceptance rate.",
              style: AppTextStyles.caption.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 14),
            ..._reasons.map((_CancelReason r) {
              final bool active = _selected == r.wire;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = r.wire),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
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
                              color:
                                  active ? context.red : context.borderStrong,
                              width: 2,
                            ),
                            color: active ? context.red : Colors.transparent,
                          ),
                          alignment: Alignment.center,
                          child: active
                              ? Icon(DrivioIcons.check,
                                  size: 11, color: context.bg)
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
                                  fontSize: 11,
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
                style: AppTextStyles.caption.copyWith(color: context.textDim),
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

class _CompletedBody extends ConsumerWidget {
  const _CompletedBody({required this.trip, required this.onContinue});
  final Trip trip;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PassengerRatingState rating =
        ref.watch(passengerRatingControllerProvider(trip.id));
    final PassengerRatingController rc =
        ref.read(passengerRatingControllerProvider(trip.id).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Column(
            children: <Widget>[
              Text(
                'YOU EARNED',
                style:
                    AppTextStyles.eyebrow.copyWith(color: context.textDim),
              ),
              const SizedBox(height: 6),
              Text(
                NairaFormatter.format(trip.fareNaira),
                style: AppTextStyles.priceHero.copyWith(
                  fontSize: 44,
                  letterSpacing: -1.2,
                  color: context.accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Credited to your wallet',
                style:
                    AppTextStyles.captionSm.copyWith(color: context.textDim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _RatingPanel(state: rating, controller: rc),
        if (rating.error != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            rating.error!,
            style: AppTextStyles.bodySm.copyWith(color: context.red),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 12),
        DrivioButton(label: 'Back online', onPressed: onContinue),
      ],
    );
  }
}

class _RatingPanel extends StatelessWidget {
  const _RatingPanel({required this.state, required this.controller});
  final PassengerRatingState state;
  final PassengerRatingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                state.submitted ? 'YOU RATED THE RIDER' : 'RATE THE RIDER',
                style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
              ),
              if (state.submitted)
                Pill(text: 'Saved · ${state.rating}★', tone: PillTone.accent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(5, (int i) {
              final int value = i + 1;
              final bool filled = value <= state.rating;
              return GestureDetector(
                onTap: state.submitted ? null : () => controller.setRating(value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    DrivioIcons.star,
                    size: 30,
                    color: filled ? context.amber : context.borderStrong,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kPassengerRatingTags.map((String tag) {
              final bool selected = state.tags.contains(tag);
              return GestureDetector(
                onTap: state.submitted ? null : () => controller.toggleTag(tag),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        selected ? context.accent : context.surface2,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: selected ? Colors.transparent : context.border,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: AppTextStyles.captionSm.copyWith(
                      fontSize: 11,
                      color: selected ? context.accentInk : context.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (!state.submitted) ...<Widget>[
            const SizedBox(height: 10),
            DrivioButton(
              label: state.isSubmitting ? 'Submitting…' : 'Submit rating',
              variant: DrivioButtonVariant.accent,
              disabled: !state.canSubmit,
              onPressed: controller.submit,
            ),
          ],
        ],
      ),
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
                child: Icon(
                  Icons.close_rounded,
                  size: 30,
                  color: context.red,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Trip cancelled',
                style: AppTextStyles.h2.copyWith(color: context.text),
              ),
              if (trip.cancellationReason != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  trip.cancellationReason!.replaceAll('_', ' '),
                  style:
                      AppTextStyles.captionSm.copyWith(color: context.textDim),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface2,
      borderRadius: AppRadius.md,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(color: context.border),
          ),
          child: Column(
            children: <Widget>[
              Icon(icon, color: context.text, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.captionSm.copyWith(
                  fontSize: 11,
                  color: context.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
