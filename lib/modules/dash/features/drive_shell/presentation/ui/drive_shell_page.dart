import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/location/location_permission_service.dart';
import 'package:drivio_driver/modules/commons/types/demand_cell.dart';
import 'package:drivio_driver/modules/commons/types/ride_request.dart';
import 'package:drivio_driver/modules/commons/types/trip.dart';
import 'package:drivio_driver/modules/commons/widgets/map/live_map.dart';
import 'package:drivio_driver/modules/dash/features/drive_shell/presentation/logic/controller/drive_shell_controller.dart';
import 'package:drivio_driver/modules/dash/features/drive_shell/presentation/ui/widgets/bidding_body.dart';
import 'package:drivio_driver/modules/dash/features/drive_shell/presentation/ui/widgets/home_body.dart';
import 'package:drivio_driver/modules/dash/features/drive_shell/presentation/ui/widgets/trip_body.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/dashboard_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/demand_heatmap_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/home_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/presence_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/driver_tab_bar.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/kyc_gate_sheet.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/location_gate_sheet.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/subscription_gate_sheet.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/vehicle_gate_sheet.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/vehicle_pending_sheet.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';
import 'package:drivio_driver/modules/marketplace/features/feed/presentation/logic/controller/marketplace_controller.dart';
import 'package:drivio_driver/modules/profile/features/notifications_inbox/presentation/logic/controller/notifications_inbox_controller.dart';
import 'package:drivio_driver/modules/subscription/features/paywall/presentation/logic/controller/subscription_controller.dart';
import 'package:drivio_driver/modules/trip/features/active_trip/presentation/logic/controller/active_trip_controller.dart';
import 'package:drivio_driver/modules/trip/features/active_trip/presentation/logic/controller/trip_location_recorder.dart';
import 'package:drivio_driver/modules/trip/features/ride_request/presentation/logic/controller/ride_request_controller.dart';

/// The single home/bidding/trip canvas. One MapLibre instance lives here
/// for the lifetime of the page; bottom-sheet bodies and top overlays
/// morph between modes via the [DriveShellController].
///
/// Other routes (paywall, profile, KYC stepper, etc.) still use the
/// regular navigator and push as separate pages — they're not part of
/// the driving canvas.
class DriveShellPage extends ConsumerStatefulWidget {
  const DriveShellPage({super.key});

  @override
  ConsumerState<DriveShellPage> createState() => _DriveShellPageState();
}

