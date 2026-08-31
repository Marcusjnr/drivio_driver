import 'dart:typed_data';

import 'package:drivio_driver/modules/commons/types/document.dart';

abstract class DocumentRepository {
  /// Uploads bytes to private storage at the canonical path
  /// `<userId>/<kind>/<uuid>.<ext>` and returns the storage path.
  Future<String> uploadFile({
    required DocumentKind kind,
    required Uint8List bytes,
    required String fileExtension,
    required String contentType,
  });

  /// Inserts a `documents` row pointing at an already-uploaded file.
  /// Short-lived signed URL for one of the caller's own files in the
  /// private KYC bucket, for in-app viewing. Null when the URL cannot
  /// be minted (offline, deleted object).
  Future<String?> signedUrl(String filePath);

  Future<Document> registerDocument({
    required DocumentKind kind,
    required String filePath,
    String? vehicleId,
  });
}
