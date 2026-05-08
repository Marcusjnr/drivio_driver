import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/profile/features/profile_edit/presentation/logic/controller/profile_edit_controller.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _gender;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _gender = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _gender.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProfileEditState state = ref.watch(profileEditControllerProvider);
    final ProfileEditController c =
        ref.read(profileEditControllerProvider.notifier);

    // Seed text controllers once after the profile loads.
    if (!_initialised && state.profile != null) {
      _initialised = true;
      _name.text = state.fullName;
      _email.text = state.email;
      _phone.text = state.phone;
      _gender.text = state.gender;
    }

    if (state.isLoading) {
      return const ScreenScaffold(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.profile == null) {
      return ScreenScaffold(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              state.error ?? 'Could not load your profile.',
              style: AppTextStyles.bodySm.copyWith(color: context.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Edit profile',
                    style: AppTextStyles.h2.copyWith(color: context.text),
                  ),
                ),
                if (state.savedAt != null && !state.isDirty)
                  const Pill(text: 'Saved', tone: PillTone.accent),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'These details show on receipts and to riders during a trip.',
              style: AppTextStyles.caption.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 22),
            Center(
              child: Avatar(
                name: state.fullName.isEmpty
                    ? state.profile!.fullName
                    : state.fullName,
                variant: 1,
                size: 76,
              ),
            ),
            const SizedBox(height: 22),
            DrivioInput(
              label: 'Full name',
              controller: _name,
              onChanged: c.setFullName,
              compact: true,
            ),
            const SizedBox(height: 12),
            DrivioInput(
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              controller: _email,
              onChanged: c.setEmail,
              compact: true,
            ),
            const SizedBox(height: 12),
            DrivioInput(
              label: 'Phone',
              hint: '+234…',
              keyboardType: TextInputType.phone,
              controller: _phone,
              onChanged: c.setPhone,
              compact: true,
            ),
            const SizedBox(height: 12),
            DrivioInput(
              label: 'Gender (optional)',
              controller: _gender,
              onChanged: c.setGender,
              compact: true,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: AppTextStyles.bodySm.copyWith(color: context.red),
              ),
            ],
            const SizedBox(height: 22),
            DrivioButton(
              label: state.isSaving ? 'Saving…' : 'Save changes',
              disabled: !state.canSave,
              onPressed: () async {
                final bool ok = await c.save();
                if (!mounted) return;
                if (ok) {
                  AppNotifier.success(message: 'Profile updated.');
                }
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Phone number changes go through OTP re-verification (coming soon).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: context.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
