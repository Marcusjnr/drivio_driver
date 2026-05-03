import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

class SupabaseKycRepository implements KycRepository {
  SupabaseKycRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<KycSnapshot> loadSnapshot() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const _KycAuthException();
    }

    final Map<String, dynamic> driver = await _supabase
        .db('drivers')
        .select('kyc_status, bvn_verified_at, nin_verified_at, liveness_passed_at')
        .eq('user_id', user.id)
        .maybeSingle() as Map<String, dynamic>;

    final List<Map<String, dynamic>> docs = await _supabase
        .db('documents')
        .select()
        .eq('owner_user_id', user.id)
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> vehicles = await _supabase
        .db('vehicles')
        .select('id')
        .eq('driver_id', user.id)
        .filter('deleted_at', 'is', null)
        .limit(1);

    DateTime? parse(Object? v) =>
        v == null ? null : DateTime.parse(v as String);

    return KycSnapshot(
      kycStatus: (driver['kyc_status'] as String?) ?? 'not_started',
      bvnVerifiedAt: parse(driver['bvn_verified_at']),
      ninVerifiedAt: parse(driver['nin_verified_at']),
      livenessPassedAt: parse(driver['liveness_passed_at']),
      documents: docs.map(Document.fromJson).toList(growable: false),
      hasVehicle: vehicles.isNotEmpty,
    );
  }

  @override
  Future<void> markStepCompleted(String step) async {
    await _supabase.client.rpc<void>(
      'mark_kyc_step_completed',
      params: <String, dynamic>{'p_step': step},
    );
  }

  @override
  Future<String?> submitForReview() async {
    final dynamic res = await _supabase.client.rpc<dynamic>(
      'submit_kyc_for_review',
    );
    return res as String?;
  }
}

class _KycAuthException implements Exception {
  const _KycAuthException();
}
