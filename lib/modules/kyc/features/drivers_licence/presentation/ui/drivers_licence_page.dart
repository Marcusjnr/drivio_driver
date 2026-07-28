import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/kyc/features/drivers_licence/presentation/logic/controller/drivers_licence_controller.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';

/// Driver's-licence entry — verified against FRSC via YouVerify, never by
/// an admin. Replaces the old licence photo upload.
class DriversLicencePage extends ConsumerStatefulWidget {
  const DriversLicencePage({super.key});

  @override
  ConsumerState<DriversLicencePage> createState() =>
      _DriversLicencePageState();
}

class _DriversLicencePageState extends ConsumerState<DriversLicencePage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LicenceState state = ref.watch(licenceControllerProvider);
    final LicenceController c = ref.read(licenceControllerProvider.notifier);

    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BackButtonBox(onTap: () => AppNavigation.pop()),
            const SizedBox(height: 18),
            Text(
              'Verify your\nlicence.',
              style: AppTextStyles.h1.copyWith(color: context.text),
            ),
            const SizedBox(height: 6),
            Text(
              "Enter your driver's licence number.",
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 22),
            DrivioInput(
              label: "Driver's licence number",
              hint: 'e.g. FKJ49206AA2',
              controller: _controller,
              onChanged: c.setValue,
              compact: true,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(15),
                _UpperCaseFormatter(),
              ],
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                state.error!,
                style: AppTextStyles.bodySm.copyWith(color: context.red),
              ),
            ],
            const SizedBox(height: 22),
            DrivioButton(
              label: state.isVerifying ? 'Verifying…' : 'Verify',
              disabled: !state.hasValidNumber || state.isVerifying,
              onPressed: () async {
                final bool ok = await c.verify();
                if (!mounted || !ok) return;
                await ref.read(kycControllerProvider.notifier).refresh();
                if (!mounted) return;
                AppNavigation.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Force licence input to uppercase as the driver types.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
