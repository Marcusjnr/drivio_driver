import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';

class KycHomePage extends ConsumerStatefulWidget {
  const KycHomePage({super.key});

  @override
  ConsumerState<KycHomePage> createState() => _KycHomePageState();
}

class _KycHomePageState extends ConsumerState<KycHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(kycControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final KycState state = ref.watch(kycControllerProvider);
    final KycController c = ref.read(kycControllerProvider.notifier);

    return ScreenScaffold(
      child: RefreshIndicator(
        onRefresh: c.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  BackButtonBox(onTap: () => AppNavigation.pop()),
                  const SizedBox(width: 12),
                  _OverallPill(status: state.overall),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Complete your\nverification.',
                style: AppTextStyles.h1.copyWith(color: context.text),
              ),
              const SizedBox(height: 6),
              Text(
                'Each step takes a few minutes. You can pause and come back any time.',
                style: AppTextStyles.bodySm.copyWith(color: context.textDim),
              ),
              if (state.error != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  state.error!,
                  style: AppTextStyles.bodySm.copyWith(color: context.red),
                ),
              ],
              const SizedBox(height: 22),
              if (state.steps.isEmpty && state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ...state.steps.map(
                  (KycStep s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StepRow(step: s),
                  ),
                ),
              const SizedBox(height: 18),
              if (state.overall == KycOverallStatus.pendingReview)
                _ReviewBanner(text: 'Your application is being reviewed.')
              else if (state.overall == KycOverallStatus.approved)
                _ReviewBanner(text: 'You\'re approved. Welcome to Drivio!')
              else
                DrivioButton(
                  label: state.isSubmitting
                      ? 'Submitting…'
                      : 'Submit for review',
                  disabled: !state.canSubmitForReview || state.isSubmitting,
                  onPressed: () async {
                    final bool ok = await c.submitForReview();
                    if (!ok) return;
                    AppNotifier.success(
                      message: "Submitted. We'll notify you when reviewed.",
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverallPill extends StatelessWidget {
  const _OverallPill({required this.status});
  final KycOverallStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (status) {
      case KycOverallStatus.approved:
        bg = context.accent.withValues(alpha: 0.18);
        fg = context.accent;
        break;
      case KycOverallStatus.pendingReview:
        bg = context.amber.withValues(alpha: 0.18);
        fg = context.amber;
        break;
      case KycOverallStatus.rejected:
        bg = context.red.withValues(alpha: 0.18);
        fg = context.red;
        break;
      case KycOverallStatus.notStarted:
      case KycOverallStatus.inProgress:
        bg = context.borderStrong;
        fg = context.textDim;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.captionSm.copyWith(
          fontSize: 11,
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final KycStep step;

  @override
  Widget build(BuildContext context) {
    final (Color border, Color iconColor, IconData icon) = switch (step.status) {
      KycStepStatus.approved => (
          context.accent,
          context.accent,
          DrivioIcons.check
        ),
      KycStepStatus.submitted => (
          context.amber,
          context.amber,
          DrivioIcons.refresh
        ),
      KycStepStatus.rejected => (
          context.red,
          context.red,
          DrivioIcons.close
        ),
      KycStepStatus.expired => (
          context.amber,
          context.amber,
          DrivioIcons.refresh
        ),
      KycStepStatus.required => (
          context.borderStrong,
          context.textDim,
          DrivioIcons.chevron
        ),
    };

    final bool isInteractive = step.status == KycStepStatus.required ||
        step.status == KycStepStatus.rejected ||
        step.status == KycStepStatus.expired;

    return Opacity(
      opacity: isInteractive ? 1 : 0.55,
      child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isInteractive ? () => _routeForStep(step.kind) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    step.title,
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.rejectionReason ?? step.subtitle,
                    style: AppTextStyles.captionSm.copyWith(
                      fontSize: 11,
                      color: step.status == KycStepStatus.rejected
                          ? context.red
                          : context.textDim,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _shortLabel(step.status),
              style: AppTextStyles.captionSm.copyWith(
                fontSize: 11,
                color: iconColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  static String _shortLabel(KycStepStatus s) {
    switch (s) {
      case KycStepStatus.approved:
        return 'Approved';
      case KycStepStatus.submitted:
        return 'In review';
      case KycStepStatus.rejected:
        return 'Re-do';
      case KycStepStatus.expired:
        return 'Renew';
      case KycStepStatus.required:
        return 'Start';
    }
  }

  void _routeForStep(KycStepKind kind) {
    switch (kind) {
      case KycStepKind.bvnNin:
        AppNavigation.push<void>(AppRoutes.kycBvnNin);
      case KycStepKind.selfie:
        AppNavigation.push<void>(AppRoutes.kycSelfie);
      case KycStepKind.driversLicence:
        AppNavigation.push<void>(
          AppRoutes.kycDocumentCapture,
          arguments: DocumentKind.driversLicence,
        );
      case KycStepKind.vehicle:
        AppNavigation.push<void>(AppRoutes.addVehicle);
      case KycStepKind.vehicleReg:
        AppNavigation.push<void>(
          AppRoutes.kycDocumentCapture,
          arguments: DocumentKind.vehicleReg,
        );
      case KycStepKind.insurance:
        AppNavigation.push<void>(
          AppRoutes.kycDocumentCapture,
          arguments: DocumentKind.insurance,
        );
      case KycStepKind.roadWorthiness:
        AppNavigation.push<void>(
          AppRoutes.kycDocumentCapture,
          arguments: DocumentKind.roadWorthiness,
        );
    }
  }
}

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.accent),
      ),
      child: Row(
        children: <Widget>[
          Icon(DrivioIcons.check, color: context.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: context.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
