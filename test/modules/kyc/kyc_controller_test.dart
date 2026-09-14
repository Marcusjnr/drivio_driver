import 'package:flutter_test/flutter_test.dart';

import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

class _FakeKycRepository implements KycRepository {
  _FakeKycRepository(this.snapshot);
  final KycSnapshot snapshot;

  @override
  Future<KycSnapshot> loadSnapshot() async => snapshot;

  @override
  Future<void> markStepCompleted(String step) async {}

  @override
  Future<String?> submitForReview() async => null;

  @override
  Future<NinVerifyResult> verifyNin(String nin) async => NinVerifyResult.error;

  @override
  Future<NinVerifyResult> verifyDriversLicence(String licenceNo) async =>
      NinVerifyResult.error;
}

Document _doc({
  required DocumentKind kind,
  required DocumentStatus status,
  String? rejectionReason,
  DateTime? createdAt,
}) {
  return Document(
    id: 'doc-${kind.wire}-${(createdAt ?? DateTime(2026, 1, 1)).millisecondsSinceEpoch}',
    ownerUserId: 'driver-1',
    kind: kind,
    filePath: 'driver-1/${kind.wire}/file.jpg',
    status: status,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    rejectionReason: rejectionReason,
  );
}

void main() {
  group('KycController.refresh — rejectedItems', () {
    test('reports no rejected items when everything is pending/approved',
        () async {
      final KycSnapshot snap = KycSnapshot(
        kycStatus: 'pending_review',
        bvnVerifiedAt: null,
        ninVerifiedAt: DateTime(2026, 1, 1),
        livenessPassedAt: DateTime(2026, 1, 1),
        driversLicenceVerifiedAt: null,
        vehicleId: 'vehicle-1',
        documents: <Document>[
          _doc(kind: DocumentKind.driversLicence, status: DocumentStatus.pending),
          _doc(kind: DocumentKind.vehicleReg, status: DocumentStatus.approved),
        ],
      );
      final KycController c = KycController(_FakeKycRepository(snap));
      await c.refresh();

      expect(c.state.rejectedItems, isEmpty);
      expect(c.state.hasRejectedItems, isFalse);
    });

    test('surfaces a rejected vehicle photo with its reason and vehicle id',
        () async {
      final KycSnapshot snap = KycSnapshot(
        kycStatus: 'pending_review',
        bvnVerifiedAt: null,
        ninVerifiedAt: DateTime(2026, 1, 1),
        livenessPassedAt: DateTime(2026, 1, 1),
        driversLicenceVerifiedAt: null,
        vehicleId: 'vehicle-1',
        documents: <Document>[
          _doc(kind: DocumentKind.vehicleReg, status: DocumentStatus.approved),
          _doc(
            kind: DocumentKind.vehiclePhotoFront,
            status: DocumentStatus.rejected,
            rejectionReason: 'Photo is blurry',
          ),
        ],
      );
      final KycController c = KycController(_FakeKycRepository(snap));
      await c.refresh();

      expect(c.state.hasRejectedItems, isTrue);
      expect(c.state.rejectedItems, hasLength(1));
      final RejectedDocumentItem item = c.state.rejectedItems.single;
      expect(item.kind, DocumentKind.vehiclePhotoFront);
      expect(item.reason, 'Photo is blurry');
      expect(item.vehicleId, 'vehicle-1');
      expect(item.label, 'Vehicle photo (front)');
    });

    test(
        'only the LATEST document per kind counts — a superseded '
        'rejection does not block a later approval', () async {
      final KycSnapshot snap = KycSnapshot(
        kycStatus: 'pending_review',
        bvnVerifiedAt: null,
        ninVerifiedAt: DateTime(2026, 1, 1),
        livenessPassedAt: DateTime(2026, 1, 1),
        driversLicenceVerifiedAt: null,
        vehicleId: 'vehicle-1',
        documents: <Document>[
          // Newest first, matching kyc_repository_impl.dart's real query
          // order (`order('created_at', ascending: false)`).
          _doc(
            kind: DocumentKind.driversLicence,
            status: DocumentStatus.pending,
            createdAt: DateTime(2026, 2, 1),
          ),
          _doc(
            kind: DocumentKind.driversLicence,
            status: DocumentStatus.rejected,
            rejectionReason: 'Old, superseded rejection',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      final KycController c = KycController(_FakeKycRepository(snap));
      await c.refresh();

      expect(c.state.rejectedItems, isEmpty);
    });

    test('licence/selfie rejections carry no vehicle id', () async {
      final KycSnapshot snap = KycSnapshot(
        kycStatus: 'pending_review',
        bvnVerifiedAt: null,
        ninVerifiedAt: DateTime(2026, 1, 1),
        livenessPassedAt: null,
        driversLicenceVerifiedAt: null,
        vehicleId: 'vehicle-1',
        documents: <Document>[
          _doc(
            kind: DocumentKind.driversLicence,
            status: DocumentStatus.rejected,
            rejectionReason: 'Expired',
          ),
        ],
      );
      final KycController c = KycController(_FakeKycRepository(snap));
      await c.refresh();

      expect(c.state.rejectedItems.single.vehicleId, isNull);
    });

    test('a missing rejection reason falls back to a generic message',
        () async {
      final KycSnapshot snap = KycSnapshot(
        kycStatus: 'pending_review',
        bvnVerifiedAt: null,
        ninVerifiedAt: null,
        livenessPassedAt: null,
        driversLicenceVerifiedAt: null,
        vehicleId: null,
        documents: <Document>[
          _doc(
            kind: DocumentKind.profileSelfie,
            status: DocumentStatus.rejected,
          ),
        ],
      );
      final KycController c = KycController(_FakeKycRepository(snap));
      await c.refresh();

      expect(
        c.state.rejectedItems.single.reason,
        "This didn't pass review. Please upload a new copy.",
      );
    });
  });
}
