import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:drivio_driver/modules/authentication/features/sign_up/presentation/logic/controller/sign_up_controller.dart';
import 'package:drivio_driver/modules/commons/all.dart';

/// SCR-003 — Sign Up.
///
/// Ivory canvas. Back button top-left. Eyebrow / Marcellus title /
/// Albert Sans body. Five stacked floating-label fields (full name,
/// email, phone with 🇳🇬 +234 prefix, password with eye toggle,
/// referral code optional). Sticky bottom: coral "Continue" CTA +
/// terms micro-copy with linked words underlined.
///
/// Doubles as the COMPLETE-PROFILE screen: when a signed-in driver has
/// an auth record but no `profiles` row (a signup that died between OTP
/// and the profile insert), bootstrap routes them here. In that mode the
/// copy switches to "Finish setting up", known details are prefilled
/// from auth metadata, the password field is hidden (they're already
/// authenticated), and Continue writes the profile directly — running
/// auth.signUp again would only throw "already registered".
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
  bool _completingProfile = false;
  bool _waitlistPrefillDone = false;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _password = TextEditingController();
    _referral = TextEditingController();

    // Repair mode: a live session means the auth account already exists
    // and only the profile rows are missing. Prefill what signup stored
    // in auth metadata so the driver just confirms and continues.
    final User? user = locator<SupabaseModule>().auth.currentUser;
    if (user != null) {
      _completingProfile = true;
      final Map<String, dynamic> meta = user.userMetadata ?? const {};

      final String fullName = (meta['full_name'] as String?)?.trim() ?? '';
      // Auth metadata's `email` may just echo the synthetic phone email —
      // only prefill a real address.
      final String rawEmail = (meta['email'] as String?)?.trim() ?? '';
      final String email =
          rawEmail.endsWith('@drivio.internal') ? '' : rawEmail;
      final String phone = (meta['phone'] as String?)?.trim() ?? '';
      // "+2347019703700" → "7019703700" for the +234-prefixed field.
      final String national = phone
          .replaceFirst(RegExp(r'^\+?234'), '')
          .replaceAll(RegExp(r'\D'), '');

      if (fullName.isNotEmpty) _fullName.text = fullName;
      if (email.isNotEmpty) _email.text = email;
      if (national.isNotEmpty) _phone.text = national;

      // Riverpod forbids provider writes during the first build — push the
      // controller-state prefill to after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final SignUpController c =
            ref.read(signUpControllerProvider.notifier);
        if (fullName.isNotEmpty) c.onFullNameChanged(fullName);
        if (email.isNotEmpty) c.onEmailChanged(email);
        if (national.isNotEmpty) c.onPhoneChanged(national);
      });
    }
  }

  /// Waitlist prefill: the lookup page hands over the details it found
  /// so the form arrives already filled in (all still editable). Route
  /// arguments aren't readable in initState, so this runs from the
  /// first didChangeDependencies, exactly once.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_waitlistPrefillDone || _completingProfile) return;
    final Object? args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map || args['fromWaitlist'] != 'true') return;
    _waitlistPrefillDone = true;

    final String name = (args['prefillName'] as String?)?.trim() ?? '';
    final String email = (args['prefillEmail'] as String?)?.trim() ?? '';
    final String digits =
        ((args['prefillPhone'] as String?) ?? '').replaceAll(RegExp(r'\D'), '');
    final String national = digits
        .replaceFirst(RegExp(r'^234'), '')
        .replaceFirst(RegExp(r'^0'), '');

    if (name.isNotEmpty) _fullName.text = name;
    if (email.isNotEmpty) _email.text = email;
    if (national.isNotEmpty) _phone.text = national;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final SignUpController c = ref.read(signUpControllerProvider.notifier);
      if (name.isNotEmpty) c.onFullNameChanged(name);
      if (email.isNotEmpty) c.onEmailChanged(email);
      if (national.isNotEmpty) c.onPhoneChanged(national);
    });
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

  /// Escape hatch from repair mode: abandon the half-created account's
  /// session and start a clean sign-up. Signing out first matters —
  /// with a live session the sign-up page would just flip back into
  /// "Finish setting up".
  Future<void> _onStartOver() async {
    try {
      await locator<SupabaseModule>().auth.signOut();
    } catch (_) {
      // Even a failed network sign-out clears the local session.
    }
    // SessionGuard reacts to signedOut by routing to Welcome; let that
    // land first, then put the fresh sign-up form on top of it.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    AppNavigation.replaceAll<void>(AppRoutes.welcome);
    AppNavigation.push<void>(AppRoutes.signUp);
  }

  Future<void> _onContinue() async {
    final SignUpController c = ref.read(signUpControllerProvider.notifier);

    if (_completingProfile) {
      // Already authenticated — write the missing profile rows directly.
      final bool created = await c.submitProfile();
      if (created && mounted) {
        // Navigate first — reset only after the transition has covered
        // this screen, so the button never flashes back to idle.
        AppNavigation.replaceAll<void>(AppRoutes.home);
        Future<void>.delayed(const Duration(milliseconds: 800), c.reset);
      }
      return;
    }

    final bool success = await c.requestOtp();
    if (success && mounted) {
      final String phone = ref.read(signUpControllerProvider).normalizedPhone;
      // Navigate FIRST; the button only leaves its loading state once the
      // OTP page is gone again (back), never mid-transition.
      await AppNavigation.push<void>(AppRoutes.otp, arguments: <String, String>{
        'phone': phone,
        'mode': 'signUp',
      });
      if (mounted) c.endLoading();
    }
  }

  @override
  Widget build(BuildContext context) {
    final SignUpState state = ref.watch(signUpControllerProvider);
    final SignUpController c = ref.read(signUpControllerProvider.notifier);
    // From the waitlist lookup page (prefill map) — or the legacy
    // `arguments: true` form, kept for compatibility.
    final Object? routeArgs = ModalRoute.of(context)?.settings.arguments;
    final bool fromWaitlist = routeArgs == true ||
        (routeArgs is Map && routeArgs['fromWaitlist'] == 'true');

    // Repair mode needs no password — the account already has one.
    final bool canSubmit = _completingProfile
        ? state.fullName.trim().length >= 2 &&
            state.phone.replaceAll(RegExp(r'\s'), '').length >= 10 &&
            state.hasValidEmail
        : state.canSubmit;

    return ScreenScaffold(
      bottomBar: _BottomBar(
        canSubmit: canSubmit && !state.isLoading,
        isLoading: state.isLoading,
        completingProfile: _completingProfile,
        onPressed: _onContinue,
        onStartOver: _onStartOver,
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
              _completingProfile ? 'ONE LAST STEP' : 'STEP 1 OF 2',
              style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 14),

            // Marcellus screen title.
            Text(
              _completingProfile
                  ? 'Finish setting up'
                  : 'Create your account',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),

            // Albert Sans dim body.
            Text(
              _completingProfile
                  ? "Your account exists but your profile didn't finish "
                      "saving. Confirm your details and you're in."
                  : 'Phone, then a few quick details.',
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),

            if (fromWaitlist) ...<Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.10),
                  borderRadius: AppRadius.base,
                  border: Border.all(
                    color: context.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'We pulled in your waitlist details — check them, '
                  "set a password, and you're in.",
                  style: AppTextStyles.captionSm.copyWith(
                    color: context.text,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

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
            if (!_completingProfile) ...<Widget>[
              const SizedBox(height: 14),
              DrivioInput(
                label: 'Password',
                obscure: !_showPassword,
                controller: _password,
                onChanged: c.onPasswordChanged,
                suffix: _PasswordEyeToggle(
                  visible: _showPassword,
                  onTap: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
            ],
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
/// underlined "Terms" and "Privacy Policy" per SCR-003 mockup. The
/// linked words open the live legal pages in an in-app browser tab.
class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.canSubmit,
    required this.isLoading,
    required this.completingProfile,
    required this.onPressed,
    required this.onStartOver,
  });

  final bool canSubmit;
  final bool isLoading;
  final bool completingProfile;
  final VoidCallback onPressed;
  final VoidCallback onStartOver;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => LegalLinks.openTerms(context);
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => LegalLinks.openPrivacy(context);
  // Replace (not push) so Sign In doesn't stack on top of Sign Up.
  late final TapGestureRecognizer _signInTap = TapGestureRecognizer()
    ..onTap = () => AppNavigation.replace<void, void>(AppRoutes.signIn);

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    _signInTap.dispose();
    super.dispose();
  }

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
              label: widget.completingProfile
                  ? (widget.isLoading ? 'Saving…' : 'Finish setup')
                  : (widget.isLoading ? 'Sending code…' : 'Continue'),
              disabled: !widget.canSubmit,
              onPressed: widget.canSubmit ? widget.onPressed : null,
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
                      recognizer: _termsTap,
                      style: AppTextStyles.captionSm.copyWith(
                        color: context.text,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      recognizer: _privacyTap,
                      style: AppTextStyles.captionSm.copyWith(
                        color: context.text,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (widget.completingProfile)
              // Repair mode's way out: ditch the half-created account
              // and restart sign-up from scratch.
              Center(
                child: GestureDetector(
                  onTap: widget.onStartOver,
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.textDim,
                      ),
                      children: <InlineSpan>[
                        const TextSpan(text: 'Wrong details? '),
                        TextSpan(
                          text: 'Sign up again',
                          style: AppTextStyles.bodySm.copyWith(
                            color: context.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Center(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodySm.copyWith(
                      color: context.textDim,
                    ),
                    children: <InlineSpan>[
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign in',
                        recognizer: _signInTap,
                        style: AppTextStyles.bodySm.copyWith(
                          color: context.accent,
                          fontWeight: FontWeight.w600,
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
