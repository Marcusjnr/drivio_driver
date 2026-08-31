import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/document_repository.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';

/// Route arguments for [DocumentViewPage]: which document to show and the
/// human label for its kind.
class DocumentViewArgs {
  const DocumentViewArgs({required this.label, required this.document});

  final String label;
  final Document document;
}

/// Full-page view of one uploaded document: the picture itself (via a
/// short-lived signed URL into the private KYC bucket) with its review
/// status. Tapping a document row on the profile lands here once a file
/// exists, so "In review" or "Approved" is shown ON the document rather
/// than as a bare status line.
class DocumentViewPage extends ConsumerStatefulWidget {
  const DocumentViewPage({super.key});

  @override
  ConsumerState<DocumentViewPage> createState() => _DocumentViewPageState();
}

class _DocumentViewPageState extends ConsumerState<DocumentViewPage> {
  Future<String?>? _url;
  DocumentViewArgs? _args;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args != null) return;
    final Object? raw = ModalRoute.of(context)?.settings.arguments;
    if (raw is DocumentViewArgs) {
      _args = raw;
      _url = locator<DocumentRepository>().signedUrl(raw.document.filePath);
      setState(() {});
    }
  }

  bool get _isPdf =>
      (_args?.document.filePath ?? '').toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final DocumentViewArgs? args = _args;
    if (args == null) {
      return const ScreenScaffold(child: SizedBox.shrink());
    }
    final Document doc = args.document;
    final (String statusLabel, Color tone) = _statusOf(context, doc);

    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              args.label,
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 10),

            // Status pill + optional rejection reason, above the file so
            // the verdict reads first.
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: tone.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusLabel.toUpperCase(),
                    style: AppTextStyles.micro.copyWith(
                      color: tone,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            if (doc.status == DocumentStatus.rejected &&
                (doc.rejectionReason ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                doc.rejectionReason!,
                style: AppTextStyles.bodySm.copyWith(
                  color: context.red,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 18),

            // The document itself.
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 220),
                decoration: BoxDecoration(
                  color: context.surface,
                  border: Border.all(color: context.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _isPdf ? _pdfCard(context) : _imageView(context),
              ),
            ),
            const SizedBox(height: 22),

            // Replacing an approved document would silently un-verify the
            // driver, so the re-upload path only shows before approval.
            if (doc.status != DocumentStatus.approved)
              DrivioButton(
                label: 'Upload a new copy',
                variant: DrivioButtonVariant.ghost,
                onPressed: () async {
                  await AppNavigation.push<void>(
                    AppRoutes.kycDocumentCapture,
                    arguments: doc.kind,
                  );
                  if (mounted) AppNavigation.pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _imageView(BuildContext context) {
    return FutureBuilder<String?>(
      future: _url,
      builder: (BuildContext context, AsyncSnapshot<String?> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final String? url = snap.data;
        if (url == null) {
          return SizedBox(
            height: 220,
            child: Center(
              child: Text(
                "Couldn't load the file. Check your connection.",
                style: AppTextStyles.bodySm.copyWith(color: context.textDim),
              ),
            ),
          );
        }
        return Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (_, Widget child, ImageChunkEvent? p) => p == null
              ? child
              : const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                ),
          errorBuilder: (_, _, _) => SizedBox(
            height: 220,
            child: Center(
              child: Text(
                "Couldn't display this file.",
                style: AppTextStyles.bodySm.copyWith(color: context.textDim),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pdfCard(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(DrivioIcons.document, size: 44, color: context.textDim),
          const SizedBox(height: 10),
          Text(
            'PDF document',
            style: AppTextStyles.bodySm.copyWith(color: context.textDim),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusOf(BuildContext context, Document doc) {
    switch (doc.status) {
      case DocumentStatus.approved:
        return ('Approved', context.accent);
      case DocumentStatus.pending:
        return ('In review', context.amber);
      case DocumentStatus.rejected:
        return ('Rejected', context.red);
      case DocumentStatus.expired:
        return ('Expired', context.amber);
    }
  }
}
