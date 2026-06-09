import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/ride_request.dart';

class RequestFeedCard extends ConsumerStatefulWidget {
  const RequestFeedCard({
    super.key,
    required this.request,
    required this.driverLat,
    required this.driverLng,
    required this.onTap,
  });

  final RideRequest request;
  final double? driverLat;
  final double? driverLng;
  final VoidCallback onTap;

  @override
  ConsumerState<RequestFeedCard> createState() => _RequestFeedCardState();
}

class _RequestFeedCardState extends ConsumerState<RequestFeedCard> {
  Timer? _ticker;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.request.secondsRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = widget.request.secondsRemaining());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RideRequest r = widget.request;
    final bool urgent = _secondsLeft <= 15;
    // The expiry colour stays coral until the last 15s, then flips to
    // red as a genuine warning — coral is "live", red is "about to lapse".
    final Color timerColor = urgent ? context.red : context.coral;

    final String? tripKm = r.expectedDistanceM != null
        ? _fmtKm(r.expectedDistanceM!.toDouble())
        : null;
    final String? tripMin = r.expectedDurationS != null
        ? '~${r.expectedDurationS! ~/ 60} min'
        : null;
    final String meta =
        <String?>[tripKm, tripMin].whereType<String>().join(' · ');

    return InkWell(
      onTap: _secondsLeft <= 0 ? null : widget.onTap,
      borderRadius: AppRadius.md,
      child: Opacity(
        opacity: _secondsLeft <= 0 ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.md,
            border: Border.all(
              color: urgent
                  ? context.red.withValues(alpha: 0.6)
                  : context.borderStrong,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Pickup row + expiry pill, top-right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _PinDot(color: context.coral, square: false),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AddressLine(
                      label: 'Pickup',
                      value: r.pickupAddress ?? 'Pickup',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fmtClock(_secondsLeft),
                    style: AppTextStyles.mono.copyWith(
                      color: timerColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Drop-off row.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _PinDot(color: context.teal, square: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AddressLine(
                      label: 'Drop-off',
                      value: r.dropoffAddress ?? 'Dropoff',
                    ),
                  ),
                ],
              ),
              if (meta.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text(
                    meta,
                    style: AppTextStyles.captionSm.copyWith(
                      color: context.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "00:42" mm:ss expiry clock per the SCR-018 mockup.
  static String _fmtClock(int seconds) {
    if (seconds <= 0) return '00:00';
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _fmtKm(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

/// Coral pickup disc / teal drop-off square — the map-pin language
/// echoed in the list (brand §4.4: coral = pickup, teal = the other end).
class _PinDot extends StatelessWidget {
  const _PinDot({required this.color, required this.square});

  final Color color;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: color,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(2) : null,
      ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: AppTextStyles.bodySm.copyWith(color: context.text),
        children: <InlineSpan>[
          TextSpan(
            text: '$label: ',
            style: AppTextStyles.bodySm.copyWith(color: context.textDim),
          ),
          TextSpan(
            text: value,
            style: AppTextStyles.bodySm.copyWith(
              color: context.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
