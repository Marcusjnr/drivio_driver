import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/ride_request.dart';
import 'package:drivio_driver/modules/dash/features/drive_shell/presentation/logic/controller/drive_shell_controller.dart';
import 'package:drivio_driver/modules/marketplace/features/feed/presentation/logic/controller/marketplace_controller.dart';
import 'package:drivio_driver/modules/marketplace/features/feed/presentation/ui/widgets/request_feed_card.dart';

class RequestFeed extends ConsumerWidget {
  const RequestFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MarketplaceState state = ref.watch(marketplaceControllerProvider);
    // Honour the driver's saved pricing preferences (max pickup distance,
    // trip-length filter). `visibleRequestsProvider` is the
    // marketplace+pricing join.
    final List<RideRequest> requests = ref.watch(visibleRequestsProvider);

    if (requests.isEmpty) {
      return const _EmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // SCR-018 header — "REQUESTS NEARBY · N" in coral.
        Text(
          'REQUESTS NEARBY · ${requests.length}',
          style: AppTextStyles.eyebrow.copyWith(color: context.coral),
        ),
        const SizedBox(height: 10),
        ...requests.take(4).map(
              (RideRequest r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RequestFeedCard(
                  request: r,
                  driverLat: state.driverLat,
                  driverLng: state.driverLng,
                  onTap: () => ref
                      .read(driveShellControllerProvider.notifier)
                      .enterBidding(r.id),
                ),
              ),
            ),
      ],
    );
  }
}

/// DRV-095: when the feed has been empty for a while, show a rotating
/// tip set so the screen doesn't feel stale.
const Duration _kQuietPeriodBeforeTips = Duration(seconds: 60);
const Duration _kTipRotateInterval = Duration(seconds: 6);
const List<_NoRequestsTip> _kNoRequestsTips = <_NoRequestsTip>[
  _NoRequestsTip(text: 'Demand picks up at 6–9 PM. Stick around.'),
  _NoRequestsTip(text: 'Drift toward Victoria Island for higher fares.'),
  _NoRequestsTip(text: 'Lower your suggested price for more bites.'),
  _NoRequestsTip(text: 'Fuel costs eat margins — short trips compound.'),
  _NoRequestsTip(text: 'Rain spikes demand. Stay online when the sky turns grey.'),
];

class _EmptyState extends StatefulWidget {
  const _EmptyState();

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  late final DateTime _emptySince;
  Timer? _quietTimer;
  Timer? _rotateTimer;
  bool _showTips = false;
  int _tipIdx = 0;

  @override
  void initState() {
    super.initState();
    _emptySince = DateTime.now();
    _quietTimer = Timer(_kQuietPeriodBeforeTips, () {
      if (!mounted) return;
      setState(() => _showTips = true);
      _rotateTimer = Timer.periodic(_kTipRotateInterval, (_) {
        if (!mounted) return;
        setState(() {
          _tipIdx = (_tipIdx + 1) % _kNoRequestsTips.length;
        });
      });
    });
  }

  @override
  void dispose() {
    _quietTimer?.cancel();
    _rotateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showTips) {
      return _WaitingCard(
        title: 'NO REQUESTS YET',
        message: "You're online. Hang tight…",
      );
    }

    final _NoRequestsTip tip = _kNoRequestsTips[_tipIdx];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'NO REQUESTS YET',
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
          ),
          const SizedBox(height: 6),
          Text(
            _waitingFor(_emptySince),
            style: TextStyle(
              fontSize: 13,
              color: context.text,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              tip.text,
              key: ValueKey<int>(_tipIdx),
              style: TextStyle(fontSize: 12, color: context.textDim),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  static String _waitingFor(DateTime since) {
    final Duration d = DateTime.now().difference(since);
    if (d.inMinutes < 1) return "You're online. Hang tight…";
    return "You've been online for ${d.inMinutes} min — riders just haven't pinged yet.";
  }
}

class _NoRequestsTip {
  const _NoRequestsTip({required this.text});
  final String text;
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: context.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
