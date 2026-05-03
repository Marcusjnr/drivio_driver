import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/otp/presentation/logic/controller/otp_controller.dart';
import 'package:drivio_driver/modules/authentication/features/sign_in/presentation/logic/controller/sign_in_controller.dart';
import 'package:drivio_driver/modules/authentication/features/sign_up/presentation/logic/controller/sign_up_controller.dart';
import 'package:drivio_driver/modules/commons/all.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  StateNotifierProvider<OtpController, OtpState>? _provider;
  String _phone = '';
  String _displayPhone = '';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final String? arg =
        ModalRoute.of(context)?.settings.arguments as String?;
    _phone = arg ?? '';
    _displayPhone = _formatPhone(_phone);
    _provider = otpControllerForPhone(_phone);
  }

  String _formatPhone(String phone) {
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 13) {
      return '+${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6, 9)} ${digits.substring(9)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) return const SizedBox.shrink();

    final OtpState state = ref.watch(_provider!);
    final OtpController c = ref.read(_provider!.notifier);

    return ScreenScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BackButtonBox(onTap: () => AppNavigation.pop()),
            const SizedBox(height: 22),
            Text(
              'Verify your number.',
              style: AppTextStyles.screenTitleSm.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: AppTextStyles.bodySm.copyWith(
                  color: context.textDim,
                  height: 1.5,
                ),
                children: <InlineSpan>[
                  const TextSpan(text: 'We texted a 6-digit code to '),
                  TextSpan(
                    text: _displayPhone,
                    style: TextStyle(
                      color: context.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            PinInput(
              length: state.length,
              initial: state.value,
              onChanged: c.setValue,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: AppTextStyles.bodySm.copyWith(color: context.red),
              ),
            ],
            const SizedBox(height: 18),
            Center(
              child: GestureDetector(
                onTap: state.canResend ? () => c.resend() : null,
                child: RichText(
                  text: TextSpan(
                    style:
                        AppTextStyles.caption.copyWith(color: context.textDim),
                    children: <InlineSpan>[
                      const TextSpan(text: "Didn't get it? "),
                      TextSpan(
                        text: state.canResend
                            ? 'Resend now'
                            : 'Resend in 0:${state.resendSeconds.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: context.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            DrivioButton(
              label: state.isVerifying ? 'Verifying\u2026' : 'Verify & continue',
              onPressed: () async {
                final SignUpState signUpState =
                    ref.read(signUpControllerProvider);
                final bool isSignUp = signUpState.hasPendingProfile;

                final String email;
                final String password;
                String? phone;
                if (isSignUp) {
                  email = signUpState.email.trim();
                  password = signUpState.password;
                  phone = signUpState.normalizedPhone;
                } else {
                  final SignInState signInState =
                      ref.read(signInControllerProvider);
                  email = signInState.email.trim();
                  password = signInState.password;
                }

                final bool success = await c.verify(
                  mode: isSignUp ? AuthMode.signUp : AuthMode.signIn,
                  email: email,
                  password: password,
                  phone: phone,
                );
                if (!success || !mounted) return;

                if (isSignUp) {
                  final SignUpController signUpC =
                      ref.read(signUpControllerProvider.notifier);
                  final bool profileCreated = await signUpC.submitProfile();
                  if (!mounted) return;
                  if (profileCreated) {
                    signUpC.reset();
                    AppNavigation.replaceAll<void>(AppRoutes.home);
                    return;
                  }
                  final String? signUpError =
                      ref.read(signUpControllerProvider).error;
                  c.surfaceError(
                    signUpError ?? 'Could not create your profile.',
                  );
                  return;
                }

                final BootstrapController bootstrap =
                    ref.read(bootstrapControllerProvider.notifier);
                await bootstrap.resolve();
                if (mounted) {
                  AppNavigation.replaceAll<void>(
                    bootstrap.initialRoute,
                    arguments: bootstrap.initialArguments,
                  );
                }
              },
              disabled: !state.isComplete || state.isVerifying,
            ),
          ],
        ),
      ),
    );
  }
}
