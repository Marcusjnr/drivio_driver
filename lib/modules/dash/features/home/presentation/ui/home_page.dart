import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/ride_request.dart';
import 'package:drivio_driver/modules/commons/widgets/map/live_map.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/home_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/presence_controller.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/driver_tab_bar.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/kyc_gate_sheet.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/subscription_gate_sheet.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/vehicle_gate_sheet.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/ui/widgets/vehicle_pending_sheet.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';
import 'package:drivio_driver/modules/marketplace/features/feed/presentation/logic/controller/marketplace_controller.dart';
import 'package:drivio_driver/modules/marketplace/features/feed/presentation/ui/widgets/request_feed.dart';
import 'package:drivio_driver/modules/subscription/features/paywall/presentation/logic/controller/subscription_controller.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _gateOpen = false;
  bool _kycGateOpen = false;
  bool _pendingGateOpen = false;
  bool _subGateOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(homeControllerProvider.notifier).refreshVehicleStatus();
        ref.read(kycControllerProvider.notifier).refresh();
        ref.read(subscriptionControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final HomeState state = ref.watch(homeControllerProvider);
    final HomeController c = ref.read(homeControllerProvider.notifier);
    final KycOverallStatus kycStatus =
        ref.watch(kycControllerProvider.select((KycState s) => s.overall));
    final bool kycComplete = kycStatus == KycOverallStatus.approved;
    final SubscriptionState subState = ref.watch(subscriptionControllerProvider);
    final bool subUnlocks = subState.unlocksMarketplace;

    // Push the latest GPS fix into the marketplace controller so cards can
    // sort by distance.
    ref.listen<PresenceState>(presenceControllerProvider,
        (PresenceState? prev, PresenceState next) {
      if (next.lastLat != null &&
          next.lastLng != null &&
          (prev?.lastLat != next.lastLat || prev?.lastLng != next.lastLng)) {
        ref
            .read(marketplaceControllerProvider.notifier)
            .updateDriverPosition(next.lastLat!, next.lastLng!);
      }
    });

    // Force-offline if subscription flipped while online (mid-trip is exempt
    // upstream — we never enter onTrip via the online toggle).
    if (state.isOnline && subState.subscription != null && !subUnlocks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.setStatus(DriverStatus.offline);
      });
    }
    // Pull live position + open requests from their controllers so we can
    // pass them straight into LiveMap as the driver dot is handled
    // natively while incoming requests render as amber pins.
    final PresenceState presenceState = ref.watch(presenceControllerProvider);
    // Map pins respect the driver's pricing preferences too — no point
    // showing an amber dot for a request the feed itself filters out.
    final List<RideRequest> openRequests =
        ref.watch(visibleRequestsProvider);
    final LatLng? driverFix =
        (presenceState.lastLat != null && presenceState.lastLng != null)
            ? LatLng(presenceState.lastLat!, presenceState.lastLng!)
            : null;

    return ScreenScaffold(
      bottomBar: const DriverTabBar(active: DriverTab.drive),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          LiveMap(
            // Centre on the latest GPS fix once we have one. Until then,
            // LiveMap's default Lagos centre handles the first paint.
            initialCenter: driverFix,
            initialZoom: 14,
            showUserLocation: state.isOnline,
            followUser: state.isOnline,
            markers: <LiveMapMarker>[
              for (final RideRequest r in openRequests)
                LiveMapMarker(
                  id: 'req_${r.id}',
                  position: LatLng(r.pickupLat, r.pickupLng),
                  kind: LiveMapMarkerKind.request,
                ),
            ],
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OnlineToggle(
                    online: state.isOnline,
                    onTap: () async {
                      final PresenceController presence =
                          ref.read(presenceControllerProvider.notifier);

                      if (state.isOnline) {
                        // Going offline: stop streaming + marketplace, then flip UI.
                        await presence.stopStreaming();
                        await ref
                            .read(marketplaceControllerProvider.notifier)
                            .stop();
                        if (!mounted) return;
                        c.toggleOnline();
                        return;
                      }

                      // Going online — run gate chain first.
                      if (!kycComplete) {
                        setState(() => _kycGateOpen = true);
                        return;
                      }
                      if (!subUnlocks) {
                        setState(() => _subGateOpen = true);
                        return;
                      }
                      if (!state.hasVehicle) {
                        setState(() {
                          if (state.hasAnyVehicle) {
                            _pendingGateOpen = true;
                          } else {
                            _gateOpen = true;
                          }
                        });
                        return;
                      }

                      // Gates passed → start location streaming. Only flip
                      // the toggle if the stream actually starts.
                      final bool ok = await presence.startStreaming();
                      if (!mounted) return;
                      if (ok) {
                        c.toggleOnline();
                        // Kick off the marketplace feed in parallel.
                        unawaited(ref
                            .read(marketplaceControllerProvider.notifier)
                            .start());
                      } else {
                        final String? err =
                            ref.read(presenceControllerProvider).error;
                        AppNotifier.error(
                          message: err ?? 'Could not start location.',
                        );
                      }
                    },
                    label: state.isOnline
                        ? 'Online'
                        : state.isOnTrip
                            ? 'On trip'
                            : 'Offline',
                  ),
                ),
                const SizedBox(width: 10),
                IconCircleButton(
                  icon: DrivioIcons.notification,
                  // The standalone preferences page was removed (Q4);
                  // the bell now opens the in-app notifications inbox.
                  onTap: () =>
                      AppNavigation.push(AppRoutes.notificationsInbox),
                ),
              ],
            ),
          ),
          if (state.isOnline)
            Positioned(
              top: 64,
              left: 16,
              right: 16,
              child: _DemandBanner(),
            ),
          if (!kycComplete && !state.isOnline)
            Positioned(
              top: 64,
              left: 16,
              right: 16,
              child: _KycBanner(status: kycStatus),
            )
          else if (!state.hasVehicle && !state.isOnline)
            Positioned(
              top: 64,
              left: 16,
              right: 16,
              child: _AddVehicleBanner(
                onAdd: () => setState(() => _gateOpen = true),
              ),
            ),
          Positioned(
            bottom: 240,
            right: 16,
            child: _PriceBubble(price: state.priceTrip),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomSheet(state: state),
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
              vehicle: state.pendingVehicle,
              onDismiss: () => setState(() => _pendingGateOpen = false),
            ),
          if (_subGateOpen)
            SubscriptionGateSheet(
              subscription: subState.subscription,
              onDismiss: () => setState(() => _subGateOpen = false),
              onContinue: () {
                setState(() => _subGateOpen = false);
                AppNavigation.push<void>(AppRoutes.paywall);
              },
            ),
        ],
      ),
    );
  }
}

