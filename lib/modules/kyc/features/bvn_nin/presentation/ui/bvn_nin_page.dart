import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/kyc/features/bvn_nin/presentation/logic/controller/bvn_nin_controller.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';

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
    final BvnNinState state = ref.watch(bvnNinControllerProvider);
    final BvnNinController c = ref.read(bvnNinControllerProvider.notifier);

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
              'We use NIBSS / NIMC to confirm your details. Your number is never shown to riders.',
              style: AppTextStyles.bodySm.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 22),
            _KindToggle(
              kind: state.kind,
              onChanged: c.setKind,
            ),
            const SizedBox(height: 14),
            DrivioInput(
              label: state.kind == BvnNinKind.bvn ? 'BVN' : 'NIN',
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

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.kind, required this.onChanged});

  final BvnNinKind kind;
  final ValueChanged<BvnNinKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: context.borderStrong),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _seg(
              context,
              label: 'BVN',
              selected: kind == BvnNinKind.bvn,
              onTap: () => onChanged(BvnNinKind.bvn),
            ),
          ),
          Expanded(
            child: _seg(
              context,
              label: 'NIN',
              selected: kind == BvnNinKind.nin,
              onTap: () => onChanged(BvnNinKind.nin),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context,
      {required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? context.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? context.bg : context.text,
          ),
        ),
      ),
    );
  }
}
