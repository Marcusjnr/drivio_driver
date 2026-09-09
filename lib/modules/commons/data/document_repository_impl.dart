import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/config/config.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/commons/data/document_repository.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository_impl.dart';

const String _bucket = 'kyc-private';

class SupabaseDocumentRepository implements DocumentRepository {
  SupabaseDocumentRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<String> uploadFile({
    required DocumentKind kind,
    required Uint8List bytes,
    required String fileExtension,
    required String contentType,
  }) async {
    final User? user = _supabase.auth.currentUser;
    final String? token = _supabase.auth.currentSession?.accessToken;
    if (user == null || token == null) {
      throw const DocumentAuthException();
    }

    // Through the compress-upload middleware instead of straight to
    // Storage: the server auto-orients, resizes (max 1600px edge),
    // strips EXIF (GPS!) and re-encodes photos before storing — a
    // multi-megabyte camera shot lands as a few hundred KB with no
    // visible quality loss. PDFs pass through untouched, and if the
    // server cannot process a file it stores the original, so uploads
    // never fail because of compression.
    final http.Response res = await http.post(
      Uri.parse(
        '${locator<Config>().supabaseUrl}/functions/v1/compress-upload',
      ),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'apikey': locator<Config>().supabaseAnonKey,
        'content-type': contentType,
        'x-doc-kind': kind.wire,
      },
      body: bytes,
    );
    if (res.statusCode != 200) {
      throw DocumentUploadException(
        'compress-upload failed (${res.statusCode})',
      );
    }
    final Map<String, dynamic> json =
        jsonDecode(res.body) as Map<String, dynamic>;
    final String? path = json['path'] as String?;
    if (path == null || path.isEmpty) {
      throw const DocumentUploadException('compress-upload returned no path');
    }
    return path;
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

class DocumentUploadException implements Exception {
  const DocumentUploadException(this.message);
  final String message;
  @override
  String toString() => 'DocumentUploadException: $message';
}

class DocumentAuthException implements Exception {
  const DocumentAuthException();
  @override
  String toString() => 'DocumentAuthException: no signed-in user';
}
