import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

/// "Joined the waitlist?" entry point — asks for ONLY the phone number,
/// looks the signup up on the waitlist, and opens the account form with
/// their name/email already filled in (still editable). A number that
/// isn't on the waitlist gets a friendly error plus a path into the
/// regular fresh sign-up.
class WaitlistLookupPage extends ConsumerStatefulWidget {
  const WaitlistLookupPage({super.key});

  @override
  ConsumerState<WaitlistLookupPage> createState() =>
      _WaitlistLookupPageState();
}

class _WaitlistLookupPageState extends ConsumerState<WaitlistLookupPage> {
  final TextEditingController _phone = TextEditingController();
  bool _isLooking = false;
  bool _notFound = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');
  bool get _canSubmit => _digits.length >= 10 && !_isLooking;

  Future<void> _onContinue() async {
    setState(() {
      _isLooking = true;
      _notFound = false;
      _error = null;
    });
    try {
      final dynamic res = await locator<SupabaseModule>().client.rpc<dynamic>(
        'get_waitlist_prefill',
        params: <String, dynamic>{'p_phone': _digits},
      );
      if (!mounted) return;
      final List<dynamic> rows = res is List ? res : const <dynamic>[];
      if (rows.isEmpty) {
        setState(() {
          _isLooking = false;
          _notFound = true;
        });
        return;
      }
      final Map<String, dynamic> row =
          (rows.first as Map).cast<String, dynamic>();
      // Hand the prefill to the sign-up form. Stay "loading" through the
      // push; reset once the form screen has taken over.
      await AppNavigation.push<void>(
        AppRoutes.signUp,
        arguments: <String, String>{
          'fromWaitlist': 'true',
          'prefillName': (row['full_name'] as String?)?.trim() ?? '',
          'prefillEmail': (row['email'] as String?)?.trim() ?? '',
          'prefillPhone': _digits,
        },
      );
      if (mounted) setState(() => _isLooking = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLooking = false;
        _error = "Couldn't check the waitlist. Try again in a moment.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      bottomBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
        decoration: BoxDecoration(color: context.bg),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DrivioButton(
                label: _isLooking ? 'Checking…' : 'Continue',
                disabled: !_canSubmit,
                onPressed: _canSubmit ? _onContinue : null,
              ),
              const SizedBox(height: 12),
              // Always-available exit to the regular flow — not only
              // after a failed lookup.
              Center(
                child: GestureDetector(
                  onTap: () =>
                      AppNavigation.replace<void, void>(AppRoutes.signUp),
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.textDim,
                      ),
                      children: <InlineSpan>[
                        const TextSpan(text: 'Not on the waitlist? '),
                        TextSpan(
                          text: 'Sign up',
                          style: AppTextStyles.bodySm.copyWith(
                            color: context.accent,
                            fontWeight: FontWeight.w600,
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
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'WAITLIST',
              style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 14),
            Text(
              'Welcome back',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the phone number you joined the waitlist with and '
              "we'll pull up your details.",
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            PhoneNumberInput(
              controller: _phone,
              autofocus: true,
              onChanged: (_) => setState(() {
                _notFound = false;
                _error = null;
              }),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.red.withValues(alpha: 0.10),
                  borderRadius: AppRadius.md,
                  border:
                      Border.all(color: context.red.withValues(alpha: 0.30)),
                ),
                child: Text(
                  _error!,
                  style: AppTextStyles.bodySm.copyWith(
                    color: context.red,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (_notFound) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.10),
                  borderRadius: AppRadius.base,
                  border: Border.all(
                    color: context.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "We couldn't find that number on the waitlist.",
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Double-check the number, or create a fresh '
                      'account, it only takes a minute.',
                      style: AppTextStyles.captionSm.copyWith(
                        color: context.textDim,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () =>
                          AppNavigation.replace<void, void>(AppRoutes.signUp),
                      child: Text(
                        'Sign up without the waitlist →',
                        style: AppTextStyles.bodySm.copyWith(
                          color: context.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
