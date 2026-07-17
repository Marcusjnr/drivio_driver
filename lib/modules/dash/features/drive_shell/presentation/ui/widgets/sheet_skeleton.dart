import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:drivio_driver/modules/commons/all.dart';

/// Skeleton bottom sheets shown while a shell sheet body hydrates.
///
/// They carry the destination sheet's real chrome (surface, top radius,
/// hairline, drag handle) so the thing that slides up during a shell
/// mode transition already reads as the next sheet — the shimmer only
/// stands in for its content. Each layout mirrors the real body's
/// structure so nothing jumps when data lands.
class SheetSkeleton extends StatelessWidget {
  const SheetSkeleton.bidding({super.key}) : _layout = _Layout.bidding;

  const SheetSkeleton.trip({super.key}) : _layout = _Layout.trip;

  final _Layout _layout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: context.text.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Shimmer.fromColors(
            baseColor: context.surface2,
            highlightColor: context.surface3,
            period: const Duration(milliseconds: 1400),
            child: _layout == _Layout.bidding
                ? const _BiddingSkeleton()
                : const _TripSkeleton(),
          ),
        ],
      ),
    );
  }
}

enum _Layout { bidding, trip }

/// Mirrors the bid composer: route rows → YOUR PRICE block → variant
/// tabs → quick chips → you-keep line → Decline / Submit.
class _BiddingSkeleton extends StatelessWidget {
  const _BiddingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _RouteLine(widthFactor: 0.85),
        const SizedBox(height: 12),
        const _RouteLine(widthFactor: 0.7),
        const SizedBox(height: 20),
        const Center(child: _Box(width: 90, height: 10)),
        const SizedBox(height: 12),
        const Center(child: _Box(width: 180, height: 44, radius: 8)),
        const SizedBox(height: 8),
        const Center(child: _Box(width: 130, height: 10)),
        const SizedBox(height: 18),
        const _Box(width: double.infinity, height: 40, radius: 12),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            for (int i = 0; i < 4; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              const Expanded(
                child: _Box(width: double.infinity, height: 46, radius: 14),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        const Center(child: _Box(width: 120, height: 10)),
        const SizedBox(height: 14),
        Row(
          children: const <Widget>[
            Expanded(
              child: _Box(width: double.infinity, height: 52, radius: 16),
            ),
            SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _Box(width: double.infinity, height: 52, radius: 16),
            ),
          ],
        ),
      ],
    );
  }
}

/// Mirrors the active-trip sheet: rider row → route rows → primary CTA.
class _TripSkeleton extends StatelessWidget {
  const _TripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: const <Widget>[
            _Box(width: 44, height: 44, radius: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Box(width: 130, height: 13),
                  SizedBox(height: 6),
                  _Box(width: 80, height: 10),
                ],
              ),
            ),
            SizedBox(width: 12),
            _Box(width: 40, height: 40, radius: 20),
          ],
        ),
        const SizedBox(height: 18),
        const _RouteLine(widthFactor: 0.85),
        const SizedBox(height: 12),
        const _RouteLine(widthFactor: 0.7),
        const SizedBox(height: 20),
        const _Box(width: double.infinity, height: 52, radius: 16),
      ],
    );
  }
}

/// Route row shape: leading dot + one text bar.
class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const _Box(width: 10, height: 10, radius: 5),
        const SizedBox(width: 12),
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthFactor,
            child: const _Box(width: double.infinity, height: 12),
          ),
        ),
      ],
    );
  }
}

/// One filled rounded rectangle the shimmer paints over.
class _Box extends StatelessWidget {
  const _Box({required this.width, required this.height, this.radius = 4});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white, // recoloured by the Shimmer ancestor
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
