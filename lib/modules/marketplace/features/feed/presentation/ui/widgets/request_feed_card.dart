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
    final double? distM = (widget.driverLat != null && widget.driverLng != null)
        ? r.distanceMetersFrom(widget.driverLat!, widget.driverLng!)
        : null;
    final bool urgent = _secondsLeft <= 15;
    final Color tone = urgent ? context.red : context.amber;

    return InkWell(
      onTap: _secondsLeft <= 0 ? null : widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: _secondsLeft <= 0 ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.md,
            border: Border.all(
              color: urgent
                  ? context.red.withValues(alpha: 0.6)
                  : context.borderStrong,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _secondsLeft > 0 ? _secondsLeft.toString() : '0',
                  style: TextStyle(
                    color: tone,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            r.pickupAddress ?? 'Pickup',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distM != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            _fmtKm(distM),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textDim,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Icon(DrivioIcons.chevron,
                            size: 12, color: context.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            r.dropoffAddress ?? 'Dropoff',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textDim,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        if (r.expectedDistanceM != null) ...<Widget>[
                          _Tag(label: '${_fmtKm(r.expectedDistanceM!.toDouble())} trip'),
                          const SizedBox(width: 6),
                        ],
                        if (r.expectedDurationS != null)
                          _Tag(label: '${(r.expectedDurationS! ~/ 60)} min'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtKm(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: context.textDim),
      ),
    );
  }
}
