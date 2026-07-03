import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/trip_location_repository.dart';
import 'package:drivio_driver/modules/commons/types/trip.dart';
import 'package:drivio_driver/modules/commons/widgets/map/live_map.dart';
import 'package:drivio_driver/modules/dash/features/drive_shell/presentation/logic/route_ahead_provider.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/presence_controller.dart';
import 'package:drivio_driver/modules/trip/features/active_trip/presentation/logic/controller/active_trip_controller.dart';
import 'package:drivio_driver/modules/trip/features/active_trip/presentation/logic/controller/trip_location_recorder.dart';
import 'package:drivio_driver/modules/trip/features/call/logic/call_controller.dart';
import 'package:drivio_driver/modules/trip/features/call/presentation/ui/call_sheet.dart';

class ActiveTripPage extends ConsumerStatefulWidget {
  const ActiveTripPage({super.key});

  @override
  ConsumerState<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends ConsumerState<ActiveTripPage>
    with WidgetsBindingObserver {
  String? _tripId;

  /// Last good road shape for the route-to-target line, kept so a transient
  /// empty (while the next directions request loads as the driver moves)
  /// doesn't flash a straight line. Reset when the leg target changes.
  List<LatLng> _lastRouteShape = const <LatLng>[];
  LatLng? _lastRouteTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeCallControllerProvider.notifier).startIncomingWatch();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tripId ??= ModalRoute.of(context)?.settings.arguments as String?;
    _ensureLocationStreaming();
  }

  /// Re-check location whenever the driver returns to the app. If they
  /// revoked permission or turned off location services while away, the
  /// live trip would otherwise silently stop tracking — so we re-request.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      _ensureLocationStreaming();
    }
  }

  void _ensureLocationStreaming() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final PresenceState p = ref.read(presenceControllerProvider);
      if (!p.isStreaming ||
          p.permission != PresencePermissionState.granted) {
        // silent: don't re-pop the notification/battery hardening dialogs the
        // driver already answered, but DO request location if it's missing.
        ref
            .read(presenceControllerProvider.notifier)
            .startStreaming(silent: true);
      }
    });
  }

  /// Act on the permission banner: re-request when it's just denied, or send
  /// the driver to the right Settings screen when it's blocked / services off.
  Future<void> _resolveLocation(PresencePermissionState p) async {
    switch (p) {
      case PresencePermissionState.permanentlyDenied:
        await Geolocator.openAppSettings();
      case PresencePermissionState.serviceDisabled:
        await Geolocator.openLocationSettings();
      case PresencePermissionState.denied:
      case PresencePermissionState.unknown:
      case PresencePermissionState.granted:
        await ref
            .read(presenceControllerProvider.notifier)
            .startStreaming(silent: true);
    }
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
              'No trip to show. Head back to your dashboard.',
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

    // Live route line from the driver's current GPS to the leg target — the
    // rider on the pickup leg, the destination once in progress. Derived
    // from live GPS + the trip, so it reappears immediately on a cold
    // resume (unlike the in-memory breadcrumb above).
    final PresenceState presence = ref.watch(presenceControllerProvider);
    final LatLng? driverPos = presence.hasFix
        ? LatLng(presence.lastLat!, presence.lastLng!)
        : null;
    final LatLng legTarget =
        (trip.state == TripState.assigned || trip.state == TripState.enRoute)
        ? LatLng(trip.pickupLat, trip.pickupLng)
        : LatLng(trip.dropoffLat, trip.dropoffLng);
    final RouteAheadKey? routeKey = driverPos == null
        ? null
        : RouteAheadKey(
            originLat: snapForRouteCache(driverPos.latitude),
            originLng: snapForRouteCache(driverPos.longitude),
            destinationLat: legTarget.latitude,
            destinationLng: legTarget.longitude,
          );
    final List<LatLng> routeShape = routeKey == null
        ? const <LatLng>[]
        : (ref.watch(routeAheadShapeProvider(routeKey)).asData?.value ??
              const <LatLng>[]);
    // Flicker fix: keep the last good shape while the next request loads as
    // the driver moves; reset when the leg target changes.
    if (_lastRouteTarget == null ||
        _lastRouteTarget!.latitude != legTarget.latitude ||
        _lastRouteTarget!.longitude != legTarget.longitude) {
      _lastRouteShape = const <LatLng>[];
      _lastRouteTarget = legTarget;
    }
    if (routeShape.isNotEmpty) {
      _lastRouteShape = routeShape;
    }
    final List<LatLng> effectiveRoute =
        routeShape.isNotEmpty ? routeShape : _lastRouteShape;
    final List<LatLng> routePoints = driverPos == null
        ? const <LatLng>[]
        : (effectiveRoute.length >= 2
              ? <LatLng>[driverPos, ...effectiveRoute]
              : <LatLng>[driverPos, legTarget]);

    // Location is required to keep the live trip tracking. If the driver
    // reopens with it revoked/off, prompt them to restore it.
    final bool needsLocation = isLive &&
        presence.permission != PresencePermissionState.granted &&
        presence.permission != PresencePermissionState.unknown;

    return ScreenScaffold(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: LiveMap(
              initialCenter: LatLng(trip.pickupLat, trip.pickupLng),
              // Close "navigation" zoom that tracks the driver's GPS the
              // whole live trip — both to the rider and on to the drop-off —
              // matching the rider app's close follow zoom.
              initialZoom: 18,
              followUser: isLive,
              markers: markers,
              polylines: <LiveMapPolyline>[
                // Route ahead: driver → current leg target (coral).
                if (routePoints.length >= 2)
                  LiveMapPolyline(
                    id: 'route',
                    points: routePoints,
                    color: '#EE6F4A',
                    width: 6,
                  ),
                // Breadcrumb of where the driver has been (green).
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
                // Safety entry point is parked for now.
                // IconCircleButton(
                //   icon: DrivioIcons.shield,
                //   onTap: () => AppNavigation.push(AppRoutes.safety),
                // ),
              ],
            ),
          ),
          Positioned(
            top: 70,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (needsLocation) ...<Widget>[
                  _LocationPermissionBanner(
                    permission: presence.permission,
                    onResolve: () => _resolveLocation(presence.permission),
                  ),
                  const SizedBox(height: 10),
                ],
                _RouteCard(trip: trip),
              ],
            ),
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
                onTap: () => showCallSheet(context, ref, tripId: trip.id),
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
            // Safety entry point is parked for now — Call and Message
            // stretch to share the freed width.
            // const SizedBox(width: 8),
            // Expanded(
            //   child: _ActionTile(
            //     icon: DrivioIcons.shield,
            //     label: 'Safety',
            //     onTap: () => AppNavigation.push(AppRoutes.safety),
            //   ),
            // ),
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
          'The rider gets notified and your cancellation rate may take a hit.',
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

