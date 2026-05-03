import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/document_repository.dart';
import 'package:drivio_driver/modules/commons/data/document_repository_impl.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';

const int _maxFileBytes = 5 * 1024 * 1024;

enum DocPickerSource { camera, gallery, file }

class DocumentCaptureState {
  const DocumentCaptureState({
    this.kind,
    this.isUploading = false,
    this.isRegistering = false,
    this.uploadedFilePath,
    this.uploadedFileName,
    this.error,
  });

  final DocumentKind? kind;
  final bool isUploading;
  final bool isRegistering;
  final String? uploadedFilePath;
  final String? uploadedFileName;
  final String? error;

  bool get hasUpload => uploadedFilePath != null;

  DocumentCaptureState copyWith({
    DocumentKind? kind,
    bool? isUploading,
    bool? isRegistering,
    String? uploadedFilePath,
    String? uploadedFileName,
    String? error,
    bool clearError = false,
    bool clearUpload = false,
  }) {
    return DocumentCaptureState(
      kind: kind ?? this.kind,
      isUploading: isUploading ?? this.isUploading,
      isRegistering: isRegistering ?? this.isRegistering,
      uploadedFilePath:
          clearUpload ? null : (uploadedFilePath ?? this.uploadedFilePath),
      uploadedFileName:
          clearUpload ? null : (uploadedFileName ?? this.uploadedFileName),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DocumentCaptureController extends StateNotifier<DocumentCaptureState> {
  DocumentCaptureController(this._docs) : super(const DocumentCaptureState());

  final DocumentRepository _docs;
  final ImagePicker _imagePicker = ImagePicker();

  void setKind(DocumentKind k) =>
      state = state.copyWith(kind: k, clearError: true);

  Future<void> pickAndUpload(DocPickerSource source) async {
    final DocumentKind? kind = state.kind;
    if (kind == null) return;

    state = state.copyWith(isUploading: true, clearError: true);

    try {
      final _Picked? picked = await _pick(source);
      if (picked == null) {
        state = state.copyWith(isUploading: false);
        return;
      }
      if (picked.bytes.length > _maxFileBytes) {
        state = state.copyWith(
          isUploading: false,
          error: 'File is over 5 MB. Pick a smaller one.',
        );
        return;
      }

      final String filePath = await _docs.uploadFile(
        kind: kind,
        bytes: picked.bytes,
        fileExtension: picked.extension,
        contentType: picked.contentType,
      );

      state = state.copyWith(
        isUploading: false,
        uploadedFilePath: filePath,
        uploadedFileName: picked.fileName,
      );
    } on DocumentAuthException {
      state = state.copyWith(
        isUploading: false,
        error: 'Session expired. Please sign in again.',
      );
    } on StorageException catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: 'Upload failed: ${e.message}',
      );
    } catch (_) {
      state = state.copyWith(
        isUploading: false,
        error: 'Upload failed. Please try again.',
      );
    }
  }

  void clearUpload() {
    state = state.copyWith(clearUpload: true, clearError: true);
  }

  Future<bool> registerDocument() async {
    final DocumentKind? kind = state.kind;
    final String? filePath = state.uploadedFilePath;
    if (kind == null || filePath == null) return false;

    state = state.copyWith(isRegistering: true, clearError: true);
    try {
      await _docs.registerDocument(kind: kind, filePath: filePath);
      state = state.copyWith(isRegistering: false);
      return true;
    } catch (_) {
      state = state.copyWith(
        isRegistering: false,
        error: 'Could not save document. Please try again.',
      );
      return false;
    }
  }

  Future<_Picked?> _pick(DocPickerSource source) async {
    switch (source) {
      case DocPickerSource.camera:
      case DocPickerSource.gallery:
        final XFile? x = await _imagePicker.pickImage(
          source: source == DocPickerSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2400,
        );
        if (x == null) return null;
        final Uint8List bytes = await x.readAsBytes();
        final String name = p.basename(x.path);
        final String ext =
            p.extension(x.path).replaceFirst('.', '').toLowerCase();
        final String contentType =
            x.mimeType ?? lookupMimeType(x.path) ?? 'image/jpeg';
        return _Picked(
          bytes: bytes,
          fileName: name.isEmpty ? 'photo.$ext' : name,
          extension: ext.isEmpty ? 'jpg' : ext,
          contentType: contentType,
        );
      case DocPickerSource.file:
        final FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const <String>[
            'pdf',
            'jpg',
            'jpeg',
            'png',
            'heic',
            'webp'
          ],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return null;
        final PlatformFile f = result.files.single;
        final Uint8List? bytes = f.bytes ??
            (f.path != null ? await File(f.path!).readAsBytes() : null);
        if (bytes == null) return null;
        final String ext = (f.extension ?? '').toLowerCase();
        final String contentType =
            lookupMimeType(f.name) ?? 'application/octet-stream';
        return _Picked(
          bytes: bytes,
          fileName: f.name,
          extension: ext.isEmpty ? 'pdf' : ext,
          contentType: contentType,
        );
    }
  }
}

class _Picked {
  const _Picked({
    required this.bytes,
    required this.fileName,
    required this.extension,
    required this.contentType,
  });
  final Uint8List bytes;
  final String fileName;
  final String extension;
  final String contentType;
}

final AutoDisposeStateNotifierProvider<DocumentCaptureController,
        DocumentCaptureState> documentCaptureControllerProvider =
    StateNotifierProvider.autoDispose<DocumentCaptureController,
        DocumentCaptureState>(
  (Ref ref) => DocumentCaptureController(locator<DocumentRepository>()),
);
