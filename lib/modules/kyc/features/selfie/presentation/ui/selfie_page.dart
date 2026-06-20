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
