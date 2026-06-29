import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/analytics/analytics_events.dart';
import 'package:drivio_driver/modules/commons/analytics/mixpanel_service.dart';
import 'package:drivio_driver/modules/commons/data/document_repository.dart';
import 'package:drivio_driver/modules/commons/data/document_repository_impl.dart';
import 'package:drivio_driver/modules/commons/data/profile_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/document.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/data/kyc_repository.dart';

class SelfieState {
  const SelfieState({this.previewBytes, this.isSubmitting = false, this.error});

  final Uint8List? previewBytes;
  final bool isSubmitting;
  final String? error;

  bool get hasPreview => previewBytes != null;

  SelfieState copyWith({
    Uint8List? previewBytes,
    bool? isSubmitting,
    String? error,
    bool clearError = false,
  }) {
    return SelfieState(
      previewBytes: previewBytes ?? this.previewBytes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Persists the captured liveness image: it doubles as the KYC selfie
/// (private, for admin review) AND the driver's profile photo (public
/// `avatars` bucket). Marking the `selfie` step server-side sets
/// `drivers.liveness_passed_at`, which unblocks the ride-request feed.
class SelfieController extends StateNotifier<SelfieState> {
  SelfieController(this._docs, this._profiles, this._kyc)
    : super(const SelfieState());

  final DocumentRepository _docs;
  final ProfileRepository _profiles;
  final KycRepository _kyc;

  /// Upload the liveness capture at [imagePath] and complete the step.
  /// Returns true on success.
  Future<bool> submit(String imagePath) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final Uint8List bytes = await File(imagePath).readAsBytes();
      final String rawExt = p
          .extension(imagePath)
          .replaceFirst('.', '')
          .toLowerCase();
      final String fileExt = rawExt.isEmpty ? 'jpg' : rawExt;
      final String contentType = lookupMimeType(imagePath) ?? 'image/jpeg';
      state = state.copyWith(previewBytes: bytes);

      // 1. KYC selfie — private bucket, for admin face-match review.
      final String filePath = await _docs.uploadFile(
        kind: DocumentKind.profileSelfie,
        bytes: bytes,
        fileExtension: fileExt,
        contentType: contentType,
      );
      await _docs.registerDocument(
        kind: DocumentKind.profileSelfie,
        filePath: filePath,
      );

      // 2. Profile photo — public avatars bucket.
      final String avatarUrl = await _profiles.uploadAvatar(
        bytes: bytes,
        fileExtension: fileExt,
        contentType: contentType,
      );
      await _profiles.updateMyProfile(avatarUrl: avatarUrl);

      // 3. Mark the step → sets drivers.liveness_passed_at.
      await _kyc.markStepCompleted('selfie');
      locator<MixpanelService>().track(AnalyticsEvents.livenessCheckPassed);
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
        error: "Couldn't save your verification. Try again in a moment.",
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
        locator<ProfileRepository>(),
        locator<KycRepository>(),
      ),
    );
