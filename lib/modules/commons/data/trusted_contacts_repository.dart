import 'package:drivio_driver/modules/commons/types/trusted_contact.dart';

abstract class TrustedContactsRepository {
  /// List all of the calling driver's contacts (max 3 — enforced by
  /// `_enforce_trusted_contacts_cap` trigger on `trusted_contacts`).
  /// Primary first, then by created_at.
  Future<List<TrustedContact>> listMyContacts();

  /// Insert a new contact. Throws if the cap (3) is already reached, or
  /// if `isPrimary=true` collides with an existing primary (server-side
  /// partial unique index handles this).
  Future<TrustedContact> addContact({
    required String name,
    required String phoneE164,
    bool isPrimary = false,
  });

  /// Edit an existing contact. Pass only fields you want to change.
  Future<TrustedContact> updateContact({
    required String id,
    String? name,
    String? phoneE164,
  });

  /// Promote one contact to primary; the previous primary is demoted in
  /// the same transaction by `set_primary_trusted_contact` RPC so the
  /// partial-unique index never trips mid-update.
  Future<void> setPrimary(String id);

  Future<void> removeContact(String id);
}
