import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:drivio_driver/modules/commons/data/profile_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/profile.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._supabase);

  final SupabaseModule _supabase;
  final Uuid _uuid = const Uuid();

  @override
  Future<Profile?> getMyProfile() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return null;
    final List<Map<String, dynamic>> rows = await _supabase
        .db('profiles')
        .select()
        .eq('user_id', user.id)
        .limit(1);
    if (rows.isEmpty) return null;
    return Profile.fromJson(rows.first);
  }

  @override
  Future<Profile> updateMyProfile({
    String? fullName,
    String? email,
    String? phoneE164,
    DateTime? dob,
    String? gender,
    String? avatarUrl,
  }) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const _ProfileAuthException();
    }
    // Only send fields the caller provided so we never overwrite a column
    // they didn't intend to touch.
    final Map<String, dynamic> patch = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (email != null) 'email': email.isEmpty ? null : email,
      if (phoneE164 != null) 'phone_e164': phoneE164,
      if (dob != null)
        'dob':
            '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}',
      if (gender != null) 'gender': gender.isEmpty ? null : gender,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
    if (patch.isEmpty) {
      // Nothing to update — return the current row.
      return (await getMyProfile())!;
    }
    final Map<String, dynamic> row = await _supabase
        .db('profiles')
        .update(patch)
        .eq('user_id', user.id)
        .select()
        .single();
    return Profile.fromJson(row);
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
    required String contentType,
  }) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const _ProfileAuthException();
    }
    final String safeExt = fileExtension
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toLowerCase();
    final String objectPath =
        '${user.id}/${_uuid.v4()}.${safeExt.isEmpty ? 'jpg' : safeExt}';
    await _supabase.storage
        .from('avatars')
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _supabase.storage.from('avatars').getPublicUrl(objectPath);
  }

  @override
  Future<void> requestAccountDeletion() async {
    // Server-side gating in `request_account_deletion`:
    //  - throws `active_trip_in_progress` if any non-terminal trip exists,
    //  - stamps `drivers.deleted_at = now()` so RLS hides the row going
    //    forward.
    // The caller is responsible for signing the user out once this returns.
    await _supabase.client.rpc<dynamic>('request_account_deletion');
  }
}

class _ProfileAuthException implements Exception {
  const _ProfileAuthException();
  @override
  String toString() => 'ProfileAuthException: no signed-in user';
}
