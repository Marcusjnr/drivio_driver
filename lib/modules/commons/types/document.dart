enum DocumentKind {
  driversLicence('drivers_licence'),
  vehicleReg('vehicle_reg'),
  insurance('insurance'),
  roadWorthiness('road_worthiness'),
  lasrra('lasrra'),
  inspectionReport('inspection_report'),
  profileSelfie('profile_selfie'),
  // Vehicle photos captured during onboarding. Stored as documents (against
  // the vehicle id) but deliberately NOT part of the required-doc KYC gate.
  vehiclePhotoFront('vehicle_photo_front'),
  vehiclePhotoBack('vehicle_photo_back'),
  vehiclePhotoSide('vehicle_photo_side'),
  vehiclePhotoInterior('vehicle_photo_interior');

  const DocumentKind(this.wire);
  final String wire;

  static DocumentKind fromWire(String value) {
    return DocumentKind.values.firstWhere(
      (DocumentKind k) => k.wire == value,
      orElse: () => DocumentKind.vehicleReg,
    );
  }
}

enum DocumentStatus { pending, approved, rejected, expired }

class Document {
  const Document({
    required this.id,
    required this.ownerUserId,
    required this.kind,
    required this.filePath,
    required this.status,
    required this.createdAt,
    this.vehicleId,
    this.expiresOn,
    this.rejectionReason,
    this.blurHash,
  });

  final String id;
  final String ownerUserId;
  final DocumentKind kind;
  final String? vehicleId;
  final String filePath;
  final DateTime? expiresOn;
  final DocumentStatus status;
  final String? rejectionReason;
  final DateTime createdAt;

  /// ~30-char BlurHash of the image, rendered as an instant blurred
  /// placeholder while the real file streams in. Null for PDFs and for
  /// uploads that predate the compress-upload middleware.
  final String? blurHash;

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      kind: DocumentKind.fromWire(json['kind'] as String),
      vehicleId: json['vehicle_id'] as String?,
      filePath: json['file_path'] as String,
      expiresOn: json['expires_on'] == null
          ? null
          : DateTime.parse(json['expires_on'] as String),
      status: DocumentStatus.values.firstWhere(
        (DocumentStatus s) => s.name == json['status'],
        orElse: () => DocumentStatus.pending,
      ),
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      blurHash: json['blur_hash'] as String?,
    );
  }
}

/// Vehicle-related document kinds actually collected today — the ones
/// that can be individually rejected and need a targeted re-upload.
/// Insurance, road worthiness, LASRRA and inspection report are enum
/// values that exist but are not collected by any current UI.
const List<DocumentKind> vehicleDocumentKinds = <DocumentKind>[
  DocumentKind.vehicleReg,
  DocumentKind.vehiclePhotoFront,
  DocumentKind.vehiclePhotoBack,
  DocumentKind.vehiclePhotoSide,
  DocumentKind.vehiclePhotoInterior,
];

/// True if any vehicle-related document's latest status is rejected,
/// given a "latest document per kind" map (as `ProfileHubState.
/// documentsByKind` already builds).
bool hasRejectedVehicleDocument(Map<DocumentKind, Document> byKind) {
  return vehicleDocumentKinds.any(
    (DocumentKind k) => byKind[k]?.status == DocumentStatus.rejected,
  );
}
