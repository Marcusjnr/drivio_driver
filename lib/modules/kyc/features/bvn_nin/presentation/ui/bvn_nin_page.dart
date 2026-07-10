import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/kyc/features/bvn_nin/presentation/logic/controller/bvn_nin_controller.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';

/// NIN entry — the identity step of KYC. NIN-only (no BVN); verification
/// is handled by the NIMC lookup service, never by an admin.
class BvnNinPage extends ConsumerStatefulWidget {
  const BvnNinPage({super.key});

  @override
  ConsumerState<BvnNinPage> createState() => _BvnNinPageState();
}

class _BvnNinPageState extends ConsumerState<BvnNinPage> {
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
    final NinState state = ref.watch(ninControllerProvider);
    final NinController c = ref.read(ninControllerProvider.notifier);

    return ScreenScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            BackButtonBox(onTap: () => AppNavigation.pop()),
            const SizedBox(height: 18),
            Text(
              'Verify your\nidentity.',
              style: AppTextStyles.h1.copyWith(color: context.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your NIN. We confirm it with NIMC — it never appears '
              'on your profile.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 22),
            DrivioInput(
              label: 'NIN',
              hint: '11-digit number',
              keyboardType: TextInputType.number,
              controller: _controller,
              onChanged: c.setValue,
              compact: true,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
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
