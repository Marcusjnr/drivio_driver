import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/sign_up/presentation/logic/controller/sign_up_controller.dart';
import 'package:drivio_driver/modules/commons/all.dart';

/// SCR-003 — Sign Up.
///
/// Ivory canvas. Back button top-left. Eyebrow / Marcellus title /
/// Albert Sans body. Five stacked floating-label fields (full name,
/// email, phone with 🇳🇬 +234 prefix, password with eye toggle,
/// referral code optional). Sticky bottom: coral "Continue" CTA +
/// terms micro-copy with linked words underlined.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late final TextEditingController _referral;

  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _password = TextEditingController();
    _referral = TextEditingController();
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _referral.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final SignUpController c = ref.read(signUpControllerProvider.notifier);
    final bool success = await c.requestOtp();
    if (success && mounted) {
      final String phone = ref.read(signUpControllerProvider).normalizedPhone;
      AppNavigation.push(AppRoutes.otp, arguments: phone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SignUpState state = ref.watch(signUpControllerProvider);
    final SignUpController c = ref.read(signUpControllerProvider.notifier);

    return ScreenScaffold(
      bottomBar: _BottomBar(
        canSubmit: state.canSubmit && !state.isLoading,
        isLoading: state.isLoading,
        onPressed: _onContinue,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Top row: back button only, per mockup.
            Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
              ],
            ),
            const SizedBox(height: 28),

            // Eyebrow — uppercase, letter-spaced.
            Text(
              'STEP 1 OF 2',
              style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 14),

            // Marcellus screen title.
            Text(
              'Create your account',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),

            // Albert Sans dim body.
            Text(
              'Phone, then a few quick details.',
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),

            // Stacked form fields per SCR-003.
            DrivioInput(
              label: 'Full name',
              controller: _fullName,
              onChanged: c.onFullNameChanged,
              autofocus: true,
            ),
            const SizedBox(height: 14),
            DrivioInput(
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              controller: _email,
              onChanged: c.onEmailChanged,
            ),
            const SizedBox(height: 14),
            PhoneNumberInput(
              controller: _phone,
              onChanged: c.onPhoneChanged,
            ),
            const SizedBox(height: 14),
            DrivioInput(
              label: 'Password',
              obscure: !_showPassword,
              controller: _password,
              onChanged: c.onPasswordChanged,
              suffix: _PasswordEyeToggle(
                visible: _showPassword,
                onTap: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            const SizedBox(height: 14),
            DrivioInput(
              label: 'Referral code (optional)',
              controller: _referral,
              onChanged: c.onReferralChanged,
            ),

            if (state.error != null) ...<Widget>[
              const SizedBox(height: 16),
              _ErrorRow(message: state.error!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sticky bottom bar — primary CTA + the terms micro-copy with
/// underlined "Terms" and "Privacy Policy" per SCR-003 mockup.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canSubmit,
    required this.isLoading,
    required this.onPressed,
  });

  final bool canSubmit;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: BoxDecoration(color: context.bg),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DrivioButton(
              label: isLoading ? 'Sending code…' : 'Continue',
              disabled: !canSubmit,
              onPressed: canSubmit ? onPressed : null,
            ),
            const SizedBox(height: 12),
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.captionSm.copyWith(
                    color: context.textMuted,
                    height: 1.5,
                  ),
                  children: <InlineSpan>[
                    const TextSpan(text: 'By continuing you agree to our '),
                    TextSpan(
                      text: 'Terms',
                      style: AppTextStyles.captionSm.copyWith(
                        color: context.text,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: AppTextStyles.captionSm.copyWith(
                        color: context.text,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eye / eye-off toggle for the password field's suffix slot. Lucide-
/// style line icons via Material's built-in equivalents.
class _PasswordEyeToggle extends StatelessWidget {
  const _PasswordEyeToggle({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          visible
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
          color: context.textDim,
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.red.withValues(alpha: 0.10),
        borderRadius: AppRadius.md,
        border: Border.all(color: context.red.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 16, color: context.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySm.copyWith(
                color: context.red,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
