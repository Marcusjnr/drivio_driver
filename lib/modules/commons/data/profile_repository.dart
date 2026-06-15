import 'dart:typed_data';

import 'package:drivio_driver/modules/commons/types/profile.dart';

abstract class ProfileRepository {
  Future<Profile?> getMyProfile();
  Future<Profile> updateMyProfile({
    String? fullName,
    String? email,
    String? phoneE164,
    DateTime? dob,
    String? gender,
    String? avatarUrl,
  });

  /// Upload an avatar image to the public `avatars` bucket and return its
  /// public URL. Pair with [updateMyProfile] to persist it on the profile.
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
    required String contentType,
  });

  /// Soft-delete the calling driver. Server (`request_account_deletion`
  /// RPC) refuses while there's an active trip; on success the row is
  /// stamped with `deleted_at = now()` and a hard delete sweep runs
  /// asynchronously. Caller must sign out after this resolves.
  Future<void> requestAccountDeletion();
}
