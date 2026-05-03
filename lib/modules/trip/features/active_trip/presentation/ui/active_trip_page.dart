import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/trip_location_repository.dart';
import 'package:drivio_driver/modules/commons/types/trip.dart';
import 'package:drivio_driver/modules/commons/widgets/map/live_map.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/presence_controller.dart';
import 'package:drivio_driver/modules/trip/features/active_trip/presentation/logic/controller/active_trip_controller.dart';
import 'package:drivio_driver/modules/trip/features/active_trip/presentation/logic/controller/trip_location_recorder.dart';

class ActiveTripPage extends ConsumerStatefulWidget {
  const ActiveTripPage({super.key});

  @override
  ConsumerState<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends ConsumerState<ActiveTripPage> {
  String? _tripId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tripId ??= ModalRoute.of(context)?.settings.arguments as String?;
    // Ensure GPS is streaming — covers the cold-start resume case where
    // the user was routed straight to /active-trip without going through
    // the home page's online toggle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final PresenceController presence =
          ref.read(presenceControllerProvider.notifier);
      if (!ref.read(presenceControllerProvider).isStreaming) {
        presence.startStreaming();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? id = _tripId;
    if (id == null) {
      return ScreenScaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No trip selected.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
            ),
          ),
        ),
      );
    }

    final ActiveTripState state = ref.watch(activeTripControllerProvider(id));
    final ActiveTripController c =
        ref.read(activeTripControllerProvider(id).notifier);

    // Forward every trip-state change into the location recorder. It
    // starts on entry to a live state and stops on terminal.
    ref.listen<ActiveTripState>(activeTripControllerProvider(id),
        (ActiveTripState? prev, ActiveTripState next) {
      final TripState? newState = next.state;
      if (newState != null && prev?.state != newState) {
        ref
            .read(tripLocationRecorderProvider(id).notifier)
            .onTripStateChanged(newState);
      }
    });

    if (state.isLoading) {
      return const ScreenScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final Trip? trip = state.trip;
    if (trip == null) {
      return ScreenScaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              state.error ?? 'Trip unavailable.',
              style: AppTextStyles.bodySm.copyWith(color: context.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final _StageInfo info = _stageInfo(context, trip.state);
    final bool isCompleted = trip.state == TripState.completed;
    final bool isCancelled = trip.state == TripState.cancelled;
    final bool isLive = !isCompleted && !isCancelled;

    final List<LiveMapMarker> markers = <LiveMapMarker>[
      LiveMapMarker(
        id: 'pickup',
        position: LatLng(trip.pickupLat, trip.pickupLng),
        kind: LiveMapMarkerKind.pickup,
      ),
      LiveMapMarker(
        id: 'dropoff',
        position: LatLng(trip.dropoffLat, trip.dropoffLng),
        kind: LiveMapMarkerKind.dropoff,
      ),
    ];

    // Recorded breadcrumb path. Watch the recorder slice so polyline
    // updates incrementally without rebuilding the rest of the page.
    final List<LatLng> path = ref
        .watch(
          tripLocationRecorderProvider(id)
              .select((TripLocationRecorderState s) => s.samples),
        )
        .map((TripLocationSample s) => LatLng(s.lat, s.lng))
        .toList(growable: false);

    return ScreenScaffold(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: LiveMap(
              initialCenter: LatLng(trip.pickupLat, trip.pickupLng),
              initialZoom: 15,
              followUser: isLive,
              markers: markers,
              polylines: <LiveMapPolyline>[
                if (path.length >= 2)
                  LiveMapPolyline(
                    id: 'breadcrumb',
                    points: path,
                    color: '#34D399',
                    width: 5,
                  ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: info.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(info.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        info.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: info.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconCircleButton(
                  icon: DrivioIcons.shield,
                  onTap: () => AppNavigation.push(AppRoutes.safety),
                ),
              ],
            ),
          ),
          Positioned(
            top: 70,
            left: 16,
            right: 16,
            child: _RouteCard(trip: trip),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomSheetCard(
              child: isCompleted
                  ? _CompletedBody(trip: trip)
                  : isCancelled
                      ? _CancelledBody(trip: trip)
                      : _InTripBody(state: state, info: info, controller: c),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
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
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: VerticalDivider(
                    color: context.borderStrong,
                    thickness: 2,
                  ),
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
                    style: AppTextStyles.eyebrow
                        .copyWith(color: context.textDim)),
                Text(
                  trip.pickupAddress ?? 'Pickup',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'DROP-OFF · ${trip.distanceKm.toStringAsFixed(1)} KM · ${trip.durationMin} MIN',
                  style: AppTextStyles.eyebrow
                      .copyWith(color: context.textDim),
                ),
                Text(
                  trip.dropoffAddress ?? 'Dropoff',
                  style: TextStyle(
                    fontSize: 13,
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
    );
  }
}

class _InTripBody extends ConsumerWidget {
  const _InTripBody({
    required this.state,
    required this.info,
    required this.controller,
  });

  final ActiveTripState state;
  final _StageInfo info;
  final ActiveTripController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Trip trip = state.trip!;
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
                    style: TextStyle(
                      fontSize: 15,
                      color: context.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    info.label,
                    style: TextStyle(fontSize: 12, color: context.textDim),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text('FARE · LOCKED',
                    style: AppTextStyles.eyebrow
                        .copyWith(color: context.textDim)),
                Text(
                  NairaFormatter.format(trip.fareNaira),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                  ),
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
                onTap: () => AppNavigation.push(AppRoutes.call),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionTile(
                icon: DrivioIcons.chat,
                label: 'Message',
                onTap: () => AppNavigation.push(AppRoutes.chat),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionTile(
                icon: DrivioIcons.shield,
                label: 'Safety',
                onTap: () => AppNavigation.push(AppRoutes.safety),
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
        const SizedBox(height: 6),
        TextButton(
          onPressed: state.isAdvancing
              ? null
              : () => _confirmCancel(context, controller),
          child: Text(
            'Cancel trip',
            style: TextStyle(color: context.textDim, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmCancel(
      BuildContext context, ActiveTripController c) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: ctx.surface,
        title: Text('Cancel this trip?',
            style: TextStyle(color: ctx.text, fontWeight: FontWeight.w700)),
        content: Text(
          "You're about to cancel. The rider will be notified and your cancellation rate may be affected.",
          style: TextStyle(color: ctx.textDim, fontSize: 13),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep trip',
                style: TextStyle(color: ctx.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Cancel trip',
                style: TextStyle(color: ctx.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (yes == true) {
      await c.cancel();
    }
  }
}

class _CompletedBody extends StatelessWidget {
  const _CompletedBody({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Column(
            children: <Widget>[
              Text('YOU EARNED',
                  style: AppTextStyles.eyebrow
                      .copyWith(color: context.textDim)),
              const SizedBox(height: 4),
              Text(
                NairaFormatter.format(trip.fareNaira),
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                  color: context.accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Credited to your wallet',
                style: TextStyle(fontSize: 12, color: context.textDim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.surface2,
            borderRadius: AppRadius.md,
          ),
          child: Column(
            children: <Widget>[
              _Row(
                  label: 'Agreed fare',
                  value: NairaFormatter.format(trip.fareNaira)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.border)),
                ),
                child: _Row(
                  label: 'Total to you',
                  value: NairaFormatter.format(trip.fareNaira),
                  bold: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DrivioButton(
          label: 'Back online',
          onPressed: () => AppNavigation.replaceAll<void>(AppRoutes.home),
        ),
      ],
    );
  }
}

class _CancelledBody extends StatelessWidget {
  const _CancelledBody({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Column(
            children: <Widget>[
              const Text('🚫', style: TextStyle(fontSize: 38)),
              const SizedBox(height: 8),
              Text(
                'Trip cancelled',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.text,
                ),
              ),
              if (trip.cancellationReason != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  trip.cancellationReason!,
                  style: TextStyle(fontSize: 12, color: context.textDim),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        DrivioButton(
          label: 'Back to home',
          onPressed: () => AppNavigation.replaceAll<void>(AppRoutes.home),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.bold = false,
  });
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: TextStyle(fontSize: 13, color: context.textDim)),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 14 : 13,
            color: context.text,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
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
                style: TextStyle(
                  fontSize: 11,
                  color: context.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageInfo {
  _StageInfo({
    required this.label,
    required this.color,
    required this.emoji,
  });
  final String label;
  final Color color;
  final String emoji;
}

_StageInfo _stageInfo(BuildContext context, TripState state) {
  switch (state) {
    case TripState.assigned:
      return _StageInfo(
        label: 'Trip assigned',
        color: context.blue,
        emoji: '🎯',
      );
    case TripState.enRoute:
      return _StageInfo(
        label: 'En route to pickup',
        color: context.blue,
        emoji: '🚗',
      );
    case TripState.arrived:
      return _StageInfo(
        label: 'Arrived — waiting',
        color: context.amber,
        emoji: '⏱️',
      );
    case TripState.inProgress:
      return _StageInfo(
        label: 'Trip in progress',
        color: context.accent,
        emoji: '✅',
      );
    case TripState.completed:
      return _StageInfo(
        label: 'Trip complete',
        color: context.accent,
        emoji: '🎉',
      );
    case TripState.cancelled:
      return _StageInfo(
        label: 'Trip cancelled',
        color: context.red,
        emoji: '🚫',
      );
  }
}
