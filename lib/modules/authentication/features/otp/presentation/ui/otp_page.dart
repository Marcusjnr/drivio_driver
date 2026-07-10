import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/otp/presentation/logic/controller/otp_controller.dart';
import 'package:drivio_driver/modules/authentication/features/sign_in/presentation/logic/controller/sign_in_controller.dart';
import 'package:drivio_driver/modules/authentication/features/sign_up/presentation/logic/controller/sign_up_controller.dart';
import 'package:drivio_driver/modules/commons/all.dart';

/// SCR-005 — OTP Verification.
///
/// Ivory canvas. Back button + eyebrow ("STEP 2 OF 2" when reached from
/// sign-up). Marcellus "Enter the code" + body "We sent it to `<phone>`."
/// Six pin cells, then countdown ("Resend (24s)") that converts to a
/// coral "Resend code" link when the timer runs out. Sticky bottom CTA
/// "Verify & continue".
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
  AuthMode? _mode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    // Pushed with {'phone': ..., 'mode': 'signIn'|'signUp'} so this screen
    // KNOWS which flow launched it. Guessing from leftover sign-up form
    // state used to hijack sign-in after a failed sign-up in the same
    // session ("That number already has an account" on the Sign In flow).
    final Object? arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Map) {
      _phone = (arg['phone'] as String?) ?? '';
      _mode = arg['mode'] == 'signUp'
          ? AuthMode.signUp
          : arg['mode'] == 'signIn'
              ? AuthMode.signIn
              : null;
    } else if (arg is String) {
      _phone = arg;
    }
    _displayPhone = _formatPhone(_phone);
    _provider = otpControllerForPhone(_phone);
  }

  /// "+2348123354467" → "+234 812 335 4467" per SCR-005 mockup.
  String _formatPhone(String phone) {
    final String digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 13) {
      return '+${digits.substring(0, 3)} ${digits.substring(3, 6)} '
          '${digits.substring(6, 9)} ${digits.substring(9)}';
    }
    return phone;
  }

  Future<void> _onVerify() async {
    final OtpController c = ref.read(_provider!.notifier);
    final SignUpState signUpState = ref.read(signUpControllerProvider);
    // Explicit mode from the launching screen; the stale-state guess only
    // remains as a fallback for a legacy string-only route argument.
    final bool isSignUp = _mode != null
        ? _mode == AuthMode.signUp
        : signUpState.hasPendingProfile;

    final String phone;
    final String password;
    Map<String, dynamic>? signUpData;

    if (isSignUp) {
      phone = signUpState.normalizedPhone;
      password = signUpState.password;
      // Real email + name + referral travel into Supabase's
      // `raw_user_meta_data` so the post-OTP profile insert can
      // resolve them when needed.
      signUpData = <String, dynamic>{
        'full_name': signUpState.fullName.trim(),
        'email': signUpState.email.trim(),
        'referred_by': signUpState.referralCode.trim().isEmpty
            ? null
            : signUpState.referralCode.trim(),
      };
    } else {
      final SignInState signInState = ref.read(signInControllerProvider);
      phone = signInState.normalizedPhone;
      password = signInState.password;
    }

    final bool success = await c.verify(
      mode: isSignUp ? AuthMode.signUp : AuthMode.signIn,
      phone: phone,
      password: password,
      signUpData: signUpData,
    );
    if (!success || !mounted) return;

    if (isSignUp) {
      final SignUpController signUpC =
          ref.read(signUpControllerProvider.notifier);
      final bool profileCreated = await signUpC.submitProfile();
      if (!mounted) return;
      if (profileCreated) {
        // Navigate first; reset the (app-scoped) sign-up state once the
        // transition has covered this screen.
        AppNavigation.replaceAll<void>(AppRoutes.home);
        Future<void>.delayed(const Duration(milliseconds: 800), signUpC.reset);
        return;
      }
      final String? signUpError =
          ref.read(signUpControllerProvider).error;
      c.surfaceError(
        signUpError ??
            "Couldn't create your profile. Try again in a moment.",
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
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) return const SizedBox.shrink();

    final OtpState state = ref.watch(_provider!);
    final OtpController c = ref.read(_provider!.notifier);
    final bool isSignUp = ref.watch(signUpControllerProvider).hasPendingProfile;

    return ScreenScaffold(
      bottomBar: _BottomBar(
        canVerify: state.isComplete && !state.isVerifying,
        isVerifying: state.isVerifying,
        onPressed: _onVerify,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Top row — back button only. Progress bar omitted per
            // SCR-005 mockup; the eyebrow below indicates step state.
            Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
              ],
            ),
            const SizedBox(height: 28),

            // Eyebrow only when reached from sign-up — for sign-in
            // the OTP is a one-step verify with no "STEP X OF Y" frame.
            if (isSignUp) ...<Widget>[
              Text(
                'STEP 2 OF 2',
                style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
              ),
              const SizedBox(height: 14),
            ],

            Text(
              'Enter the code',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            Text(
              _displayPhone.isEmpty
                  ? 'We sent it to your phone.'
                  : 'We sent it to $_displayPhone.',
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            PinInput(
              length: state.length,
              initial: state.value,
              onChanged: c.setValue,
            ),

            if (state.error != null) ...<Widget>[
              const SizedBox(height: 14),
              _ErrorRow(message: state.error!),
            ],

            const SizedBox(height: 18),

            // Resend — center-aligned. Countdown copy mirrors the
            // mockup's "Resend (24s)" form. When the timer hits zero
            // the label flips to a tappable "Resend code" in coral.
            Center(
              child: GestureDetector(
                onTap: state.canResend ? () => c.resend() : null,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    state.canResend
                        ? 'Resend code'
                        : 'Resend (${state.resendSeconds}s)',
                    style: AppTextStyles.bodySm.copyWith(
                      color: state.canResend
                          ? context.coral
                          : context.textDim,
                      fontWeight: FontWeight.w600,
                    ),
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

/// Sticky bottom CTA — "Verify & continue" per SCR-005, disabled
/// until 6 digits are entered.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canVerify,
    required this.isVerifying,
    required this.onPressed,
  });

  final bool canVerify;
  final bool isVerifying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: BoxDecoration(color: context.bg),
      child: SafeArea(
        top: false,
        child: DrivioButton(
          label: isVerifying ? 'Verifying…' : 'Verify & continue',
          disabled: !canVerify,
          onPressed: canVerify ? onPressed : null,
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
