import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/commons/data/document_repository.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository_impl.dart';

const String _bucket = 'kyc-private';

class SupabaseDocumentRepository implements DocumentRepository {
  SupabaseDocumentRepository(this._supabase);

  final SupabaseModule _supabase;
  final Uuid _uuid = const Uuid();

  @override
  Future<String> uploadFile({
    required DocumentKind kind,
    required Uint8List bytes,
    required String fileExtension,
    required String contentType,
  }) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const DocumentAuthException();
    }

    final String safeExt =
        fileExtension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final String objectPath =
        '${user.id}/${kind.wire}/${_uuid.v4()}.$safeExt';

    await _supabase.storage.from(_bucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    return objectPath;
  }

  /// Signed URLs are reused for most of their lifetime instead of being
  /// minted per view. A fresh URL per view carries a fresh token, which
  /// makes every image cache (Flutter's and the CDN's) treat the same
  /// photo as a brand-new resource — so each open re-downloaded the full
  /// file and inflated egress. One URL per day per document lets caches
  /// actually hold the bytes. RLS still means only the owner can mint.
  static const int _signedUrlTtlSeconds = 24 * 60 * 60;
  static final Map<String, ({String url, DateTime expiresAt})> _urlCache =
      <String, ({String url, DateTime expiresAt})>{};

  @override
  Future<String?> signedUrl(String filePath) async {
    final ({String url, DateTime expiresAt})? hit = _urlCache[filePath];
    // Re-mint once under an hour of life remains, so a URL handed to
    // the viewer is always comfortably valid while on screen.
    if (hit != null &&
        hit.expiresAt.difference(DateTime.now()).inMinutes > 60) {
      return hit.url;
    }
    try {
      final String url = await _supabase.storage
          .from(_bucket)
          .createSignedUrl(filePath, _signedUrlTtlSeconds);
      _urlCache[filePath] = (
        url: url,
        expiresAt: DateTime.now().add(
          const Duration(seconds: _signedUrlTtlSeconds),
        ),
      );
      return url;
    } catch (_) {
      // Minting failed: fall back to a still-valid cached URL if any.
      if (hit != null && hit.expiresAt.isAfter(DateTime.now())) {
        return hit.url;
      }
      return null;
    }
  }

  @override
  Future<Document> registerDocument({
    required DocumentKind kind,
    required String filePath,
    String? vehicleId,
  }) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const DocumentAuthException();
    }

    final Map<String, dynamic> row = await _supabase
        .db('documents')
        .insert(<String, dynamic>{
          'owner_user_id': user.id,
          'kind': kind.wire,
          'vehicle_id': vehicleId,
          'file_path': filePath,
        })
        .select()
        .single();

    // A new document changes the KYC checklist and the profile hub:
    // drop the cached snapshot so their next load is fresh.
    SupabaseKycRepository.invalidateSnapshot();
    return Document.fromJson(row);
  }
}

class DocumentAuthException implements Exception {
  const DocumentAuthException();
  @override
  String toString() => 'DocumentAuthException: no signed-in user';
}
