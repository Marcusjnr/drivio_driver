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

  /// Soft-delete the calling driver. Server (`request_account_deletion`
  /// RPC) refuses while there's an active trip; on success the row is
  /// stamped with `deleted_at = now()` and a hard delete sweep runs
  /// asynchronously. Caller must sign out after this resolves.
  Future<void> requestAccountDeletion();
}
