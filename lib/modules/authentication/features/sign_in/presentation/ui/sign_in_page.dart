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
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
                const Spacer(),
                const BrandMark(size: 32),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: context.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SIGN IN',
                  style: AppTextStyles.eyebrow.copyWith(
                    color: context.accent,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Welcome back,\ndriver.',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 10),
            Text(
              'Sign in to pick up where you left off.',
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
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
              const SizedBox(height: 12),
              _ErrorRow(message: state.error!),
            ],
            const SizedBox(height: 24),
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
            const SizedBox(height: 28),
            Center(
              child: GestureDetector(
                onTap: () =>
                    AppNavigation.replace<void, void>(AppRoutes.signUp),
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodySm.copyWith(color: context.textDim),
                    children: <InlineSpan>[
                      const TextSpan(text: 'New to Drivio?  '),
                      TextSpan(
                        text: 'Create an account',
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