/// Shown over the active-trip map when location permission/services are
/// missing — the live trip can't track or navigate without them. Gives the
/// driver a one-tap path to restore it (request, or jump to the right
/// Settings screen).
class _LocationPermissionBanner extends StatelessWidget {
  const _LocationPermissionBanner({
    required this.permission,
    required this.onResolve,
  });

  final PresencePermissionState permission;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String body;
    final String action;
    switch (permission) {
      case PresencePermissionState.serviceDisabled:
        title = 'Location is off';
        body = 'Turn on location services so your trip keeps tracking and '
            'you can navigate.';
        action = 'Turn on location';
      case PresencePermissionState.permanentlyDenied:
        title = 'Location is blocked';
        body = 'Open Settings and allow location to continue this trip.';
        action = 'Open settings';
      case PresencePermissionState.denied:
      case PresencePermissionState.unknown:
      case PresencePermissionState.granted:
        title = 'Location needed';
        body = 'Allow location so we can track your trip and guide you to '
            'the rider.';
        action = 'Allow location';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.coral.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.location_off_rounded, size: 18, color: context.coral),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTextStyles.bodySm.copyWith(color: context.textDim),
          ),
          const SizedBox(height: 12),
          DrivioButton(label: action, onPressed: onResolve),
        ],
      ),
    );
  }
}