class _DemandBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    style: TextStyle(color: context.amber, fontWeight: FontWeight.w700),
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

class _KycBanner extends ConsumerWidget {
  const _KycBanner({required this.status});
  final KycOverallStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool inReview = status == KycOverallStatus.pendingReview;
    final String headline = inReview ? 'Verification under review' : 'Complete verification';
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 30),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              cta,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddVehicleBanner extends ConsumerWidget {
  const _AddVehicleBanner({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    style: TextStyle(color: context.amber, fontWeight: FontWeight.w700),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(0, 30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

class _PriceBubble extends ConsumerWidget {
  const _PriceBubble({required this.price});
  final int price;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class _BottomSheet extends ConsumerWidget {
  const _BottomSheet({required this.state});
  final HomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isOnTrip) {
      return BottomSheetCard(
        child: InkWell(
          onTap: () => AppNavigation.push(AppRoutes.activeTrip),
          child: Row(
            children: <Widget>[
              const Avatar(name: 'Kemi A', variant: 3, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'En route to pickup · 4 min',
                      style: AppTextStyles.caption.copyWith(color: context.textDim),
                    ),
                    Text(
                      'Kemi A · ${NairaFormatter.format(state.priceTrip)}',
                      style: AppTextStyles.h3.copyWith(color: context.text),
                    ),
                  ],
                ),
              ),
              Icon(DrivioIcons.chevron, color: context.textDim),
            ],
          ),
        ),
      );
    }
    return BottomSheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "TODAY'S EARNINGS",
                      style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      NairaFormatter.format(state.todaysEarnings),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: context.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const Pill(text: '+18% vs avg', tone: PillTone.accent),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(child: _MiniMetric(value: state.tripsToday.toString(), label: 'Trips')),
              const SizedBox(width: 8),
              Expanded(child: _MiniMetric(value: '${state.hoursOnline}h', label: 'Online')),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  value: state.rating.toStringAsFixed(1),
                  label: 'Rating',
                  showStar: true,
                ),
              ),
            ],
          ),
          if (state.isOnline) ...<Widget>[
            const SizedBox(height: 14),
            const RequestFeed(),
          ],
        ],
      ),
    );
  }
}

class _MiniMetric extends ConsumerWidget {
  const _MiniMetric({
    required this.value,
    required this.label,
    this.showStar = false,
  });

  final String value;
  final String label;
  final bool showStar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (showStar) ...<Widget>[
                Icon(DrivioIcons.star, size: 14, color: context.amber),
                const SizedBox(width: 2),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: showStar ? context.amber : context.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.textDim),
          ),
        ],
      ),
    );
  }
}
