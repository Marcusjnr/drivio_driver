import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:drivio_driver/modules/commons/all.dart';

/// Loading-state placeholder for the Profile hub. Mirrors the real
/// page's section structure (header → stats row → 5 grouped cards) so
/// the layout doesn't jump when real data arrives.
///
/// The shimmer wraps the full layout so a single sweep animates the
/// entire skeleton — much cheaper than animating each block
/// independently and visually consistent across the page.
class ProfileHubShimmer extends StatelessWidget {
  const ProfileHubShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final Color base = context.surface2;
    final Color highlight = context.surface3;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header — avatar + two stacked text bars + status pill.
          Row(
            children: <Widget>[
              const _Box(width: 60, height: 60, radius: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    _Box(width: 160, height: 18),
                    SizedBox(height: 8),
                    _Box(width: 110, height: 12),
                  ],
                ),
              ),
              const _Box(width: 70, height: 22, radius: 11),
            ],
          ),
          const SizedBox(height: 16),
          // Stats card — two-column metric band + full-width vehicle line.
          const _StatsCardSkeleton(),
          const SizedBox(height: 18),
          // Five group cards mirroring the real page sections.
          _GroupSkeleton(rows: 3),  // VEHICLE
          SizedBox(height: 16),
          _GroupSkeleton(rows: 3),  // DOCUMENTS
          SizedBox(height: 16),
          _GroupSkeleton(rows: 1, tallFirstRow: true),  // REVIEWS preview
          SizedBox(height: 16),
          _GroupSkeleton(rows: 3),  // ACCOUNT
          SizedBox(height: 16),
          _GroupSkeleton(rows: 3),  // SETTINGS
        ],
      ),
    );
  }
}

/// One filled rounded rectangle the shimmer paints over.
class _Box extends StatelessWidget {
  const _Box({
    required this.width,
    required this.height,
    this.radius = 4,
  });

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

/// Mirrors `_StatsCard` on the real page: a divided two-metric band on
/// top, then the icon-disc vehicle line — one card, same heights.
class _StatsCardSkeleton extends StatelessWidget {
  const _StatsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.md,
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: const <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Box(width: 50, height: 9),
                      SizedBox(height: 8),
                      _Box(width: 70, height: 18),
                    ],
                  ),
                ),
                SizedBox(width: 25),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Box(width: 90, height: 9),
                      SizedBox(height: 8),
                      _Box(width: 60, height: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              children: const <Widget>[
                _Box(width: 32, height: 32, radius: 10),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Box(width: 50, height: 9),
                    SizedBox(height: 5),
                    _Box(width: 130, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Group card with a title bar above and N row placeholders inside.
/// `tallFirstRow` boosts the first row height (used for the REVIEWS
/// section which renders the preview review card).
class _GroupSkeleton extends StatelessWidget {
  const _GroupSkeleton({required this.rows, this.tallFirstRow = false});

  final int rows;
  final bool tallFirstRow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _Box(width: 80, height: 9),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.md,
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < rows; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: _RowLine(
                    isTall: tallFirstRow && i == 0,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RowLine extends StatelessWidget {
  const _RowLine({required this.isTall});

  final bool isTall;

  @override
  Widget build(BuildContext context) {
    if (isTall) {
      // Mirrors the REVIEWS preview card (avatar + 2 lines + comment).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          Row(
            children: <Widget>[
              _Box(width: 32, height: 32, radius: 16),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Box(width: 110, height: 12),
                    SizedBox(height: 6),
                    _Box(width: 70, height: 10),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _Box(width: double.infinity, height: 10),
          SizedBox(height: 6),
          _Box(width: 220, height: 10),
        ],
      );
    }
    return Row(
      children: const <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Box(width: 140, height: 12),
              SizedBox(height: 6),
              _Box(width: 90, height: 10),
            ],
          ),
        ),
        SizedBox(width: 12),
        _Box(width: 14, height: 14, radius: 7),
      ],
    );
  }
}
