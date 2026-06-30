import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/withdrawal_repository.dart';
import 'package:drivio_driver/modules/commons/utils/withdrawal_fee.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/profile/features/withdraw/presentation/logic/controller/withdraw_controller.dart';

/// Driver withdrawal screen. Shows the withdrawable (wallet) balance, an
/// amount field (min ₦1,000), a live Amount / Service fee / Total
/// breakdown, and a Withdraw button → `driver-withdraw`. Until a payout
/// recipient exists, prompts the driver to add a bank account first.
class WithdrawPage extends ConsumerStatefulWidget {
  const WithdrawPage({super.key});

  @override
  ConsumerState<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends ConsumerState<WithdrawPage> {
  final TextEditingController _amount = TextEditingController();
  bool _redirectedToBank = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _onAmountChanged(String raw) {
    final int naira = int.tryParse(raw.trim()) ?? 0;
    ref.read(withdrawControllerProvider.notifier).setAmountNaira(naira);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final bool ok = await ref.read(withdrawControllerProvider.notifier).submit();
    if (!mounted) return;
    if (!ok) {
      final String? err = ref.read(withdrawControllerProvider).error;
      AppNotifier.error(
        message: err ?? "Couldn't start that withdrawal. Please try again.",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final WithdrawState state = ref.watch(withdrawControllerProvider);

    // Success — show the "processing" confirmation instead of the form.
    if (state.successResult != null) {
      return _ProcessingConfirmation(result: state.successResult!);
    }

    // No bank account yet → REPLACE this screen with the add + verify page,
    // so a back press there returns to the profile (not an empty withdraw
    // page). That page replaces itself back to a fresh withdraw screen on
    // success.
    if (!state.isLoading && !state.hasPayoutAccount && !_redirectedToBank) {
      _redirectedToBank = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppNavigation.replace<Object?, Object?>(AppRoutes.addBankAccount);
        }
      });
    }

    return DetailScaffold(
      title: 'Withdraw',
      subtitle: 'To your bank account',
      children: <Widget>[
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!state.hasPayoutAccount)
          // Redirecting to the add-bank page — a brief spinner, not a prompt.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...<Widget>[
          _BalanceCard(balanceMinor: state.balanceMinor),
          if (state.account != null) ...<Widget>[
            const SizedBox(height: 12),
            _PayoutAccountRow(
              label: state.account!.displayLabel,
              accountName: state.account!.accountName,
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'AMOUNT TO WITHDRAW',
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
          ),
          const SizedBox(height: 8),
          DrivioInput(
            label: 'Amount (₦)',
            hint: 'e.g. 5000',
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            onChanged: _onAmountChanged,
            errorText: state.amountHint,
          ),
          const SizedBox(height: 6),
          Text(
            "You'll receive this amount. The service fee is added on top.",
            style: AppTextStyles.captionSm.copyWith(color: context.textDim),
          ),
          const SizedBox(height: 20),
          _Breakdown(state: state),
          const SizedBox(height: 24),
          DrivioButton(
            label: state.isSubmitting ? 'Processing…' : 'Withdraw',
            disabled: !state.canSubmit,
            loading: state.isSubmitting,
            onPressed: state.canSubmit ? _submit : null,
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              state.error!,
              style: AppTextStyles.bodySm.copyWith(color: context.red),
            ),
          ],
        ],
      ],
    );
  }
}

// ── Balance card ───────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balanceMinor});
  final int balanceMinor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            context.coral.withValues(alpha: 0.18),
            context.coral.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: AppRadius.lg,
        border: Border.all(color: context.coral.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'AVAILABLE TO WITHDRAW',
            style: AppTextStyles.eyebrow.copyWith(color: context.coral),
          ),
          const SizedBox(height: 4),
          Text(
            NairaFormatter.format(balanceMinor ~/ 100),
            style: AppTextStyles.priceHero.copyWith(
              fontSize: 38,
              letterSpacing: -1.2,
              color: context.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fee breakdown ──────────────────────────────────────────────────────

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.state});
  final WithdrawState state;

  @override
  Widget build(BuildContext context) {
    final int amount = state.amountMinor;
    final int fee = amount == 0 ? 0 : WithdrawalFee.feeMinorFor(amount);
    final int total = amount == 0 ? 0 : WithdrawalFee.totalMinorFor(amount);
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: <Widget>[
          _row(context, 'Amount', amount),
          const SizedBox(height: 8),
          _row(context, 'Service fee', fee),
          const SizedBox(height: 10),
          Divider(height: 1, color: context.border),
          const SizedBox(height: 10),
          _row(context, 'Total', total, emphasized: true),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    int minor, {
    bool emphasized = false,
  }) {
    final TextStyle labelStyle = emphasized
        ? AppTextStyles.bodySm
            .copyWith(color: context.text, fontWeight: FontWeight.w700)
        : AppTextStyles.bodySm.copyWith(color: context.textDim);
    final TextStyle valueStyle = emphasized
        ? AppTextStyles.bodySm
            .copyWith(color: context.text, fontWeight: FontWeight.w700)
        : AppTextStyles.bodySm
            .copyWith(color: context.text, fontWeight: FontWeight.w600);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: labelStyle),
        Text(NairaFormatter.format(minor ~/ 100), style: valueStyle),
      ],
    );
  }
}

// ── Saved payout account ───────────────────────────────────────────────

class _PayoutAccountRow extends StatelessWidget {
  const _PayoutAccountRow({required this.label, required this.accountName});
  final String label;
  final String accountName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🏦', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'WITHDRAWING TO',
                  style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.bodySm.copyWith(
                    color: context.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  accountName,
                  style: AppTextStyles.captionSm
                      .copyWith(fontSize: 11, color: context.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Processing confirmation ────────────────────────────────────────────

class _ProcessingConfirmation extends StatelessWidget {
  const _ProcessingConfirmation({required this.result});
  final WithdrawalResult result;

  @override
  Widget build(BuildContext context) {
    final int amountMinor = result.amountMinor;
    return DetailScaffold(
      title: 'Withdrawal',
      subtitle: 'Processing',
      children: <Widget>[
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.coral.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 38, color: context.coral),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Withdrawal is processing',
          textAlign: TextAlign.center,
          style: AppTextStyles.h2.copyWith(color: context.text),
        ),
        const SizedBox(height: 8),
        Text(
          "${NairaFormatter.format(amountMinor ~/ 100)} is on its way to your bank. "
          'Transfers usually arrive within a few minutes.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            color: context.textDim,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        DrivioButton(
          label: 'Done',
          onPressed: () => AppNavigation.pop(),
        ),
      ],
    );
  }
}
