import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/config/config.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
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
        .select('kyc_status, bvn_verified_at, nin_verified_at, '
            'liveness_passed_at, drivers_licence_verified_at')
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
      driversLicenceVerifiedAt: parse(driver['drivers_licence_verified_at']),
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

  @override
  Future<NinVerifyResult> verifyNin(String nin) async {
    // Real YouVerify + name match happens only on prod release builds;
    // debug/profile and staging hit YouVerify's sandbox (fixed fake
    // data, no name match) so onboarding can be exercised without
    // spending real checks or failing on test identities.
    final bool prod = kReleaseMode && !locator<Config>().isStaging;
    try {
      final FunctionResponse res = await _supabase.functions.invoke(
        'youverify-verify-nin',
        body: <String, dynamic>{
          'nin': nin.replaceAll(RegExp(r'\D'), ''),
          'env': prod ? 'prod' : 'staging',
        },
      );
      final Object? data = res.data;
      if (data is! Map) return NinVerifyResult.error;
      if (data['ok'] == true) return NinVerifyResult.verified;
      switch (data['reason']) {
        case 'mismatch':
          return NinVerifyResult.mismatch;
        case 'not_found':
        case 'bad_nin':
          return NinVerifyResult.notFound;
        default:
          return NinVerifyResult.error;
      }
    } catch (e, st) {
      AppLogger.w('verifyNin failed', error: e, stackTrace: st);
      return NinVerifyResult.error;
    }
  }

  @override
  Future<NinVerifyResult> verifyDriversLicence(String licenceNo) async {
    // As with NIN, real YouVerify + name match runs only on prod release
    // builds; debug/profile and staging hit YouVerify's sandbox.
    final bool prod = kReleaseMode && !locator<Config>().isStaging;
    try {
      final FunctionResponse res = await _supabase.functions.invoke(
        'youverify-verify-drivers-license',
        body: <String, dynamic>{
          'licence': licenceNo.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''),
          'env': prod ? 'prod' : 'staging',
        },
      );
      final Object? data = res.data;
      if (data is! Map) return NinVerifyResult.error;
      if (data['ok'] == true) return NinVerifyResult.verified;
      switch (data['reason']) {
        case 'mismatch':
          return NinVerifyResult.mismatch;
        case 'not_found':
        case 'bad_licence':
          return NinVerifyResult.notFound;
        default:
          return NinVerifyResult.error;
      }
    } catch (e, st) {
      AppLogger.w('verifyDriversLicence failed', error: e, stackTrace: st);
      return NinVerifyResult.error;
    }
  }
}

class _KycAuthException implements Exception {
  const _KycAuthException();
}
