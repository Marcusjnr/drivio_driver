import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/sign_in/presentation/logic/controller/sign_in_controller.dart';
import 'package:drivio_driver/modules/commons/all.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  late final TextEditingController _email;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SignInState state = ref.watch(signInControllerProvider);
    final SignInController c = ref.read(signInControllerProvider.notifier);
    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 60, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const BrandMark(size: 40),
            const SizedBox(height: 22),
            Text(
              'Welcome back,\ndriver.',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to pick up where you left off.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 26),
            DrivioInput(
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              controller: _email,
              onChanged: c.onEmailChanged,
              compact: true,
            ),
            const SizedBox(height: 12),
            DrivioInput(
              label: 'Password',
              hint: 'Your password',
              obscure: true,
              controller: _password,
              onChanged: c.onPasswordChanged,
              compact: true,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                state.error!,
                style: AppTextStyles.bodySm.copyWith(color: context.red),
              ),
            ],
            const SizedBox(height: 22),
            DrivioButton(
              label: state.isLoading ? 'Sending code…' : 'Continue',
              onPressed: () async {
                final bool success = await c.requestOtp();
                if (success && mounted) {
                  AppNavigation.push(AppRoutes.otp,
                      arguments: state.email.trim());
                }
              },
              disabled: !state.canSubmit || state.isLoading,
            ),
            const SizedBox(height: 36),
            Center(
              child: Text(
                'New here? Tap back and create an account.',
                style: AppTextStyles.bodySm.copyWith(color: context.textDim),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
