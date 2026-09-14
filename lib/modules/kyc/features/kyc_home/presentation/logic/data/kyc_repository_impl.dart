import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/config/config.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

/// TEMPORARY (2026-08-30): forces staging/debug builds to verify against
/// YouVerify's LIVE environment so ops can confirm the prod token works
/// end to end. Live checks bill per lookup and enforce the NIMC name
/// match, so the tester's profile name must match their real NIN.
/// REVERT to false once live verification is confirmed.
const bool _forceProdVerification = true;

/// Masks an identity number for logs: first 3 and last 2 characters
/// stay readable, the middle is starred. Enough to correlate a test run
/// without writing full PII into the console.
String _maskId(String v) {
  if (v.length <= 5) return '*' * v.length;
  return '${v.substring(0, 3)}${'*' * (v.length - 5)}${v.substring(v.length - 2)}';
}

class SupabaseKycRepository implements KycRepository {
  SupabaseKycRepository(this._supabase);

  final SupabaseModule _supabase;

  /// Short-lived snapshot cache. The profile hub and the KYC checklist
  /// each load the snapshot independently, and the hub reloads on every
  /// open and on every return from a pushed flow — most of those loads
  /// see identical data seconds apart. Serving repeats from memory for
  /// [_snapshotTtl] cuts three queries per repeat without any UX change;
  /// mutations (uploads, NIN verify, vehicle submit) call
  /// [invalidateSnapshot] so the next load is always fresh.
  static const Duration _snapshotTtl = Duration(seconds: 45);
  static KycSnapshot? _cachedSnapshot;
  static DateTime? _cachedAt;
  static String? _cachedForUser;

  static void invalidateSnapshot() {
    _cachedSnapshot = null;
    _cachedAt = null;
    _cachedForUser = null;
  }

  @override
  Future<KycSnapshot> loadSnapshot() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const _KycAuthException();
    }

    final KycSnapshot? cached = _cachedSnapshot;
    if (cached != null &&
        _cachedForUser == user.id &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _snapshotTtl) {
      return cached;
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

    final KycSnapshot snapshot = KycSnapshot(
      kycStatus: (driver['kyc_status'] as String?) ?? 'not_started',
      bvnVerifiedAt: parse(driver['bvn_verified_at']),
      ninVerifiedAt: parse(driver['nin_verified_at']),
      livenessPassedAt: parse(driver['liveness_passed_at']),
      driversLicenceVerifiedAt: parse(driver['drivers_licence_verified_at']),
      documents: docs.map(Document.fromJson).toList(growable: false),
      vehicleId: vehicles.isEmpty ? null : vehicles.first['id'] as String,
    );
    _cachedSnapshot = snapshot;
    _cachedAt = DateTime.now();
    _cachedForUser = user.id;
    return snapshot;
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
    final bool prod =
        _forceProdVerification || (kReleaseMode && !locator<Config>().isStaging);
    final String cleanNin = nin.replaceAll(RegExp(r'\D'), '');
    AppLogger.i('youverify-verify-nin → request', data: <String, dynamic>{
      'nin': _maskId(cleanNin),
      'env': prod ? 'prod' : 'staging',
    });
    try {
      final FunctionResponse res = await _supabase.functions.invoke(
        'youverify-verify-nin',
        body: <String, dynamic>{
          'nin': cleanNin,
          'env': prod ? 'prod' : 'staging',
        },
      );
      final Object? data = res.data;
      AppLogger.i('youverify-verify-nin ← response', data: <String, dynamic>{
        'status': res.status,
        'body': data.toString(),
      });
      if (data is! Map) return NinVerifyResult.error;
      if (data['ok'] == true) {
        // The verified stamp changes the checklist: drop the cached
        // snapshot so the next load reflects it.
        invalidateSnapshot();
        return NinVerifyResult.verified;
      }
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
    final bool prod =
        _forceProdVerification || (kReleaseMode && !locator<Config>().isStaging);
    final String cleanLicence =
        licenceNo.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    AppLogger.i(
      'youverify-verify-drivers-license → request',
      data: <String, dynamic>{
        'licence': _maskId(cleanLicence),
        'env': prod ? 'prod' : 'staging',
      },
    );
    try {
      final FunctionResponse res = await _supabase.functions.invoke(
        'youverify-verify-drivers-license',
        body: <String, dynamic>{
          'licence': cleanLicence,
          'env': prod ? 'prod' : 'staging',
        },
      );
      final Object? data = res.data;
      AppLogger.i(
        'youverify-verify-drivers-license ← response',
        data: <String, dynamic>{
          'status': res.status,
          'body': data.toString(),
        },
      );
      if (data is! Map) return NinVerifyResult.error;
      if (data['ok'] == true) {
        // The verified stamp changes the checklist: drop the cached
        // snapshot so the next load reflects it.
        invalidateSnapshot();
        return NinVerifyResult.verified;
      }
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
