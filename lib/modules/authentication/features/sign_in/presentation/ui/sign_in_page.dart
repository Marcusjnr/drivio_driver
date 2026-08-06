import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/sign_in/presentation/logic/controller/sign_in_controller.dart';
import 'package:drivio_driver/modules/authentication/features/sign_in/presentation/ui/widgets/enable_biometrics_sheet.dart';
import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/biometric/biometric_service.dart';
import 'package:drivio_driver/modules/commons/storage/secure_store.dart';

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

  // Biometric state, mirroring kalabash_mobile_v2's sign-in page.
  bool _biometricAutoAttempted = false;
  bool _biometricInFlight = false;
  bool _biometricAvailable = false;
  bool _biometricIsFaceId = false;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController();
    _password = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshBiometricAvailability());
      unawaited(_maybeBiometricLogin(auto: true));
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Whether the device has enrolled biometrics at all, independent of
  /// whether this driver opted in. Drives the shortcut icon and remembers
  /// Face ID vs fingerprint so the label matches the hardware.
  Future<void> _refreshBiometricAvailability() async {
    final BiometricCheckResult check =
        await locator<BiometricService>().check();
    if (!mounted) return;
    final bool available = check.canCheck && check.types.isNotEmpty;
    if (available != _biometricAvailable ||
        check.hasFaceId != _biometricIsFaceId) {
      setState(() {
        _biometricAvailable = available;
        _biometricIsFaceId = check.hasFaceId;
      });
    }
  }

  /// A manual tap on the biometric icon.
  ///
  /// Two different jobs depending on how far setup has got. Once the
  /// driver has opted in AND a password is cached, it signs them in.
  /// Before that, it offers to turn biometrics on, so the icon is never
  /// a dead button for someone who has not signed in on this phone yet.
  Future<void> _onBiometricButtonTap() async {
    if (_biometricInFlight) return;
    final SecureStore store = locator<SecureStore>();
    final bool enabled = await store.readBool(SecureKeys.enableLocalLogin);
    final String? password = await store.readString(SecureKeys.userPassword);
    if (!mounted) return;

    final bool setupComplete =
        enabled && password != null && password.isNotEmpty;
    if (setupComplete) {
      await _maybeBiometricLogin(auto: false);
      return;
    }
    await _showEnableBiometricsForNextTime();
  }

  /// Turn biometrics on before there is anything to unlock.
  ///
  /// Passing the OS prompt flips the opt-in, which is what the Settings
  /// toggle reads, and the driver stays here to sign in with their
  /// password this once. That sign in caches the password, completing
  /// setup, so the next launch can go straight to the prompt.
  ///
  /// Everything written here lives in the device keystore. Nothing about
  /// biometrics is sent to or stored on Supabase.
  Future<void> _showEnableBiometricsForNextTime() async {
    final bool? proceed = await showEnableBiometricsSheet(
      context,
      isFaceId: _biometricIsFaceId,
    );
    if (proceed != true || !mounted || _biometricInFlight) return;

    _biometricInFlight = true;
    try {
      final BiometricAuthResult result =
          await locator<BiometricService>().authenticate(
        reason: 'Confirm it is you to turn on biometric sign in',
      );
      if (!mounted) return;
      if (!result.success) {
        AppNotifier.error(
          message: result.errorMessage ?? 'That did not work. Try again.',
        );
        return;
      }
      await locator<SecureStore>()
          .writeBool(SecureKeys.enableLocalLogin, true);
      if (!mounted) return;
      AppNotifier.success(
        message: 'Turned on. Sign in once more and it is ready next time.',
      );
    } finally {
      _biometricInFlight = false;
    }
  }

  /// Drives biometric sign in.
  ///
  /// `auto: true` fires once when the screen opens, so a driver who
  /// enabled it sees the OS prompt immediately. `auto: false` comes from
  /// tapping the shortcut. Both respect [_biometricInFlight] so prompts
  /// never stack.
  Future<void> _maybeBiometricLogin({required bool auto}) async {
    if (auto) {
      if (_biometricAutoAttempted) return;
      _biometricAutoAttempted = true;
    }
    if (_biometricInFlight) return;

    final SecureStore store = locator<SecureStore>();
    if (!await store.readBool(SecureKeys.enableLocalLogin)) return;

    final String? phone = await store.readString(SecureKeys.userPhoneNumber);
    final String? password = await store.readString(SecureKeys.userPassword);
    if (phone == null || password == null || password.isEmpty) return;

    final BiometricService biometric = locator<BiometricService>();
    final BiometricCheckResult check = await biometric.check();
    if (!check.canCheck || check.types.isEmpty) return;

    _biometricInFlight = true;
    try {
      final BiometricAuthResult result = await biometric.authenticate(
        reason: 'Confirm it is you to sign in to Drivio',
      );
      if (!result.success || !mounted) return;

      final SignInController c = ref.read(signInControllerProvider.notifier);
      final bool ok = await c.signInWithStoredCredentials(
        phoneE164: phone,
        password: password,
      );
      if (ok && mounted) await _enterApp();
    } finally {
      _biometricInFlight = false;
    }
  }

  Future<void> _onSignIn() async {
    final SignInController c = ref.read(signInControllerProvider.notifier);
    final bool success = await c.signIn();
    if (!success || !mounted) return;
    // Offer biometrics before leaving, while the password that would be
    // stored is still the one just proved to work.
    await _maybeOfferBiometrics();
    if (mounted) await _enterApp();
  }

  /// One-time offer after a successful password sign in. Skipped when
  /// already on, previously declined, or the device has no biometrics.
  Future<void> _maybeOfferBiometrics() async {
    final SecureStore store = locator<SecureStore>();
    if (await store.readBool(SecureKeys.enableLocalLogin)) return;
    if (await store.readBool(SecureKeys.biometricPromptDismissed)) return;
    if (!_biometricAvailable || !mounted) return;

    final bool? enable = await showEnableBiometricsSheet(
      context,
      isFaceId: _biometricIsFaceId,
    );
    if (enable != true) {
      await store.writeBool(SecureKeys.biometricPromptDismissed, true);
      return;
    }
    final BiometricAuthResult result =
        await locator<BiometricService>().authenticate(
      reason: 'Confirm it is you to turn on biometric sign in',
    );
    if (result.success) {
      await store.writeBool(SecureKeys.enableLocalLogin, true);
      AppNotifier.success(message: 'Biometric sign in is on.');
    }
  }

  /// Resolve where this driver belongs and go there, replacing the auth
  /// stack. Same handoff the OTP page used to perform.
  Future<void> _enterApp() async {
    final BootstrapController bootstrap =
        ref.read(bootstrapControllerProvider.notifier);
    await bootstrap.resolve();
    if (!mounted) return;
    AppNavigation.replaceAll<void>(
      bootstrap.initialRoute,
      arguments: bootstrap.initialArguments,
    );
  }

  void _onForgotPassword() {
    AppNavigation.push<void>(AppRoutes.forgotPassword);
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

            // Biometric shortcut. Sits above the CTA rather than under
            // it, and is hidden while the keyboard is up so it never
            // fights the fields for room.
            if (_biometricAvailable &&
                MediaQuery.viewInsetsOf(context).bottom == 0) ...<Widget>[
              const SizedBox(height: 36),
              Center(
                child: _BiometricUnlockButton(
                  isFaceId: _biometricIsFaceId,
                  enabled: !state.isLoading,
                  onTap: _onBiometricButtonTap,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rounded-square biometric shortcut, mirroring the panel in
/// kalabash_mobile_v2's sign-in page.
///
/// The glyph follows the hardware: a face for Face ID devices, a
/// fingerprint otherwise, decided by what `local_auth` reports is
/// actually enrolled.
class _BiometricUnlockButton extends StatelessWidget {
  const _BiometricUnlockButton({
    required this.isFaceId,
    required this.enabled,
    required this.onTap,
  });

  final bool isFaceId;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkResponse(
            radius: 48,
            onTap: enabled ? onTap : null,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.coral.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.coral.withValues(alpha: 0.28),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                isFaceId ? DrivioIcons.faceId : DrivioIcons.fingerprint,
                size: 38,
                color: context.coral,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isFaceId ? 'Use Face ID' : 'Use fingerprint',
            style: AppTextStyles.bodySm.copyWith(
              color: context.textDim,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom bar — the primary "Sign in" CTA. The biometric
/// shortcut lives in the body above it, not here.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.canSubmit,
    required this.isLoading,
    required this.onSignIn,
  });

  final bool canSubmit;
  final bool isLoading;
  final VoidCallback onSignIn;

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
              label: isLoading ? 'Signing in…' : 'Sign in',
              disabled: !canSubmit,
              onPressed: canSubmit ? onSignIn : null,
            ),
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
