import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/driver_rating.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/profile/features/reviews/presentation/logic/controller/driver_reviews_controller.dart';

/// Default star value rendered before the first rating lands. Picked
/// to match the home tile fallback so the two stay in sync visually.
const double _kRatingPlaceholder = 5.0;

class ReviewsPage extends ConsumerWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DriverReviewsState state =
        ref.watch(driverReviewsControllerProvider);
    final DriverRatingSummary summary = state.summary;
    final double headlineRating = summary.average30d ??
        summary.average ??
        _kRatingPlaceholder;
    final int subtitleCount =
        summary.count30d > 0 ? summary.count30d : summary.count;

    return DetailScaffold(
      title: 'Reviews',
      subtitle: subtitleCount == 0
          ? 'No ratings yet'
          : '$subtitleCount trip${subtitleCount == 1 ? '' : 's'} rated',
      children: <Widget>[
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...<Widget>[
          if (state.error != null) ...<Widget>[
            _ErrorBanner(
              message: state.error!,
              onRetry: () => ref
                  .read(driverReviewsControllerProvider.notifier)
                  .refresh(),
            ),
            const SizedBox(height: 16),
          ],
          _SummaryHeader(
            headlineRating: headlineRating,
            distribution: summary.distributionPercent,
            isPlaceholder: summary.count == 0,
          ),
          if (summary.count > 0) ...<Widget>[
            const SizedBox(height: 18),
            _TopTags(reviews: state.reviews),
          ],
          const SizedBox(height: 18),
          if (state.reviews.isEmpty)
            _EmptyReviewsCard(isError: state.error != null)
          else
            ..._buildReviewCards(state.reviews),
        ],
      ],
    );
  }

  List<Widget> _buildReviewCards(List<DriverRating> reviews) {
    return <Widget>[
      for (final DriverRating r in reviews)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ReviewCard(review: r),
        ),
    ];
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.headlineRating,
    required this.distribution,
    required this.isPlaceholder,
  });

  final double headlineRating;
  final List<int> distribution; // length 5: [5★%, 4★%, 3★%, 2★%, 1★%]
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Column(
          children: <Widget>[
            Text(
              isPlaceholder ? '—' : headlineRating.toStringAsFixed(1),
              style: AppTextStyles.priceHero.copyWith(
                fontSize: 44,
                letterSpacing: -1.4,
                color: isPlaceholder ? context.textDim : context.amber,
              ),
            ),
            const SizedBox(height: 4),
            Rating(value: isPlaceholder ? 0 : headlineRating),
            const SizedBox(height: 2),
            Text(
              isPlaceholder ? 'No ratings yet' : 'Last 30 days',
              style: AppTextStyles.captionSm
                  .copyWith(fontSize: 11, color: context.textDim),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < distribution.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: _DistributionRow(
                    stars: 5 - i,
                    percent: distribution[i],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({required this.stars, required this.percent});

  final int stars;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 12,
          child: Text(
            '$stars',
            style: AppTextStyles.captionSm
                .copyWith(fontSize: 11, color: context.textDim),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: <Widget>[
                  Container(color: context.surface2),
                  FractionallySizedBox(
                    widthFactor: (percent / 100).clamp(0.0, 1.0),
                    child: Container(color: context.amber),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$percent%',
            textAlign: TextAlign.right,
            style: AppTextStyles.captionSm
                .copyWith(fontSize: 11, color: context.textDim),
          ),
        ),
      ],
    );
  }
}

/// Aggregates the most-frequent tags across the loaded reviews. We
/// intentionally derive this client-side rather than adding a tag-
/// frequency RPC — the trailing 25 reviews give a representative
/// sample without another round trip.
class _TopTags extends StatelessWidget {
  const _TopTags({required this.reviews});

  final List<DriverRating> reviews;

  @override
  Widget build(BuildContext context) {
    final Map<String, int> counts = <String, int>{};
    for (final DriverRating r in reviews) {
      for (final String t in r.tags) {
        if (t.trim().isEmpty) continue;
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const SizedBox.shrink();
    final List<MapEntry<String, int>> sorted = counts.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    final Iterable<MapEntry<String, int>> top = sorted.take(5);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final MapEntry<String, int> e in top)
          _TagChip(text: '${e.key} · ${e.value}'),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final DriverRating review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.base,
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Avatar(
                name: review.passengerName,
                // Stable avatar variant per passenger so colours don't
                // shimmer on re-render.
                variant: review.passengerId.hashCode.abs() % 4,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      review.passengerName,
                      style: AppTextStyles.caption.copyWith(
                        color: context.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        Rating(value: review.rating.toDouble()),
                        const SizedBox(width: 6),
                        Text(
                          '· ${_relativeAge(review.createdAt)}',
                          style: AppTextStyles.captionSm
                              .copyWith(fontSize: 11, color: context.textDim),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '"${review.comment}"',
              style: AppTextStyles.caption.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
          ],
          if (review.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                for (final String t in review.tags) _TagChip(text: t),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _relativeAge(DateTime t) {
    final Duration d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'yesterday';
    if (d.inDays < 7) return '${d.inDays}d ago';
    if (d.inDays < 30) return '${(d.inDays / 7).floor()}w ago';
    if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo ago';
    return '${(d.inDays / 365).floor()}y ago';
  }
}

class _EmptyReviewsCard extends StatelessWidget {
  const _EmptyReviewsCard({required this.isError});
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.base,
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: <Widget>[
          const Text('🌱', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 10),
          Text(
            isError
                ? 'Could not load your reviews.'
                : 'Reviews from your passengers will show up here.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: context.textDim,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.red.withValues(alpha: 0.08),
        borderRadius: AppRadius.sm,
        border: Border.all(color: context.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.captionSm.copyWith(color: context.red),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'RETRY',
              style: AppTextStyles.eyebrow.copyWith(color: context.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border),
      ),
      child: Text(
        text,
        style: AppTextStyles.captionSm.copyWith(
          fontSize: 11,
          color: context.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
