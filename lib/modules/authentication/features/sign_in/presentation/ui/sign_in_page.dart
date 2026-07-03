import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/sign_in/presentation/logic/controller/sign_in_controller.dart';
import 'package:drivio_driver/modules/commons/all.dart';

/// SCR-004 — Sign In.
///
/// Ivory canvas. Back button top-left. Marcellus "Welcome back, driver"
/// + Albert Sans "Phone and password." Two fields (phone with 🇳🇬 +234
/// prefix + password with eye toggle), Forgot password link right-
/// aligned. Sticky bottom: coral "Sign in" CTA + ghost "Use Face ID".
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  late final TextEditingController _phone;
  late final TextEditingController _password;

  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    final SignInController c = ref.read(signInControllerProvider.notifier);
    final SignInState state = ref.read(signInControllerProvider);
    final bool success = await c.requestOtp();
    if (success && mounted) {
      AppNavigation.push(AppRoutes.otp, arguments: state.normalizedPhone);
    }
  }

  void _onForgotPassword() {
    // TODO: route to /forgot-password once the reset flow is built.
    AppNotifier.success(
      message: "We'll text you a reset link in a moment.",
    );
  }

  void _onUseFaceId() {
    // TODO: wire to local_auth biometric prompt + stored credentials.
    AppNotifier.success(
      message: 'Face ID is coming soon for returning drivers.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final SignInState state = ref.watch(signInControllerProvider);
    final SignInController c = ref.read(signInControllerProvider.notifier);

    return ScreenScaffold(
      bottomBar: _BottomBar(
        canSubmit: state.canSubmit && !state.isLoading,
        isLoading: state.isLoading,
        onSignIn: _onSignIn,
        onUseFaceId: _onUseFaceId,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Top row: back button only — no eyebrow, no progress bar.
            Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
              ],
            ),
            const SizedBox(height: 40),

            // Marcellus title — sits high on the page, gives the
            // returning driver an editorial welcome.
            Text(
              'Welcome back, driver',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Phone and password.',
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Phone (NG default per §3.4 pan-African — single country
            // for v1, then add country picker as we expand).
            PhoneNumberInput(
              controller: _phone,
              onChanged: c.onPhoneChanged,
              autofocus: true,
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
            const SizedBox(height: 12),

            // Forgot password — right-aligned, charcoal-teal text.
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _onForgotPassword,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
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

/// Sticky bottom bar — primary "Sign in" CTA + ghost "Use Face ID"
/// per SCR-004 mockup.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canSubmit,
    required this.isLoading,
    required this.onSignIn,
    required this.onUseFaceId,
  });

  final bool canSubmit;
  final bool isLoading;
  final VoidCallback onSignIn;
  final VoidCallback onUseFaceId;

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
              label: isLoading ? 'Sending code…' : 'Sign in',
              disabled: !canSubmit,
              onPressed: canSubmit ? onSignIn : null,
            ),
            // const SizedBox(height: 10),
            // SizedBox(
            //   height: 44,
            //   child: TextButton.icon(
            //     onPressed: onUseFaceId,
            //     icon: Icon(
            //       Icons.face_outlined,
            //       size: 18,
            //       color: context.text,
            //     ),
            //     label: Text(
            //       'Use Face ID',
            //       style: AppTextStyles.bodySm.copyWith(
            //         color: context.text,
            //         fontWeight: FontWeight.w600,
            //       ),
            //     ),
            //     style: TextButton.styleFrom(
            //       foregroundColor: context.text,
            //       padding: const EdgeInsets.symmetric(vertical: 12),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

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
