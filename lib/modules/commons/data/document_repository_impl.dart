import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/commons/data/document_repository.dart';

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

    return Document.fromJson(row);
  }
}

class DocumentAuthException implements Exception {
  const DocumentAuthException();
  @override
  String toString() => 'DocumentAuthException: no signed-in user';
}
