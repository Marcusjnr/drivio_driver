import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/forgot_password/presentation/logic/controller/forgot_password_controller.dart';
import 'package:drivio_driver/modules/authentication/features/forgot_password/presentation/ui/widgets/reset_error_row.dart';
import 'package:drivio_driver/modules/commons/all.dart';

/// Step 3 of 3 — the new password.
class ForgotPasswordNewPage extends ConsumerStatefulWidget {
  const ForgotPasswordNewPage({super.key});

  @override
  ConsumerState<ForgotPasswordNewPage> createState() =>
      _ForgotPasswordNewPageState();
}

class _ForgotPasswordNewPageState
    extends ConsumerState<ForgotPasswordNewPage> {
  late final TextEditingController _password;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final ForgotPasswordController c =
        ref.read(forgotPasswordControllerProvider.notifier);
    final bool ok = await c.submitPassword();
    if (!ok || !mounted) return;

    // Straight back to sign in, with the whole reset stack cleared so
    // Back cannot land on a spent code screen.
    AppNavigation.replaceAll<void>(AppRoutes.signIn);
    AppNotifier.success(
      message: 'Password changed. Sign in with your new one.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ForgotPasswordState state =
        ref.watch(forgotPasswordControllerProvider);
    final ForgotPasswordController c =
        ref.read(forgotPasswordControllerProvider.notifier);

    return ScreenScaffold(
      bottomBar: _BottomBar(
        label: state.isBusy ? 'Saving…' : 'Save password',
        enabled: state.canSubmitPassword,
        onPressed: _onSave,
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
            const SizedBox(height: 40),

            Text(
              'Set a new password',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Use at least 8 characters. You will sign in with this from '
              'now on, and any other phone signed in as you gets signed out.',
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            DrivioInput(
              label: 'New password',
              obscure: !_show,
              controller: _password,
              onChanged: c.onPasswordChanged,
              suffix: GestureDetector(
                onTap: () => setState(() => _show = !_show),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _show
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: context.textDim,
                  ),
                ),
              ),
            ),

            if (state.error != null) ...<Widget>[
              const SizedBox(height: 16),
              ResetErrorRow(message: state.error!),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: BoxDecoration(color: context.bg),
      child: SafeArea(
        top: false,
        child: DrivioButton(
          label: label,
          disabled: !enabled,
          onPressed: enabled ? onPressed : null,
        ),
      ),
    );
  }
}
