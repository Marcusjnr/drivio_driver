import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/trusted_contacts_repository.dart';
import 'package:drivio_driver/modules/commons/supabase/supabase_module.dart';
import 'package:drivio_driver/modules/commons/types/trusted_contact.dart';

class SupabaseTrustedContactsRepository implements TrustedContactsRepository {
  SupabaseTrustedContactsRepository(this._supabase);

  final SupabaseModule _supabase;

  @override
  Future<List<TrustedContact>> listMyContacts() async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) return const <TrustedContact>[];
    // Primary contact first, then in insert order.
    final List<Map<String, dynamic>> rows = await _supabase
        .db('trusted_contacts')
        .select()
        .eq('user_id', user.id)
        .order('is_primary', ascending: false)
        .order('created_at');
    return rows.map(TrustedContact.fromJson).toList(growable: false);
  }

  @override
  Future<TrustedContact> addContact({
    required String name,
    required String phoneE164,
    bool isPrimary = false,
  }) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const _ContactsAuthException();
    }
    final Map<String, dynamic> row = await _supabase
        .db('trusted_contacts')
        .insert(<String, dynamic>{
          'user_id': user.id,
          'name': name,
          'phone_e164': phoneE164,
          'is_primary': isPrimary,
        })
        .select()
        .single();
    return TrustedContact.fromJson(row);
  }

  @override
  Future<TrustedContact> updateContact({
    required String id,
    String? name,
    String? phoneE164,
  }) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const _ContactsAuthException();
    }
    final Map<String, dynamic> patch = <String, dynamic>{
      if (name != null) 'name': name,
      if (phoneE164 != null) 'phone_e164': phoneE164,
    };
    if (patch.isEmpty) {
      // Nothing to write — fetch & return the row as-is.
      final Map<String, dynamic> row = await _supabase
          .db('trusted_contacts')
          .select()
          .eq('id', id)
          .eq('user_id', user.id)
          .single();
      return TrustedContact.fromJson(row);
    }
    final Map<String, dynamic> row = await _supabase
        .db('trusted_contacts')
        .update(patch)
        .eq('id', id)
        .eq('user_id', user.id)
        .select()
        .single();
    return TrustedContact.fromJson(row);
  }

  @override
  Future<void> setPrimary(String id) async {
    // The RPC demotes the previous primary in the same transaction so the
    // partial-unique index never trips mid-update.
    await _supabase.client.rpc<dynamic>(
      'set_primary_trusted_contact',
      params: <String, dynamic>{'p_id': id},
    );
  }

  @override
  Future<void> removeContact(String id) async {
    final User? user = _supabase.auth.currentUser;
    if (user == null) {
      throw const _ContactsAuthException();
    }
    await _supabase
        .db('trusted_contacts')
        .delete()
        .eq('id', id)
        .eq('user_id', user.id);
  }
}

class _ContactsAuthException implements Exception {
  const _ContactsAuthException();
  @override
  String toString() => 'TrustedContactsAuthException: no signed-in user';
}
