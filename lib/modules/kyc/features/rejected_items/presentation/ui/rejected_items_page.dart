import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/document_capture/presentation/ui/document_capture_page.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';

/// The guided "what needs fixing" screen. Reached from the home banner,
/// a rejection push notification, the KYC checklist, or the profile
/// hub's vehicle row — always the same list, always the same behaviour:
/// one row per currently-rejected document, tap to fix just that one.
///
/// The list is captured ONCE when the screen loads (a fresh
/// `KycController.refresh()`, then whatever `rejectedItems` comes back)
/// and never reflows afterwards. Fixing an item flips its row to a
/// non-tappable "Uploaded" state instead of removing it, so progress
/// reads clearly against a stable list even though a fresh server fetch
/// would technically already show fewer rejected items.
class RejectedItemsPage extends ConsumerStatefulWidget {
  const RejectedItemsPage({super.key});

  @override
  ConsumerState<RejectedItemsPage> createState() => _RejectedItemsPageState();
}

class _RejectedItemsPageState extends ConsumerState<RejectedItemsPage> {
  List<RejectedDocumentItem>? _items;
  final Set<DocumentKind> _completed = <DocumentKind>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await ref.read(kycControllerProvider.notifier).refresh();
    if (!mounted) return;
    setState(() {
      _items = ref.read(kycControllerProvider).rejectedItems;
    });
  }

  Future<void> _fix(RejectedDocumentItem item) async {
    // Selfie has its own dedicated recapture flow (face liveness +
    // profile photo + the server-side liveness stamp) — it doesn't
    // return a bool like DocumentCapturePage does, so completion is
    // detected by re-checking rejectedItems after a fresh refresh
    // instead of trusting a pushed result.
    if (item.kind == DocumentKind.profileSelfie) {
      await AppNavigation.push<void>(
        AppRoutes.kycSelfie,
        arguments: item.reason,
      );
      if (!mounted) return;
      await ref.read(kycControllerProvider.notifier).refresh();
      if (!mounted) return;
      final bool stillRejected = ref
          .read(kycControllerProvider)
          .rejectedItems
          .any((RejectedDocumentItem i) => i.kind == DocumentKind.profileSelfie);
      if (!stillRejected) {
        setState(() => _completed.add(item.kind));
      }
      return;
    }

    final bool? done = await AppNavigation.push<bool>(
      AppRoutes.kycDocumentCapture,
      arguments: DocumentCaptureArgs(
        kind: item.kind,
        vehicleId: item.vehicleId,
        rejectionReason: item.reason,
      ),
    );
    if (done == true && mounted) {
      setState(() => _completed.add(item.kind));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<RejectedDocumentItem>? items = _items;
    if (items == null) {
      return ScreenScaffold(
        child: Center(
          child: CircularProgressIndicator(color: context.accent),
        ),
      );
    }

    final bool allDone = items.isNotEmpty &&
        items.every((RejectedDocumentItem i) => _completed.contains(i.kind));

    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BackButtonBox(onTap: () => AppNavigation.pop()),
            const SizedBox(height: 18),
            Text(
              'What needs\nfixing.',
              style: AppTextStyles.h1.copyWith(color: context.text),
            ),
            const SizedBox(height: 6),
            Text(
              allDone
                  ? "You're all set — we'll review this shortly."
                  : items.isEmpty
                      ? 'Nothing needs fixing right now.'
                      : 'A few things need another look. Fix each one below.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 22),
            for (final RejectedDocumentItem item in items) ...<Widget>[
              _RejectedItemRow(
                item: item,
                done: _completed.contains(item.kind),
                onTap: () => _fix(item),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _RejectedItemRow extends StatelessWidget {
  const _RejectedItemRow({
    required this.item,
    required this.done,
    required this.onTap,
  });

  final RejectedDocumentItem item;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tone = done ? context.accent : context.red;
    return Opacity(
      opacity: done ? 0.6 : 1,
      child: InkWell(
        onTap: done ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: tone),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Icon(
                  done ? DrivioIcons.check : DrivioIcons.close,
                  size: 16,
                  color: tone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.label,
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done ? 'Uploaded — pending review' : item.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.captionSm.copyWith(
                        fontSize: 11,
                        color: tone,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                done ? 'Uploaded' : 'Fix',
                style: AppTextStyles.captionSm.copyWith(
                  fontSize: 11,
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
