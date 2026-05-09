import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/document_repository.dart';
import 'package:drivio_driver/modules/commons/data/document_repository_impl.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

class SelfieState {
  const SelfieState({
    this.previewBytes,
    this.isCapturing = false,
    this.isSubmitting = false,
    this.error,
  });

  final Uint8List? previewBytes;
  final bool isCapturing;
  final bool isSubmitting;
  final String? error;

  bool get hasPreview => previewBytes != null;

  SelfieState copyWith({
    Uint8List? previewBytes,
    bool? isCapturing,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
    bool clearPreview = false,
  }) {
    return SelfieState(
      previewBytes:
          clearPreview ? null : (previewBytes ?? this.previewBytes),
      isCapturing: isCapturing ?? this.isCapturing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SelfieController extends StateNotifier<SelfieState> {
  SelfieController(this._docs, this._kyc) : super(const SelfieState());

  final DocumentRepository _docs;
  final KycRepository _kyc;
  final ImagePicker _imagePicker = ImagePicker();
  String? _pendingExtension;
  String? _pendingContentType;

  Future<void> capture() async {
    state = state.copyWith(isCapturing: true, clearError: true);
    try {
      final XFile? x = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (x == null) {
        state = state.copyWith(isCapturing: false);
        return;
      }
      final Uint8List bytes = await x.readAsBytes();
      _pendingExtension =
          p.extension(x.path).replaceFirst('.', '').toLowerCase();
      if (_pendingExtension!.isEmpty) _pendingExtension = 'jpg';
      _pendingContentType =
          x.mimeType ?? lookupMimeType(x.path) ?? 'image/jpeg';
      state = state.copyWith(
        isCapturing: false,
        previewBytes: bytes,
      );
    } catch (_) {
      state = state.copyWith(
        isCapturing: false,
        error: "Couldn't open the camera. Check permissions and try again.",
      );
    }
  }

  void clear() => state = state.copyWith(clearPreview: true, clearError: true);

  Future<bool> submit() async {
    final Uint8List? bytes = state.previewBytes;
    if (bytes == null) return false;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final String filePath = await _docs.uploadFile(
        kind: DocumentKind.profileSelfie,
        bytes: bytes,
        fileExtension: _pendingExtension ?? 'jpg',
        contentType: _pendingContentType ?? 'image/jpeg',
      );
      await _docs.registerDocument(
        kind: DocumentKind.profileSelfie,
        filePath: filePath,
      );
      await _kyc.markStepCompleted('selfie');
      state = state.copyWith(isSubmitting: false);
      return true;
    } on DocumentAuthException {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Session expired. Sign in again.',
      );
      return false;
    } on StorageException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Upload failed: ${e.message}',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        error: "Couldn't submit your selfie. Try again in a moment.",
      );
      return false;
    }
  }
}

final AutoDisposeStateNotifierProvider<SelfieController, SelfieState>
    selfieControllerProvider =
    StateNotifierProvider.autoDispose<SelfieController, SelfieState>(
  (Ref ref) => SelfieController(
    locator<DocumentRepository>(),
    locator<KycRepository>(),
  ),
);
