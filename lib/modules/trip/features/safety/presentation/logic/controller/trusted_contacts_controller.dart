import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/data/trusted_contacts_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/errors/error_messages.dart';
import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/types/trusted_contact.dart';

/// Hard cap mirrored from the server-side `_enforce_trusted_contacts_cap`
/// trigger. UI uses this to grey-out the "Add contact" row pre-emptively
/// instead of round-tripping for the failure.
const int kTrustedContactsCap = 3;

class TrustedContactsState {
  const TrustedContactsState({
    this.contacts = const <TrustedContact>[],
    this.isLoading = true,
    this.isMutating = false,
    this.error,
  });

  final List<TrustedContact> contacts;
  final bool isLoading;
  final bool isMutating;
  final String? error;

  bool get isFull => contacts.length >= kTrustedContactsCap;

  TrustedContactsState copyWith({
    List<TrustedContact>? contacts,
    bool? isLoading,
    bool? isMutating,
    String? error,
    bool clearError = false,
  }) {
    return TrustedContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Owns the driver's trusted-contacts list. All writes optimistically
/// reload from the server so we always render what RLS would return —
/// avoids drift if the partial-unique index demoted/promoted rows
/// behind us.
class TrustedContactsController
    extends StateNotifier<TrustedContactsState> {
  TrustedContactsController(this._repo) : super(const TrustedContactsState()) {
    _hydrate();
  }

  final TrustedContactsRepository _repo;

  Future<void> _hydrate() async {
    try {
      final List<TrustedContact> rows = await _repo.listMyContacts();
      if (!mounted) return;
      state = state.copyWith(contacts: rows, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load contacts.',
      );
    }
  }

  Future<void> refresh() => _hydrate();

  Future<bool> add({
    required String name,
    required String phoneE164,
    bool isPrimary = false,
  }) async {
    if (state.isFull) {
      state = state.copyWith(error: 'You can only have $kTrustedContactsCap contacts.');
      return false;
    }
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      // If caller asked for primary AND another primary exists, demote it
      // first via the RPC so we don't fight the partial-unique index.
      if (isPrimary) {
        await _repo.addContact(name: name, phoneE164: phoneE164);
        // The freshly-inserted row is non-primary; promote via RPC.
        final List<TrustedContact> rows = await _repo.listMyContacts();
        final TrustedContact added = rows.firstWhere(
          (TrustedContact c) =>
              c.name == name && c.phoneE164 == phoneE164,
          orElse: () => rows.last,
        );
        await _repo.setPrimary(added.id);
      } else {
        await _repo.addContact(name: name, phoneE164: phoneE164);
      }
      await _hydrate();
      if (!mounted) return false;
      state = state.copyWith(isMutating: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isMutating: false,
        error: _friendly(e, fallback: 'Could not add contact.'),
      );
      return false;
    }
  }

  Future<bool> update({
    required String id,
    String? name,
    String? phoneE164,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repo.updateContact(id: id, name: name, phoneE164: phoneE164);
      await _hydrate();
      if (!mounted) return false;
      state = state.copyWith(isMutating: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isMutating: false,
        error: _friendly(e, fallback: 'Could not update contact.'),
      );
      return false;
    }
  }

  Future<bool> setPrimary(String id) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repo.setPrimary(id);
      await _hydrate();
      if (!mounted) return false;
      state = state.copyWith(isMutating: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isMutating: false,
        error: _friendly(e, fallback: 'Could not set primary contact.'),
      );
      return false;
    }
  }

  Future<bool> remove(String id) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repo.removeContact(id);
      await _hydrate();
      if (!mounted) return false;
      state = state.copyWith(isMutating: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isMutating: false,
        error: _friendly(e, fallback: 'Could not remove contact.'),
      );
      return false;
    }
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  String _friendly(Object e, {required String fallback}) {
    final String msg = e.toString();
    AppLogger.w('Trusted contact mutation failed', error: e);
    if (msg.contains('trusted_contacts_one_primary_per_user')) {
      return 'You already have a primary contact.';
    }
    if (msg.contains('trusted_contacts_user_id_phone_e164_key') ||
        msg.contains('duplicate key')) {
      return 'That phone number is already saved.';
    }
    if (msg.contains('trusted_contacts_cap')) {
      return 'You can only have $kTrustedContactsCap contacts.';
    }
    return humaniseError(e, fallback: fallback);
  }
}

final StateNotifierProvider<TrustedContactsController, TrustedContactsState>
    trustedContactsControllerProvider =
    StateNotifierProvider<TrustedContactsController, TrustedContactsState>(
  (Ref _) =>
      TrustedContactsController(locator<TrustedContactsRepository>()),
);
