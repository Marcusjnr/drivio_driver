import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/commons/data/profile_repository.dart';
import 'package:drivio_driver/modules/commons/di/di.dart';
import 'package:drivio_driver/modules/commons/types/profile.dart';

final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class ProfileEditState {
  const ProfileEditState({
    this.profile,
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.gender = '',
    this.isLoading = true,
    this.isSaving = false,
    this.error,
    this.savedAt,
  });

  final Profile? profile;
  final String fullName;
  final String email;
  final String phone;
  final String gender;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final DateTime? savedAt;

  bool get hasValidEmail =>
      email.trim().isEmpty || _emailRegex.hasMatch(email.trim());

  bool get isDirty {
    if (profile == null) return false;
    final String currentName = profile!.fullName;
    final String currentEmail = profile!.email ?? '';
    final String currentPhone = profile!.phoneE164 ?? '';
    final String currentGender = profile!.gender ?? '';
    return fullName.trim() != currentName ||
        email.trim() != currentEmail ||
        phone.trim() != currentPhone ||
        gender.trim() != currentGender;
  }

  bool get canSave =>
      isDirty && fullName.trim().length >= 2 && hasValidEmail && !isSaving;

  ProfileEditState copyWith({
    Profile? profile,
    String? fullName,
    String? email,
    String? phone,
    String? gender,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
    DateTime? savedAt,
  }) {
    return ProfileEditState(
      profile: profile ?? this.profile,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      savedAt: savedAt ?? this.savedAt,
    );
  }
}

class ProfileEditController extends StateNotifier<ProfileEditState> {
  ProfileEditController(this._repo) : super(const ProfileEditState()) {
    _hydrate();
  }

  final ProfileRepository _repo;

  Future<void> _hydrate() async {
    try {
      final Profile? p = await _repo.getMyProfile();
      if (!mounted) return;
      if (p == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Profile not found.',
        );
        return;
      }
      state = ProfileEditState(
        profile: p,
        fullName: p.fullName,
        email: p.email ?? '',
        phone: p.phoneE164 ?? '',
        gender: p.gender ?? '',
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: "Couldn't load your profile. Pull down to retry.",
      );
    }
  }

  void setFullName(String v) =>
      state = state.copyWith(fullName: v, clearError: true);
  void setEmail(String v) => state = state.copyWith(email: v, clearError: true);
  void setPhone(String v) => state = state.copyWith(phone: v, clearError: true);
  void setGender(String v) =>
      state = state.copyWith(gender: v, clearError: true);

  Future<bool> save() async {
    if (!state.canSave) return false;
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final Profile updated = await _repo.updateMyProfile(
        fullName: state.fullName.trim(),
        email: state.email.trim(),
        phoneE164: state.phone.trim(),
        gender: state.gender.trim(),
      );
      if (!mounted) return false;
      state = ProfileEditState(
        profile: updated,
        fullName: updated.fullName,
        email: updated.email ?? '',
        phone: updated.phoneE164 ?? '',
        gender: updated.gender ?? '',
        isLoading: false,
        isSaving: false,
        savedAt: DateTime.now(),
      );
      return true;
    } on PostgrestException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isSaving: false,
        error: e.message,
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      state = state.copyWith(
        isSaving: false,
        error: "Couldn't save. Check your connection and try again.",
      );
      return false;
    }
  }
}

final StateNotifierProvider<ProfileEditController, ProfileEditState>
    profileEditControllerProvider =
    StateNotifierProvider<ProfileEditController, ProfileEditState>(
  (Ref _) => ProfileEditController(locator<ProfileRepository>()),
);