class _DriveShellPageState extends ConsumerState<DriveShellPage> {
  bool _consumedInitialTrip = false;
  bool _gateOpen = false;
  bool _kycGateOpen = false;
  bool _pendingGateOpen = false;
  bool _subGateOpen = false;
  // True when the driver tried to go online without a usable location
  // permission. Holds the snapshot of the failure state so the gate
  // sheet can render the right copy + CTA (re-prompt vs Open Settings).
  bool _locationGateOpen = false;
  LocationPermState _locationGateReason = LocationPermState.unknown;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeControllerProvider.notifier).refreshVehicleStatus();
      ref.read(kycControllerProvider.notifier).refresh();
      ref.read(subscriptionControllerProvider.notifier).refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_consumedInitialTrip) return;
    _consumedInitialTrip = true;
    final Object? arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(driveShellControllerProvider.notifier).enterTrip(arg);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DriveShellState shell = ref.watch(driveShellControllerProvider);
    final HomeState home = ref.watch(homeControllerProvider);
    final HomeController homeC = ref.read(homeControllerProvider.notifier);
    final KycOverallStatus kycStatus =
        ref.watch(kycControllerProvider.select((KycState s) => s.overall));
    final bool kycComplete = kycStatus == KycOverallStatus.approved;
    final SubscriptionState subState =
        ref.watch(subscriptionControllerProvider);
    final bool subUnlocks = subState.unlocksMarketplace;
    final PresenceState presenceState = ref.watch(presenceControllerProvider);

    // ── Mode transitions driven by underlying controllers ───────────────

    // Bidding lifecycle: when bid is accepted, enter trip; when lost, snack
    // + return to idle.
    if (shell.isBidding && shell.activeRequestId != null) {
      ref.listen<RideRequestState>(
        rideRequestControllerProvider(shell.activeRequestId!),
        (RideRequestState? prev, RideRequestState next) {
          if (prev?.phase == next.phase) return;
          if (next.phase == BidPhase.won && next.tripId != null) {
            ref
                .read(driveShellControllerProvider.notifier)
                .enterTrip(next.tripId!);
          } else if (next.phase == BidPhase.lost) {
            AppNotifier.warning(
              message:
                  next.error ?? 'Another driver was picked for this trip.',
            );
            Future<void>.delayed(const Duration(milliseconds: 700), () {
              if (mounted) {
                ref
                    .read(driveShellControllerProvider.notifier)
                    .exitBidding();
              }
            });
          }
        },
      );
    }

    // Trip lifecycle: forward trip-state changes to the recorder + flip
    // the shell to terminal modes when the trip ends.
    if (shell.isTripLike && shell.activeTripId != null) {
      ref.listen<ActiveTripState>(
        activeTripControllerProvider(shell.activeTripId!),
        (ActiveTripState? prev, ActiveTripState next) {
          final TripState? newState = next.state;
          if (newState != null && prev?.state != newState) {
            ref
                .read(tripLocationRecorderProvider(shell.activeTripId!).notifier)
                .onTripStateChanged(newState);

            final DriveShellController shellC =
                ref.read(driveShellControllerProvider.notifier);
            if (newState == TripState.completed) {
              shellC.onTripCompleted();
              // Bump the home tile so the just-finished fare shows up
              // immediately rather than waiting for the 60s ticker.
              ref.read(dashboardControllerProvider.notifier).refresh();
              // DRV-032: if the subscription went hard-blocked while
              // this trip was in flight (we refused to offline mid-trip),
              // honour the gate now that the trip is closed.
              final SubscriptionState s =
                  ref.read(subscriptionControllerProvider);
              if (s.subscription?.status.isHardBlocked ?? false) {
                ref
                    .read(homeControllerProvider.notifier)
                    .setStatus(DriverStatus.offline);
              }
            } else if (newState == TripState.cancelled) {
              // Distinguish passenger-cancelled from driver-cancelled
              // by reading the audit-trail reason. The user app's
              // `cancel_my_active_trip` RPC stamps the trip with
              // `passenger_cancelled`; the driver's own
              // `transition_trip` cancel uses `driver_cancelled` or a
              // specific reason from the cancel-reason sheet.
              final String? reason = next.trip?.cancellationReason;
              final bool byPassenger =
                  reason != null && reason.startsWith('passenger');
              if (byPassenger) {
                AppNotifier.warning(
                  message: 'Passenger cancelled the ride.',
                );
              }
              shellC.onTripCancelled();
            }
          }
        },
      );
    }

    // DRV-032: hard block on subscription expiry. Trigger auto-offline
    // ONLY when the status is hard-blocked (expired/cancelled), never
    // for `pastDue` (Paystack's 3-day grace) so a temporarily-overdue
    // driver isn't booted off mid-shift while the cron retries.
    //
    // The trip-in-progress case is sacred: if the sub flips while a
    // trip is live, we let the trip finish. The post-trip handler
    // (`onTripCompleted`) checks the same condition and offlines then.
    final bool subHardBlocked =
        subState.subscription?.status.isHardBlocked ?? false;
    if (home.isOnline && subHardBlocked && !shell.isTripLike) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        homeC.setStatus(DriverStatus.offline);
        // Cut the realtime channel so a stray request can't render
        // before the next rebuild.
        ref.read(marketplaceControllerProvider.notifier).stop();
      });
    }

    // ── Map props derived from shell mode ───────────────────────────────

    final _MapProps mapProps =
        _computeMapProps(shell, home, presenceState, ref);

    // ── Top overlays + banners ──────────────────────────────────────────

    final Widget topOverlay = _buildTopOverlay(shell, home, kycComplete, subUnlocks, homeC);
    final Widget? banner = _buildBanner(shell, home, kycComplete, kycStatus);
    final Widget? subTop = _buildSubTopArea(shell);
    final Widget? priceBubble = shell.isIdle
        ? _PriceBubble(price: home.priceTrip)
        : null;

    // ── Bottom sheet body ───────────────────────────────────────────────

    final Widget body = _buildBody(shell);

    return ScreenScaffold(
      bottomBar:
          shell.isIdle ? const DriverTabBar(active: DriverTab.drive) : null,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: LiveMap(
              initialCenter: mapProps.initialCenter,
              initialZoom: mapProps.initialZoom,
              showUserLocation: mapProps.showUserLocation,
              followUser: mapProps.followUser,
              markers: mapProps.markers,
              polylines: mapProps.polylines,
              polygons: mapProps.polygons,
            ),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: topOverlay,
          ),
          if (banner != null)
            Positioned(top: 76, left: 16, right: 16, child: banner),
          if (subTop != null)
            Positioned(top: 76, left: 16, right: 16, child: subTop),
          if (priceBubble != null)
            Positioned(bottom: 240, right: 16, child: priceBubble),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (Widget child, Animation<double> a) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: a,
                  curve: Curves.easeOutCubic,
                )),
                child: FadeTransition(opacity: a, child: child),
              );
            },
            child: Align(
              key: ValueKey<String>('body_${shell.mode.name}_'
                  '${shell.activeRequestId ?? shell.activeTripId ?? ''}'),
              alignment: Alignment.bottomCenter,
              child: body,
            ),
          ),
          if (_kycGateOpen)
            KycGateSheet(
              status: kycStatus,
              onDismiss: () => setState(() => _kycGateOpen = false),
              onContinue: () {
                setState(() => _kycGateOpen = false);
                AppNavigation.push<void>(AppRoutes.kycHome);
              },
            ),
          if (_gateOpen)
            VehicleGateSheet(
              onDismiss: () => setState(() => _gateOpen = false),
              onAdd: () {
                setState(() => _gateOpen = false);
                AppNavigation.push(AppRoutes.addVehicle);
              },
            ),
          if (_pendingGateOpen)
            VehiclePendingSheet(
              vehicle: home.pendingVehicle,
              onDismiss: () => setState(() => _pendingGateOpen = false),
            ),
          if (_subGateOpen)
            SubscriptionGateSheet(
              subscription: subState.subscription,
              onDismiss: () => setState(() => _subGateOpen = false),
              onContinue: () {
                setState(() => _subGateOpen = false);
                // Paused users go to the manage page (where the resume
                // control lives); everyone else is funnelled to the
                // paywall.
                final bool paused =
                    subState.subscription?.isPaused ?? false;
                AppNavigation.push<void>(
                  paused ? AppRoutes.subscriptionManage : AppRoutes.paywall,
                );
              },
            ),
          if (_locationGateOpen)
            LocationGateSheet(
              permission: _locationGateReason,
              onDismiss: () => setState(() => _locationGateOpen = false),
              onAllow: () async {
                // Re-trigger the system prompt + try to start streaming
                // again. The presence controller already does both —
                // we just close the sheet and let it run.
                setState(() => _locationGateOpen = false);
                final PresenceController p =
                    ref.read(presenceControllerProvider.notifier);
                final HomeController h =
                    ref.read(homeControllerProvider.notifier);
                final bool ok = await p.startStreaming();
                if (!mounted) return;
                if (ok) {
                  h.toggleOnline();
                  unawaited(ref
                      .read(marketplaceControllerProvider.notifier)
                      .start());
                  unawaited(ref
                      .read(dashboardControllerProvider.notifier)
                      .refresh());
                }
              },
              onOpenSettings: () async {
                final LocationPermissionService svc =
                    locator<LocationPermissionService>();
                if (_locationGateReason == LocationPermState.serviceDisabled) {
                  await svc.openLocationSettings();
                } else {
                  await svc.openAppSettings();
                }
                if (mounted) {
                  setState(() => _locationGateOpen = false);
                }
              },
            ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  _MapProps _computeMapProps(
    DriveShellState shell,
    HomeState home,
    PresenceState presence,
    WidgetRef ref,
  ) {
    final LatLng? driverFix =
        (presence.lastLat != null && presence.lastLng != null)
            ? LatLng(presence.lastLat!, presence.lastLng!)
            : null;

    switch (shell.mode) {
      case ShellMode.idle:
        // Match the feed's filter — pin only what the driver would
        // actually see in the request list.
        final List<RideRequest> openRequests =
            ref.watch(visibleRequestsProvider);
        // DRV-075: render the demand heatmap polygons when the driver
        // has the overlay toggled on. Each cell becomes a square
        // polygon coloured by intensity relative to the hottest cell.
        final DemandHeatmapState heatmap =
            ref.watch(demandHeatmapControllerProvider);
        return _MapProps(
          initialCenter: driverFix,
          initialZoom: 14,
          showUserLocation: home.isOnline,
          followUser: home.isOnline,
          markers: <LiveMapMarker>[
            for (final RideRequest r in openRequests)
              LiveMapMarker(
                id: 'req_${r.id}',
                position: LatLng(r.pickupLat, r.pickupLng),
                kind: LiveMapMarkerKind.request,
              ),
          ],
          polygons: heatmap.visible
              ? _heatmapPolygons(heatmap)
              : const <LiveMapPolygon>[],
        );
      case ShellMode.bidding:
        if (shell.activeRequestId == null) {
          return _MapProps(initialCenter: driverFix, initialZoom: 13);
        }
        final RideRequest? req = ref.watch(
          rideRequestControllerProvider(shell.activeRequestId!)
              .select((RideRequestState s) => s.request),
        );
        if (req == null) {
          return _MapProps(initialCenter: driverFix, initialZoom: 13);
        }
        final LatLng centre = LatLng(
          (req.pickupLat + req.dropoffLat) / 2,
          (req.pickupLng + req.dropoffLng) / 2,
        );
        return _MapProps(
          initialCenter: centre,
          initialZoom: 13,
          showUserLocation: true,
          followUser: false,
          markers: <LiveMapMarker>[
            LiveMapMarker(
              id: 'pickup',
              position: LatLng(req.pickupLat, req.pickupLng),
              kind: LiveMapMarkerKind.pickup,
            ),
            LiveMapMarker(
              id: 'dropoff',
              position: LatLng(req.dropoffLat, req.dropoffLng),
              kind: LiveMapMarkerKind.dropoff,
            ),
          ],
        );
      case ShellMode.trip:
      case ShellMode.tripCompleted:
      case ShellMode.tripCancelled:
        if (shell.activeTripId == null) {
          return _MapProps(initialCenter: driverFix, initialZoom: 14);
        }
        final Trip? trip = ref.watch(
          activeTripControllerProvider(shell.activeTripId!)
              .select((ActiveTripState s) => s.trip),
        );
        if (trip == null) {
          return _MapProps(initialCenter: driverFix, initialZoom: 14);
        }
        // Recorder mutates `samples` by creating a new list each tick, so
        // a select on it correctly fires on each new breadcrumb.
        final List<LatLng> breadcrumb = ref
            .watch(tripLocationRecorderProvider(shell.activeTripId!)
                .select((TripLocationRecorderState s) => s.samples))
            .map((dynamic s) => LatLng(s.lat as double, s.lng as double))
            .toList(growable: false);
        final bool isLive = shell.mode == ShellMode.trip &&
            (trip.state == TripState.enRoute ||
                trip.state == TripState.arrived ||
                trip.state == TripState.inProgress);

        // Forward-looking route line: driver position → pickup (pre-pickup
        // states) or → dropoff (in-progress). Straight-line v1; per spec
        // turn-by-turn is handed off to Google/Apple Maps via DRV-053.
        final List<LiveMapPolyline> lines = <LiveMapPolyline>[];
        if (breadcrumb.length >= 2) {
          lines.add(LiveMapPolyline(
            id: 'breadcrumb',
            points: breadcrumb,
            color: '#34D399', // accent green = where we've been
            width: 5,
            opacity: 0.95,
          ));
        }
        if (driverFix != null && isLive) {
          final LatLng? aheadTarget = _routeAheadTarget(trip);
          if (aheadTarget != null) {
            lines.add(LiveMapPolyline(
              id: 'route_ahead',
              points: <LatLng>[driverFix, aheadTarget],
              color: '#3B82F6', // blue = where we're heading
              width: 4,
              opacity: 0.85,
            ));
          }
        }

        return _MapProps(
          initialCenter: LatLng(trip.pickupLat, trip.pickupLng),
          initialZoom: 15,
          showUserLocation: true,
          followUser: isLive,
          markers: <LiveMapMarker>[
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
          ],
          polylines: lines,
        );
    }
  }

  /// Map the presence controller's permission enum onto the
  /// LocationPermState the gate sheet understands. Both enums carry
  /// the same conceptual states; we keep them separate so the gate
  /// sheet can be shared with the splash without dragging in
  /// presence-controller types.
  static LocationPermState _toGateReason(PresencePermissionState p) {
    switch (p) {
      case PresencePermissionState.granted:
        return LocationPermState.granted;
      case PresencePermissionState.denied:
        return LocationPermState.denied;
      case PresencePermissionState.permanentlyDenied:
        return LocationPermState.permanentlyDenied;
      case PresencePermissionState.serviceDisabled:
        return LocationPermState.serviceDisabled;
      case PresencePermissionState.unknown:
        return LocationPermState.denied;
    }
  }

  /// Where the route-ahead line should terminate based on the current
  /// trip state: pickup until the driver hits "I've arrived", then
  /// dropoff once they "Start trip".
  static LatLng? _routeAheadTarget(Trip trip) {
    switch (trip.state) {
      case TripState.assigned:
      case TripState.enRoute:
        return LatLng(trip.pickupLat, trip.pickupLng);
      case TripState.arrived:
        // Already at pickup — no forward line.
        return null;
      case TripState.inProgress:
        return LatLng(trip.dropoffLat, trip.dropoffLng);
      case TripState.completed:
      case TripState.cancelled:
        return null;
    }
  }

  Widget _buildTopOverlay(
    DriveShellState shell,
    HomeState home,
    bool kycComplete,
    bool subUnlocks,
    HomeController homeC,
  ) {
    switch (shell.mode) {
      case ShellMode.idle:
        return Row(
          children: <Widget>[
            Expanded(
              child: OnlineToggle(
                online: home.isOnline,
                onTap: () async {
                  final PresenceController presence =
                      ref.read(presenceControllerProvider.notifier);

                  if (home.isOnline) {
                    await presence.stopStreaming();
                    await ref
                        .read(marketplaceControllerProvider.notifier)
                        .stop();
                    if (!mounted) return;
                    homeC.toggleOnline();
                    return;
                  }
                  if (!kycComplete) {
                    setState(() => _kycGateOpen = true);
                    return;
                  }
                  if (!subUnlocks) {
                    setState(() => _subGateOpen = true);
                    return;
                  }
                  if (!home.hasVehicle) {
                    setState(() {
                      if (home.hasAnyVehicle) {
                        _pendingGateOpen = true;
                      } else {
                        _gateOpen = true;
                      }
                    });
                    return;
                  }
                  final bool ok = await presence.startStreaming();
                  if (!mounted) return;
                  if (ok) {
                    homeC.toggleOnline();
                    unawaited(ref
                        .read(marketplaceControllerProvider.notifier)
                        .start());
                    // Going online is a definite "show me today's
                    // numbers" moment — refresh the home tile in case
                    // it stalled at zeros during cold start.
                    unawaited(ref
                        .read(dashboardControllerProvider.notifier)
                        .refresh());
                  } else {
                    // startStreaming sets a `permission` field on the
                    // presence state when it bailed for permission/
                    // service reasons. Open the dedicated location
                    // gate sheet so the driver gets a clear path
                    // forward (re-prompt or Open Settings) instead
                    // of just a snackbar.
                    final PresenceState ps =
                        ref.read(presenceControllerProvider);
                    final LocationPermState reason =
                        _toGateReason(ps.permission);
                    if (reason == LocationPermState.granted) {
                      // Permission was OK but something else failed (no
                      // fix yet, network, etc.). Surface as a banner —
                      // the gate sheet wouldn't help.
                      AppNotifier.error(
                        message: ps.error ??
                            "Couldn't start location. Try again in a moment.",
                      );
                    } else {
                      setState(() {
                        _locationGateReason = reason;
                        _locationGateOpen = true;
                      });
                    }
                  }
                },
                label: home.isOnline
                    ? 'Online'
                    : home.isOnTrip
                        ? 'On trip'
                        : 'Offline',
              ),
            ),
            const SizedBox(width: 10),
            // DRV-075: heatmap toggle. Square button styled like the
            // bell so they stack visually.
            _HeatmapToggle(
              active: ref.watch(demandHeatmapControllerProvider).visible,
              onTap: () => ref
                  .read(demandHeatmapControllerProvider.notifier)
                  .toggle(),
            ),
            const SizedBox(width: 10),
            _NotificationBell(
              onTap: () =>
                  AppNavigation.push(AppRoutes.notificationsInbox),
            ),
          ],
        );
      case ShellMode.bidding:
        if (shell.activeRequestId == null) return const SizedBox.shrink();
        final RideRequestState bid = ref.watch(
            rideRequestControllerProvider(shell.activeRequestId!));
        final Color timerColor = bid.secondsLeft <= 5
            ? context.red
            : bid.secondsLeft <= 15
                ? context.amber
                : context.accent;
        return Row(
          children: <Widget>[
            Expanded(
              child: _TimerCard(
                secondsLeft: bid.secondsLeft,
                progress: bid.progressPct,
                color: timerColor,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.border),
              ),
              child: const Rating(value: 4.8),
            ),
          ],
        );
      case ShellMode.trip:
      case ShellMode.tripCompleted:
      case ShellMode.tripCancelled:
        final Trip? trip = shell.activeTripId == null
            ? null
            : ref.watch(activeTripControllerProvider(shell.activeTripId!)
                .select((ActiveTripState s) => s.trip));
        final TripState state = trip?.state ?? TripState.assigned;
        return Row(
          children: <Widget>[
            _StagePill(state: state),
            const Spacer(),
            IconCircleButton(
              icon: DrivioIcons.shield,
              onTap: () => AppNavigation.push(
                AppRoutes.safety,
                arguments: shell.activeTripId,
              ),
            ),
          ],
        );
    }
  }

  Widget? _buildBanner(
    DriveShellState shell,
    HomeState home,
    bool kycComplete,
    KycOverallStatus kycStatus,
  ) {
    if (!shell.isIdle) return null;
    if (home.isOnline) return _DemandBanner();
    if (!kycComplete) return _KycBanner(status: kycStatus);
    if (!home.hasVehicle) {
      return _AddVehicleBanner(
        onAdd: () => setState(() => _gateOpen = true),
      );
    }
    return null;
  }

  /// Mode-specific widget anchored just below the top overlay (where the
  /// banner sits in idle). For trip-like modes we render the route card so
  /// the driver can see pickup/dropoff + ETA at a glance.
  Widget? _buildSubTopArea(DriveShellState shell) {
    if (!shell.isTripLike || shell.activeTripId == null) return null;
    final Trip? trip = ref.watch(
      activeTripControllerProvider(shell.activeTripId!)
          .select((ActiveTripState s) => s.trip),
    );
    if (trip == null) return null;
    return _TripRouteCard(trip: trip);
  }

  Widget _buildBody(DriveShellState shell) {
    switch (shell.mode) {
      case ShellMode.idle:
        return const HomeBody();
      case ShellMode.bidding:
        if (shell.activeRequestId == null) return const SizedBox.shrink();
        return BiddingBody(requestId: shell.activeRequestId!);
      case ShellMode.trip:
      case ShellMode.tripCompleted:
      case ShellMode.tripCancelled:
        if (shell.activeTripId == null) return const SizedBox.shrink();
        return TripBody(tripId: shell.activeTripId!);
    }
  }
}

