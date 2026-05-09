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
    final String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 13) {
      return '+${digits.substring(0, 3)} ${digits.substring(3, 6)} '
          '${digits.substring(6, 9)} ${digits.substring(9)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) return const SizedBox.shrink();

    final OtpState state = ref.watch(_provider!);
    final OtpController c = ref.read(_provider!.notifier);
    final bool isSignUp = ref.watch(signUpControllerProvider).hasPendingProfile;

    return ScreenScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
                if (isSignUp) ...<Widget>[
                  const SizedBox(width: 12),
                  Text(
                    'STEP 2 OF 2',
                    style: AppTextStyles.mono.copyWith(
                      color: context.textDim,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: ProgressSteps(total: 2, completed: 2)),
                ],
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Verify your number.',
              style:
                  AppTextStyles.screenTitleSm.copyWith(color: context.text),
            ),
            const SizedBox(height: 10),
            Text(
              "We've sent a 6-digit code by SMS. Enter it below to "
              'continue.',
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            _PhoneCard(displayPhone: _displayPhone),
            const SizedBox(height: 22),
            PinInput(
              length: state.length,
              initial: state.value,
              onChanged: c.setValue,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 12),
              _ErrorRow(message: state.error!),
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
                      const TextSpan(text: "Didn't get it?  "),
                      TextSpan(
                        text: state.canResend
                            ? 'Resend now'
                            : 'Resend in 0:${state.resendSeconds.toString().padLeft(2, '0')}',
                        style: AppTextStyles.caption.copyWith(
                          color: state.canResend
                              ? context.accent
                              : context.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            DrivioButton(
              label: state.isVerifying ? 'Verifying…' : 'Verify & continue',
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

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.displayPhone});

  final String displayPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.accent.withValues(alpha: 0.14),
              borderRadius: AppRadius.sm,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.sms_rounded,
              size: 16,
              color: context.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'CODE SENT TO',
                  style: AppTextStyles.micro.copyWith(
                    color: context.textDim,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayPhone.isEmpty ? 'Your phone' : displayPhone,
                  style: AppTextStyles.h3.copyWith(color: context.text),
                ),
              ],
            ),
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
