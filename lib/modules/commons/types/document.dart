enum DocumentKind {
  driversLicence('drivers_licence'),
  vehicleReg('vehicle_reg'),
  insurance('insurance'),
  roadWorthiness('road_worthiness'),
  lasrra('lasrra'),
  inspectionReport('inspection_report'),
  profileSelfie('profile_selfie');

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
    );
  }
}
