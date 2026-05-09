import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/profile_summary.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/profile/features/referral/presentation/logic/controller/referral_controller.dart';

class ReferralPage extends ConsumerWidget {
  const ReferralPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReferralState state = ref.watch(referralControllerProvider);
    final ReferralSummary s = state.summary;
    final String? code = s.myCode;

    return DetailScaffold(
      title: 'Refer & earn',
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                context.accent.withValues(alpha: 0.16),
                context.accent.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: AppRadius.lg,
            border: Border.all(color: context.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: <Widget>[
              const Text('🎁', style: TextStyle(fontSize: 38)),
              const SizedBox(height: 8),
              Text(
                'Get 1 free month\nfor every driver you bring.',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(color: context.text),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 260,
                child: Text(
                  'Your friend gets a free month too. No limit — refer as many drivers as you like.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: context.textDim,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'YOUR CODE',
          style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.base,
            border: Border.all(color: context.borderStrong),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  state.isLoading
                      ? 'Loading…'
                      : (code ?? 'No code yet'),
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: code == null
                        ? context.textDim
                        : context.accent,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: code == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        AppNotifier.success(
                          message: 'Copied to clipboard',
                          duration: const Duration(seconds: 2),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accent,
                  foregroundColor: context.accentInk,
                  disabledBackgroundColor:
                      context.accent.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Copy',
                  style: AppTextStyles.captionSm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DrivioButton(
          label: 'Share code',
          // Share-sheet integration is its own ticket; the button is
          // disabled until then so we don't ship a non-functional CTA.
          onPressed: code == null ? null : null,
        ),
        DetailGroup(
          title: 'YOUR REFERRALS',
          topMargin: 24,
          children: <Widget>[
            FieldRow(
              label: 'Total drivers referred',
              value: state.isLoading ? '—' : '${s.totalReferred}',
            ),
            FieldRow(
              label: 'Free months earned',
              // 1 free month per ACTIVE referred driver per the
              // headline copy at the top of the page.
              value: state.isLoading
                  ? '—'
                  : '${s.activeReferred} · worth ${NairaFormatter.format(s.activeReferred * 15000)}',
            ),
            FieldRow(
              label: 'Pending (sign-up, not yet active)',
              value: state.isLoading ? '—' : '${s.pendingReferred}',
              divider: false,
            ),
          ],
        ),
        if (state.error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            state.error!,
            style: AppTextStyles.bodySm.copyWith(color: context.red),
          ),
        ],
      ],
    );
  }
}
