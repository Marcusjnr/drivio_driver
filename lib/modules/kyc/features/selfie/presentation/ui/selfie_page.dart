import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';
import 'package:drivio_driver/modules/kyc/features/selfie/presentation/logic/controller/selfie_controller.dart';
import 'package:drivio_driver/modules/kyc/features/selfie/presentation/ui/liveness_capture_page.dart';

/// KYC face-liveness step. Runs the on-device liveness check (blink +
/// smile + anti-spoofing); the captured image becomes both the KYC selfie
/// and the driver's profile photo, and passing it sets the server-side
/// liveness flag that unblocks ride requests.
class SelfiePage extends ConsumerWidget {
  const SelfiePage({super.key});

  Future<void> _runFaceCheck(BuildContext context, WidgetRef ref) async {
    final String? imagePath = await Navigator.of(context).push<String?>(
      MaterialPageRoute<String?>(
        fullscreenDialog: true,
        builder: (BuildContext _) => const LivenessCapturePage(),
      ),
    );
    if (imagePath == null || !context.mounted) {
      return;
    }
    final bool ok = await ref
        .read(selfieControllerProvider.notifier)
        .submit(imagePath);
    if (!context.mounted || !ok) {
      return;
    }
    await ref.read(kycControllerProvider.notifier).refresh();
    if (!context.mounted) {
      return;
    }
    AppNavigation.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SelfieState state = ref.watch(selfieControllerProvider);

    // Set only when this page is reached via the guided rejection-fix flow
    // (RejectedItemsPage or the document-rejected push deep link) — a normal
    // first-time onboarding visit passes no arguments.
    final Object? arg = ModalRoute.of(context)?.settings.arguments;
    final String? rejectionReason = arg is String && arg.trim().isNotEmpty
        ? arg
        : null;

    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BackButtonBox(onTap: () => AppNavigation.pop()),
            const SizedBox(height: 18),
            Text(
              "Verify it's\nreally you.",
              style: AppTextStyles.h1.copyWith(color: context.text),
            ),
            const SizedBox(height: 6),
            Text(
              "We'll ask you to blink and smile so we know you're a real "
              'person. This photo also becomes your profile picture, so '
              'face the camera in good light and remove sunglasses and hats.',
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            if (rejectionReason != null) ...<Widget>[
              const SizedBox(height: 16),
              _RejectionReasonBanner(reason: rejectionReason),
            ],
            const SizedBox(height: 22),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: AppRadius.lg,
                  border: Border.all(
                    color: state.hasPreview
                        ? context.accent
                        : context.borderStrong,
                  ),
                  image: state.hasPreview
                      ? DecorationImage(
                          image: MemoryImage(state.previewBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: state.hasPreview
                    ? null
                    : Center(
                        child: Icon(
                          DrivioIcons.camera,
                          size: 44,
                          color: context.textDim,
                        ),
                      ),
              ),
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: AppTextStyles.bodySm.copyWith(color: context.red),
              ),
            ],
            const SizedBox(height: 22),
            DrivioButton(
              label: state.isSubmitting ? 'Saving…' : 'Start face check',
              loading: state.isSubmitting,
              onPressed: state.isSubmitting
                  ? null
                  : () => _runFaceCheck(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the previous selfie didn't pass review — shown up front, before the
/// capture control, mirroring `DocumentCapturePage`'s reason banner.
class _RejectionReasonBanner extends StatelessWidget {
  const _RejectionReasonBanner({required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.red.withValues(alpha: 0.10),
        borderRadius: AppRadius.md,
        border: Border.all(color: context.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(DrivioIcons.close, size: 16, color: context.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Why this was rejected',
                  style: AppTextStyles.captionSm.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.red,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: AppTextStyles.bodySm.copyWith(
                    color: context.text,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
