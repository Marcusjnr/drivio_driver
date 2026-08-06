import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/authentication/features/forgot_password/presentation/logic/controller/forgot_password_controller.dart';
import 'package:drivio_driver/modules/authentication/features/forgot_password/presentation/ui/widgets/reset_error_row.dart';
import 'package:drivio_driver/modules/commons/all.dart';

/// Step 1 of 3 — the number to send the code to.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _onNext() async {
    final ForgotPasswordController c =
        ref.read(forgotPasswordControllerProvider.notifier);
    final bool ok = await c.submitPhone();
    if (ok && mounted) {
      await AppNavigation.push<void>(AppRoutes.forgotPasswordCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ForgotPasswordState state =
        ref.watch(forgotPasswordControllerProvider);
    final ForgotPasswordController c =
        ref.read(forgotPasswordControllerProvider.notifier);

    return ScreenScaffold(
      bottomBar: _BottomBar(
        label: state.isBusy ? 'Sending code…' : 'Next',
        enabled: state.canSubmitPhone,
        onPressed: _onNext,
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
              'Reset your password',
              style: AppTextStyles.screenTitle.copyWith(color: context.text),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the phone number you drive with. We will text you a '
              'code to confirm it is you.',
              style: AppTextStyles.bodySm.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            PhoneNumberInput(
              controller: _phone,
              onChanged: c.onPhoneChanged,
              autofocus: true,
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
