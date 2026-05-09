import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/document_capture/presentation/logic/controller/document_capture_controller.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';

class DocumentCapturePage extends ConsumerStatefulWidget {
  const DocumentCapturePage({super.key});

  @override
  ConsumerState<DocumentCapturePage> createState() =>
      _DocumentCapturePageState();
}

class _DocumentCapturePageState extends ConsumerState<DocumentCapturePage> {
  bool _initialized = false;
  DocumentKind _kind = DocumentKind.driversLicence;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final Object? arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is DocumentKind) _kind = arg;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(documentCaptureControllerProvider.notifier).setKind(_kind);
      }
    });
  }

  String get _title {
    switch (_kind) {
      case DocumentKind.driversLicence:
        return "Driver's licence";
      case DocumentKind.vehicleReg:
        return 'Vehicle registration';
      case DocumentKind.insurance:
        return 'Proof of insurance';
      case DocumentKind.roadWorthiness:
        return 'Road worthiness';
      case DocumentKind.lasrra:
        return 'LASRRA';
      case DocumentKind.inspectionReport:
        return 'Inspection report';
      case DocumentKind.profileSelfie:
        return 'Selfie';
    }
  }

  @override
  Widget build(BuildContext context) {
    final DocumentCaptureState state =
        ref.watch(documentCaptureControllerProvider);
    final DocumentCaptureController c =
        ref.read(documentCaptureControllerProvider.notifier);

    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BackButtonBox(onTap: () => AppNavigation.pop()),
            const SizedBox(height: 18),
            Text(
              'Upload your\n$_title.',
              style: AppTextStyles.h1.copyWith(color: context.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Make sure all four corners are visible and the text is sharp.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 26),
            _UploadTile(state: state, controller: c),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: AppTextStyles.bodySm.copyWith(color: context.red),
              ),
            ],
            const SizedBox(height: 22),
            DrivioButton(
              label: state.isRegistering
                  ? 'Saving…'
                  : 'Submit for review',
              disabled: !state.hasUpload || state.isRegistering,
              onPressed: () async {
                final bool ok = await c.registerDocument();
                if (!mounted || !ok) return;
                await ref.read(kycControllerProvider.notifier).refresh();
                if (!mounted) return;
                AppNavigation.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.state, required this.controller});

  final DocumentCaptureState state;
  final DocumentCaptureController controller;

  @override
  Widget build(BuildContext context) {
    final bool busy = state.isUploading;
    final bool uploaded = state.hasUpload;
    return InkWell(
      onTap: busy ? null : () => _openSourceSheet(context, controller),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: uploaded ? context.accent : context.borderStrong,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (uploaded ? context.accent : context.textDim)
                    .withValues(alpha: 0.14),
                borderRadius: AppRadius.sm,
              ),
              alignment: Alignment.center,
              child: Icon(
                uploaded
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                size: 18,
                color: uploaded ? context.accent : context.textDim,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    busy
                        ? 'Uploading…'
                        : uploaded
                            ? (state.uploadedFileName ?? 'Uploaded')
                            : 'Tap to upload · PDF or photo',
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.text,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    uploaded
                        ? 'Looking good. Submit when ready.'
                        : 'Camera, gallery, or file picker.',
                    style: AppTextStyles.captionSm.copyWith(
                      fontSize: 11,
                      color: uploaded ? context.accent : context.textDim,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.accent,
                ),
              )
            else if (uploaded)
              GestureDetector(
                onTap: controller.clearUpload,
                child: Icon(DrivioIcons.close,
                    size: 18, color: context.textDim),
              )
            else
              Icon(DrivioIcons.plus, size: 18, color: context.textDim),
          ],
        ),
      ),
    );
  }

  Future<void> _openSourceSheet(
      BuildContext context, DocumentCaptureController c) async {
    final DocPickerSource? choice = await showModalBottomSheet<DocPickerSource>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: ctx.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  'Add document',
                  style: AppTextStyles.bodyLg.copyWith(
                    color: ctx.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _Option(
                  icon: DrivioIcons.camera,
                  label: 'Take a photo',
                  onTap: () =>
                      Navigator.of(ctx).pop(DocPickerSource.camera),
                ),
                _Option(
                  icon: DrivioIcons.image,
                  label: 'Choose from gallery',
                  onTap: () =>
                      Navigator.of(ctx).pop(DocPickerSource.gallery),
                ),
                _Option(
                  icon: DrivioIcons.document,
                  label: 'Choose a PDF',
                  onTap: () => Navigator.of(ctx).pop(DocPickerSource.file),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (choice != null) {
      await c.pickAndUpload(choice);
    }
  }
}

class _Option extends StatelessWidget {
  const _Option(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 22, color: context.text),
            const SizedBox(width: 14),
            Text(label,
                style: AppTextStyles.body.copyWith(color: context.text)),
          ],
        ),
      ),
    );
  }
}
