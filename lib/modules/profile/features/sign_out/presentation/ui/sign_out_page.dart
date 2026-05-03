import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/profile_repository.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/dash/features/home/presentation/logic/controller/home_controller.dart';

class SignOutPage extends ConsumerStatefulWidget {
  const SignOutPage({super.key});

  @override
  ConsumerState<SignOutPage> createState() => _SignOutPageState();
}

class _SignOutPageState extends ConsumerState<SignOutPage> {
  bool _isLoading = false;
  bool _isDeleting = false;

  Future<void> _handleSignOut() async {
    final HomeState home = ref.read(homeControllerProvider);
    if (home.isOnline || home.isOnTrip) {
      _showCannotSignOutSheet();
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(mutationQueueProvider.notifier).clearAll();
      await locator<SupabaseModule>().auth.signOut();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCannotSignOutSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Can't sign out right now",
                style: AppTextStyles.h2.copyWith(color: ctx.text),
              ),
              const SizedBox(height: 10),
              Text(
                'You need to go offline and finish any active trips before signing out.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: ctx.textDim,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
              DrivioButton(
                label: 'Got it',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Two-step confirm: bottom sheet asks the user to type DELETE before
  /// the destructive RPC fires. Server (`request_account_deletion`)
  /// refuses if there's an active trip — surface that as a friendly
  /// message rather than a raw error.
  Future<void> _handleDeleteAccount() async {
    final HomeState home = ref.read(homeControllerProvider);
    if (home.isOnline || home.isOnTrip) {
      _showCannotSignOutSheet();
      return;
    }

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => const _ConfirmDeleteSheet(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await locator<ProfileRepository>().requestAccountDeletion();
      // Clear queued mutations & sign out so the auth listener routes the
      // user back to the welcome page.
      await ref.read(mutationQueueProvider.notifier).clearAll();
      await locator<SupabaseModule>().auth.signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      final String msg = e.toString();
      final String friendly = msg.contains('active_trip_in_progress')
          ? "Finish your current trip before deleting your account."
          : "Could not delete your account. Please try again.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _isLoading || _isDeleting;
    return DetailScaffold(
      title: 'Sign out',
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 30, 10, 20),
          child: Column(
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.amber.withValues(alpha: 0.14),
                  border: Border.all(color: context.amber.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Text('\u{1F44B}', style: TextStyle(fontSize: 32)),
              ),
              const SizedBox(height: 18),
              Text(
                'Sign out of Drivio?',
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(color: context.text),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 280,
                child: Text(
                  "You'll go offline immediately and won't receive any new ride requests until you sign in again.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: context.textDim,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
        const DetailGroup(
          title: 'BEFORE YOU GO',
          topMargin: 0,
          children: <Widget>[
            FieldRow(label: "Today's earnings", value: '₦18,400 · paying out tonight'),
            FieldRow(label: 'Trips this week', value: '27'),
            FieldRow(label: 'Subscription', value: 'Active · 18 days left', divider: false),
          ],
        ),
        const SizedBox(height: 20),
        DrivioButton(
          label: _isLoading ? 'Signing out…' : 'Yes, sign me out',
          variant: DrivioButtonVariant.danger,
          disabled: busy,
          onPressed: busy ? null : _handleSignOut,
        ),
        const SizedBox(height: 8),
        DrivioButton(
          label: 'Stay signed in',
          variant: DrivioButtonVariant.ghost,
          disabled: busy,
          onPressed: busy ? null : () => AppNavigation.pop(),
        ),
        const SizedBox(height: 24),
        // Destructive: separated visually from the safe sign-out flow.
        DetailGroup(
          title: 'DANGER ZONE',
          children: <Widget>[
            InkWell(
              onTap: busy ? null : _handleDeleteAccount,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _isDeleting
                                ? 'Deleting account…'
                                : 'Delete my account',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Permanently removes your profile, vehicles, and history.',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textDim,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isDeleting)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.red,
                        ),
                      )
                    else
                      Icon(DrivioIcons.chevron,
                          size: 14, color: context.red),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Two-step "type DELETE" guard for account removal. Returns `true` only
/// once the user types the literal token + taps Confirm — typo-resistant
/// without needing a separate route.
class _ConfirmDeleteSheet extends StatefulWidget {
  const _ConfirmDeleteSheet();

  @override
  State<_ConfirmDeleteSheet> createState() => _ConfirmDeleteSheetState();
}

class _ConfirmDeleteSheetState extends State<_ConfirmDeleteSheet> {
  static const String _token = 'DELETE';
  final TextEditingController _input = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final bool ok = _input.text.trim().toUpperCase() == _token;
      if (ok != _matches) {
        setState(() => _matches = ok);
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Delete your Drivio account?',
              style: AppTextStyles.h2.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            Text(
              "This is permanent. We will remove your profile, vehicles, "
              "and trip history. You won't be able to recover them.",
              style: AppTextStyles.caption.copyWith(
                color: context.textDim,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.red.withValues(alpha: 0.06),
                borderRadius: AppRadius.sm,
                border: Border.all(color: context.red.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: <Widget>[
                  const Text('⚠️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Any active or unpaid trip must be settled first.",
                      style: TextStyle(
                          fontSize: 12, color: context.red, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DrivioInput(
              label: 'Type DELETE to confirm',
              hint: 'DELETE',
              controller: _input,
              autofocus: true,
            ),
            const SizedBox(height: 18),
            DrivioButton(
              label: 'Delete my account',
              variant: DrivioButtonVariant.danger,
              disabled: !_matches,
              onPressed:
                  _matches ? () => Navigator.of(context).pop(true) : null,
            ),
            const SizedBox(height: 8),
            DrivioButton(
              label: 'Cancel',
              variant: DrivioButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