/// DRV-075: build the per-cell polygons for the demand-heatmap
/// overlay. Each cell becomes a square (rectangle in degrees) coloured
/// from cool to hot relative to the busiest cell in the snapshot.
List<LiveMapPolygon> _heatmapPolygons(DemandHeatmapState heatmap) {
  final int max = heatmap.maxCount;
  if (max <= 0) return const <LiveMapPolygon>[];
  return <LiveMapPolygon>[
    for (final DemandCell c in heatmap.cells)
      LiveMapPolygon(
        id: 'heatmap_${c.cellId}',
        rings: <List<LatLng>>[
          <LatLng>[
            LatLng(
              c.centerLat - c.latSpan / 2,
              c.centerLng - c.lngSpan / 2,
            ),
            LatLng(
              c.centerLat - c.latSpan / 2,
              c.centerLng + c.lngSpan / 2,
            ),
            LatLng(
              c.centerLat + c.latSpan / 2,
              c.centerLng + c.lngSpan / 2,
            ),
            LatLng(
              c.centerLat + c.latSpan / 2,
              c.centerLng - c.lngSpan / 2,
            ),
            LatLng(
              c.centerLat - c.latSpan / 2,
              c.centerLng - c.lngSpan / 2,
            ),
          ],
        ],
        fillColor: _heatmapFill(c.requestCount, max),
        // Opacity scales with intensity but clamped so even single-
        // request cells are still visible.
        fillOpacity: 0.18 + 0.42 * (c.requestCount / max).clamp(0.0, 1.0),
        outlineColor: _heatmapFill(c.requestCount, max),
      ),
  ];
}

