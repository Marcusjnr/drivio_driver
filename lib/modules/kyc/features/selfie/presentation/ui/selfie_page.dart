import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';
import 'package:drivio_driver/modules/kyc/features/selfie/presentation/logic/controller/selfie_controller.dart';

class SelfiePage extends ConsumerWidget {
  const SelfiePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SelfieState state = ref.watch(selfieControllerProvider);
    final SelfieController c = ref.read(selfieControllerProvider.notifier);

    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BackButtonBox(onTap: () => AppNavigation.pop()),
            const SizedBox(height: 18),
            Text(
              'Take a quick\nselfie.',
              style: AppTextStyles.h1.copyWith(color: context.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Face the camera in good light. Remove sunglasses and hats.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
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
                        child: Icon(DrivioIcons.camera,
                            size: 44, color: context.textDim),
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
              label: state.isCapturing
                  ? 'Opening camera…'
                  : state.hasPreview
                      ? 'Retake'
                      : 'Open camera',
              variant: state.hasPreview
                  ? DrivioButtonVariant.ghost
                  : DrivioButtonVariant.accent,
              disabled: state.isCapturing || state.isSubmitting,
              onPressed: state.hasPreview ? c.clear : c.capture,
            ),
            if (state.hasPreview) ...<Widget>[
              const SizedBox(height: 8),
              DrivioButton(
                label: state.isSubmitting ? 'Submitting…' : 'Submit selfie',
                disabled: state.isSubmitting,
                onPressed: () async {
                  final bool ok = await c.submit();
                  if (!context.mounted || !ok) return;
                  await ref.read(kycControllerProvider.notifier).refresh();
                  if (!context.mounted) return;
                  AppNavigation.pop();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
