import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/withdrawal_repository.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/profile/features/payment_methods/presentation/logic/controller/payout_account_controller.dart';
import 'package:drivio_driver/modules/profile/features/payment_methods/presentation/ui/payout_account_sheet.dart';

/// Full-screen "add + verify your payout bank account" step. Pops `true` once
/// the account is verified, so the caller (the withdraw flow) can continue to
/// the withdraw screen.
class AddPayoutAccountPage extends ConsumerStatefulWidget {
  const AddPayoutAccountPage({super.key});

  @override
  ConsumerState<AddPayoutAccountPage> createState() =>
      _AddPayoutAccountPageState();
}

class _AddPayoutAccountPageState extends ConsumerState<AddPayoutAccountPage> {
  final TextEditingController _acct = TextEditingController();

  List<PaystackBank> _banks = const <PaystackBank>[];
  PaystackBank? _bank;
  bool _banksLoading = true;
  bool _banksError = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  @override
  void dispose() {
    _acct.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    setState(() {
      _banksLoading = true;
      _banksError = false;
    });
    try {
      final List<PaystackBank> banks =
          await ref.read(payoutAccountControllerProvider.notifier).loadBanks();
      if (!mounted) return;
      setState(() {
        _banks = banks;
        _banksLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _banksLoading = false;
        _banksError = true;
      });
    }
  }

  Future<void> _verify() async {
    if (_bank == null) {
      setState(() => _error = 'Please pick your bank.');
      return;
    }
    if (!RegExp(r'^\d{10}$').hasMatch(_acct.text.trim())) {
      setState(() => _error = 'Account number must be 10 digits (NUBAN format).');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final String? name = await ref
        .read(payoutAccountControllerProvider.notifier)
        .saveAccount(
          bankName: _bank!.name,
          bankCode: _bank!.code,
          accountNumber: _acct.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (name == null) {
      setState(() => _error =
          ref.read(payoutAccountControllerProvider).error ??
              "Couldn't verify that account. Check the details and try again.");
    } else {
      AppNotifier.success(message: 'Bank account verified — $name.');
      // Replace this page with the withdraw screen so a later back press goes
      // to the profile, not back to the add-account step.
      AppNavigation.replace<Object?, Object?>(AppRoutes.withdraw);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Add bank account',
      subtitle: 'Where your withdrawals go',
      children: <Widget>[
        Text(
          "Pick your bank and enter your account number — we'll confirm the "
          'account name with your bank before you can withdraw.',
          style: AppTextStyles.body.copyWith(color: context.textDim, height: 1.5),
        ),
        const SizedBox(height: 18),
        PayoutBankPicker(
          banks: _banks,
          selected: _bank,
          loading: _banksLoading,
          hasError: _banksError,
          onRetry: _loadBanks,
          onChanged: (PaystackBank? b) => setState(() => _bank = b),
        ),
        const SizedBox(height: 12),
        DrivioInput(
          label: 'Account number',
          hint: '10-digit NUBAN',
          controller: _acct,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(fontSize: 12, color: context.red)),
        ],
        const SizedBox(height: 20),
        DrivioButton(
          label: _saving ? 'Verifying…' : 'Verify & continue',
          loading: _saving,
          disabled: _banksLoading || _banksError,
          onPressed: _verify,
        ),
      ],
    );
  }
}
