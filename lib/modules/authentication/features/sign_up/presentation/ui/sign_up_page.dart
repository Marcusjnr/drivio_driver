import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/sign_up/presentation/logic/controller/sign_up_controller.dart';
import 'package:drivio_driver/modules/commons/all.dart';

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
                const SizedBox(width: 12),
                Text(
                  'STEP 1 OF 2',
                  style: AppTextStyles.mono.copyWith(
                    color: context.textDim,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: ProgressSteps(total: 2, completed: 1)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              "Let's set up your\ndriver account.",
              style:
                  AppTextStyles.screenTitleSm.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            Text(
              "Takes about 3 minutes. You'll need your ID and vehicle "
              'docs ready.',
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            DrivioInput(
              label: 'Full name',
              hint: 'Tunde Ogunleye',
              controller: _fullName,
              onChanged: c.onFullNameChanged,
              compact: true,
            ),
            const SizedBox(height: 12),
            DrivioInput(
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              controller: _email,
              onChanged: c.onEmailChanged,
              compact: true,
            ),
            const SizedBox(height: 12),
            const SectionLabel(text: 'Phone number'),
            const SizedBox(height: 6),
            PhoneNumberInput(
              controller: _phone,
              onChanged: c.onPhoneChanged,
            ),
            const SizedBox(height: 12),
            DrivioInput(
              label: 'Password',
              hint: 'At least 8 characters',
              obscure: true,
              controller: _password,
              onChanged: c.onPasswordChanged,
              compact: true,
            ),
            const SizedBox(height: 14),
            _ReferralCard(
              controller: _referral,
              onChanged: c.onReferralChanged,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 14),
              _ErrorRow(message: state.error!),
            ],
            const SizedBox(height: 24),
            DrivioButton(
              label: state.isLoading ? 'Sending code…' : 'Continue',
              disabled: !state.canSubmit || state.isLoading,
              onPressed: state.canSubmit && !state.isLoading ? _onContinue : null,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                "By continuing you agree to Drivio's Driver Agreement & "
                'Privacy Policy.',
                textAlign: TextAlign.center,
                style: AppTextStyles.captionSm.copyWith(
                  color: context.textMuted,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: GestureDetector(
                onTap: () =>
                    AppNavigation.replace<void, void>(AppRoutes.signIn),
                child: RichText(
                  text: TextSpan(
                    style:
                        AppTextStyles.bodySm.copyWith(color: context.textDim),
                    children: <InlineSpan>[
                      const TextSpan(text: 'Have an account?  '),
                      TextSpan(
                        text: 'Sign in',
                        style: AppTextStyles.bodySm.copyWith(
                          color: context.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralCard extends ConsumerWidget {
  const _ReferralCard({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.16),
                  borderRadius: AppRadius.sm,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.card_giftcard_rounded,
                  size: 16,
                  color: context.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Have a referral code?',
                      style: AppTextStyles.h3.copyWith(color: context.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get 1 extra free month on us.',
                      style: AppTextStyles.captionSm.copyWith(
                        color: context.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DrivioInput(
            hint: 'Enter code',
            controller: controller,
            onChanged: onChanged,
            compact: true,
          ),
        ],
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
