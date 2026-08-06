import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/forgot_password/presentation/logic/controller/forgot_password_controller.dart';
import 'package:drivio_driver/modules/authentication/features/forgot_password/presentation/ui/widgets/reset_error_row.dart';
import 'package:drivio_driver/modules/commons/all.dart';

/// Step 2 of 3 — the six digit code.
class ForgotPasswordCodePage extends ConsumerWidget {
  const ForgotPasswordCodePage({super.key});

  Future<void> _onVerify(BuildContext context, WidgetRef ref) async {
    final ForgotPasswordController c =
        ref.read(forgotPasswordControllerProvider.notifier);
    final bool ok = await c.submitCode();
    if (ok && context.mounted) {
      await AppNavigation.push<void>(AppRoutes.forgotPasswordNew);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ForgotPasswordState state =
        ref.watch(forgotPasswordControllerProvider);
    final ForgotPasswordController c =
        ref.read(forgotPasswordControllerProvider.notifier);

    return ScreenScaffold(
      bottomBar: _BottomBar(
        label: state.isBusy ? 'Checking…' : 'Continue',
        enabled: state.canSubmitCode,
        onPressed: () => _onVerify(context, ref),
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
              'Enter the code',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a six digit code to ${state.displayPhone}. It is '
              'good for the next 10 minutes.',
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            PinInput(
              length: 6,
              initial: state.code,
              onChanged: c.onCodeChanged,
            ),

            if (state.error != null) ...<Widget>[
              const SizedBox(height: 14),
              ResetErrorRow(message: state.error!),
            ],

            const SizedBox(height: 18),
            Center(
              child: GestureDetector(
                onTap: state.canResend ? c.resend : null,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    state.canResend
                        ? 'Send a new code'
                        : 'Send a new code (${state.resendSeconds}s)',
                    style: AppTextStyles.bodySm.copyWith(
                      color:
                          state.canResend ? context.coral : context.textDim,
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