/// Five-step ramp: cool teal → amber → red as cell intensity rises.
String _heatmapFill(int count, int max) {
  final double t = (count / max).clamp(0.0, 1.0);
  if (t < 0.2) return '#34D399';   // teal
  if (t < 0.45) return '#FCD34D';  // light amber
  if (t < 0.7) return '#F59E0B';   // amber
  if (t < 0.9) return '#F97316';   // orange
  return '#EF4444';                // red — peak demand
}

class _MapProps {
  const _MapProps({
    this.initialCenter,
    this.initialZoom = 14,
    this.showUserLocation = false,
    this.followUser = false,
    this.markers = const <LiveMapMarker>[],
    this.polylines = const <LiveMapPolyline>[],
    this.polygons = const <LiveMapPolygon>[],
  });

  final LatLng? initialCenter;
  final double initialZoom;
  final bool showUserLocation;
  final bool followUser;
  final List<LiveMapMarker> markers;
  final List<LiveMapPolyline> polylines;
  final List<LiveMapPolygon> polygons;
}

// ── Small overlay widgets re-implemented to live with the shell ────────

class _StagePill extends StatelessWidget {
  const _StagePill({required this.state});
  final TripState state;

  @override
  Widget build(BuildContext context) {
    final (String label, String emoji, Color color) = switch (state) {
      TripState.assigned => ('Trip assigned', '🎯', context.blue),
      TripState.enRoute => ('En route to pickup', '🚗', context.blue),
      TripState.arrived => ('Arrived — waiting', '⏱️', context.amber),
      TripState.inProgress => ('Trip in progress', '✅', context.accent),
      TripState.completed => ('Trip complete', '🎉', context.accent),
      TripState.cancelled => ('Trip cancelled', '🚫', context.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.secondsLeft,
    required this.progress,
    required this.color,
  });

  final int secondsLeft;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              LiveDot(color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Incoming request',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.text,
                  ),
                ),
              ),
              Text(
                '0:${secondsLeft.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 3,
              child: Stack(
                children: <Widget>[
                  Container(color: Colors.white.withValues(alpha: 0.08)),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemandBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.88),
        border: Border.all(color: context.amber.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: context.text),
                children: <InlineSpan>[
                  TextSpan(
                    text: 'High demand',
                    style: TextStyle(
                        color: context.amber, fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text: ' near Victoria Island — great time to raise your rate.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KycBanner extends StatelessWidget {
  const _KycBanner({required this.status});
  final KycOverallStatus status;

  @override
  Widget build(BuildContext context) {
    final bool inReview = status == KycOverallStatus.pendingReview;
    final String headline =
        inReview ? 'Verification under review' : 'Complete verification';
    final String subline = inReview
        ? "We'll notify you when it's approved."
        : 'Upload your docs to start accepting trips.';
    final String cta = inReview ? 'View status' : 'Continue';
    final Color tone = inReview ? context.accent : context.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.92),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Text('🪪', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 12,
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subline,
                  style: TextStyle(fontSize: 11, color: context.text),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => AppNavigation.push<void>(AppRoutes.kycHome),
            style: ElevatedButton.styleFrom(
              backgroundColor: tone,
              foregroundColor: inReview ? context.bg : context.amberInk,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 30),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              cta,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddVehicleBanner extends StatelessWidget {
  const _AddVehicleBanner({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.92),
        border: Border.all(color: context.amber.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Text('🚘', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 12, color: context.text),
                children: <InlineSpan>[
                  TextSpan(
                    text: 'Add your vehicle',
                    style: TextStyle(
                        color: context.amber, fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' to start accepting trips.'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.amber,
              foregroundColor: context.amberInk,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 30),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Add now',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bell with an unread badge driven by [NotificationsInboxController].
/// Subscribing here keeps the badge live even when the inbox isn't open.
/// DRV-075: square button mirroring the notification bell. The icon
/// is theme-tinted when the overlay is showing so the toggle state
/// is unambiguous at a glance.
class _HeatmapToggle extends StatelessWidget {
  const _HeatmapToggle({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconCircleButton(
      icon: active
          ? Icons.local_fire_department
          : Icons.local_fire_department_outlined,
      onTap: onTap,
      fg: active ? context.amber : null,
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int unread = ref.watch(notificationsInboxControllerProvider
        .select((NotificationsInboxState s) => s.unreadCount));

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconCircleButton(
          icon: DrivioIcons.notification,
          onTap: onTap,
        ),
        if (unread > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.red,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: context.bg, width: 2),
              ),
              child: Text(
                unread > 9 ? '9+' : unread.toString(),
                style: TextStyle(
                  color: context.bg,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TripRouteCard extends StatelessWidget {
  const _TripRouteCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.95),
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Vertical pickup → dropoff rail.
          SizedBox(
            width: 12,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 4),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: context.blue,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(
                  height: 22,
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
                Text(
                  'PICKUP',
                  style: AppTextStyles.eyebrow
                      .copyWith(color: context.textDim),
                ),
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
                const SizedBox(height: 6),
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

class _PriceBubble extends StatelessWidget {
  const _PriceBubble({required this.price});
  final int price;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: AppRadius.md,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () => AppNavigation.push(AppRoutes.pricing),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(color: context.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('💸', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text(
                'Price: ${NairaFormatter.format(price)}/trip',
                style: TextStyle(
                  color: context.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
