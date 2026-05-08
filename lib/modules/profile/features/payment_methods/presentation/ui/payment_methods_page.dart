import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/payout_account.dart';
import 'package:drivio_driver/modules/commons/types/wallet.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/profile/features/payment_methods/presentation/logic/controller/payout_account_controller.dart';

/// Per Q2: cards-on-file are removed (we can't securely store cards
/// in v1). The page now manages a single payout bank account and
/// shows subscription billing history derived from
/// `wallet_ledger.subscription_debit` entries.
class PaymentMethodsPage extends ConsumerWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PayoutAccountState state =
        ref.watch(payoutAccountControllerProvider);
    final PayoutAccountController c =
        ref.read(payoutAccountControllerProvider.notifier);

    return DetailScaffold(
      title: 'Manage payment',
      subtitle: 'Payouts & billing',
      children: <Widget>[
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...<Widget>[
          Text(
            'PAYOUT ACCOUNT',
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
          ),
          const SizedBox(height: 8),
          if (state.account == null)
            _NoAccountCard(
              onAdd: () => _openSheet(context, ref, existing: null),
            )
          else
            _AccountCard(
              account: state.account!,
              onEdit: () => _openSheet(context, ref, existing: state.account),
              onRemove: () => _confirmRemove(context, c),
            ),
          const SizedBox(height: 24),
          Text(
            'BILLING HISTORY',
            style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
          ),
          const SizedBox(height: 8),
          _BillingHistory(charges: state.subscriptionCharges),
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

  Future<void> _openSheet(
    BuildContext context,
    WidgetRef ref, {
    required PayoutAccount? existing,
  }) async {
    final _PayoutDraft? draft = await showModalBottomSheet<_PayoutDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _PayoutSheet(existing: existing),
    );
    if (draft == null) return;
    final bool ok = await ref
        .read(payoutAccountControllerProvider.notifier)
        .saveAccount(
          bankName: draft.bankName,
          accountNumber: draft.accountNumber,
          accountName: draft.accountName,
        );
    if (!ok) {
      final String? err =
          ref.read(payoutAccountControllerProvider).error;
      AppNotifier.error(message: err ?? 'Could not save bank details.');
    } else {
      AppNotifier.success(message: 'Bank details saved.');
    }
  }

  Future<void> _confirmRemove(
      BuildContext context, PayoutAccountController c) async {
    final bool? yes = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
            const SizedBox(height: 16),
            Text(
              'Remove payout account?',
              style: AppTextStyles.h2.copyWith(color: ctx.text),
            ),
            const SizedBox(height: 8),
            Text(
              "We won't be able to send your earnings until you add another account.",
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: ctx.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            DrivioButton(
              label: 'Remove',
              variant: DrivioButtonVariant.danger,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 8),
            DrivioButton(
              label: 'Cancel',
              variant: DrivioButtonVariant.ghost,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    );
    if (yes == true) {
      await c.removeAccount();
    }
  }
}

// ── Payout account card (filled state) ─────────────────────────────────

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onEdit,
    required this.onRemove,
  });

  final PayoutAccount account;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final (String pillText, PillTone pillTone) =
        account.isVerified
            ? ('VERIFIED', PillTone.accent)
            : ('VERIFYING', PillTone.amber);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.base,
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text('🏦', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      account.displayLabel,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.accountName,
                      style: TextStyle(fontSize: 11, color: context.textDim),
                    ),
                  ],
                ),
              ),
              Pill(text: pillText, tone: pillTone),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: DrivioButton(
                  label: 'Edit',
                  variant: DrivioButtonVariant.ghost,
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DrivioButton(
                  label: 'Remove',
                  variant: DrivioButtonVariant.danger,
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoAccountCard extends StatelessWidget {
  const _NoAccountCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.base,
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: <Widget>[
          Text(
            'No payout account on file',
            style: TextStyle(
              fontSize: 13,
              color: context.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Add your bank details so we can pay your earnings.",
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: context.textDim,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          DrivioButton(
            label: '+ Add bank account',
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

// ── Billing history ────────────────────────────────────────────────────

class _BillingHistory extends StatelessWidget {
  const _BillingHistory({required this.charges});
  final List<LedgerEntry> charges;

  @override
  Widget build(BuildContext context) {
    if (charges.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: context.border),
        ),
        child: Center(
          child: Text(
            'No billing activity yet.',
            style: AppTextStyles.bodySm.copyWith(color: context.textDim),
          ),
        ),
      );
    }
    final List<LedgerEntry> shown = charges.take(20).toList();
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < shown.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: context.border),
            _BillingRow(entry: shown[i]),
          ],
        ],
      ),
    );
  }
}

class _BillingRow extends StatelessWidget {
  const _BillingRow({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('💳', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.description ?? 'Subscription charge',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtDate(entry.createdAt),
                  style: TextStyle(fontSize: 11, color: context.textDim),
                ),
              ],
            ),
          ),
          Text(
            '−${NairaFormatter.format(entry.amountMinor ~/ 100)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.red,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime t) {
    const List<String> m = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${m[(t.month - 1).clamp(0, 11)]} ${t.day}, ${t.year}';
  }
}

// ── Add/edit payout account sheet ──────────────────────────────────────

/// Returned from the bottom sheet; the page hands these values to the
/// controller for the upsert. Bank code intentionally omitted —
/// Paystack resolves the bank from the account number alone.
class _PayoutDraft {
  const _PayoutDraft({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });
  final String bankName;
  final String accountNumber;
  final String accountName;
}

class _PayoutSheet extends StatefulWidget {
  const _PayoutSheet({this.existing});
  final PayoutAccount? existing;

  @override
  State<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<_PayoutSheet> {
  late final TextEditingController _bankName =
      TextEditingController(text: widget.existing?.bankName ?? '');
  // Existing rows only have the last 4 — leave the field empty so the
  // driver re-enters the full number when editing.
  late final TextEditingController _acctNumber =
      TextEditingController();
  late final TextEditingController _acctName =
      TextEditingController(text: widget.existing?.accountName ?? '');
  String? _error;

  @override
  void dispose() {
    _bankName.dispose();
    _acctNumber.dispose();
    _acctName.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_bankName.text.trim().isEmpty) {
      setState(() => _error = 'Bank name is required.');
      return false;
    }
    final String acct = _acctNumber.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(acct)) {
      setState(() =>
          _error = 'Account number must be 10 digits (NUBAN format).');
      return false;
    }
    if (_acctName.text.trim().isEmpty) {
      setState(() => _error = 'Account name is required.');
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  void _save() {
    if (!_validate()) return;
    Navigator.of(context).pop(
      _PayoutDraft(
        bankName: _bankName.text.trim(),
        accountNumber: _acctNumber.text.trim(),
        accountName: _acctName.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existing != null;
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
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Edit payout account' : 'Add payout account',
              style: AppTextStyles.h2.copyWith(color: context.text),
            ),
            const SizedBox(height: 4),
            Text(
              "We'll deposit your earnings to this Nigerian bank account.",
              style: AppTextStyles.caption.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 16),
            DrivioInput(
              label: 'Bank name',
              hint: 'GTBank',
              controller: _bankName,
              autofocus: !isEdit,
            ),
            const SizedBox(height: 12),
            DrivioInput(
              label: 'Account number',
              hint: isEdit
                  ? 'Re-enter to update'
                  : '10-digit NUBAN',
              controller: _acctNumber,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            const SizedBox(height: 12),
            DrivioInput(
              label: 'Account name',
              hint: 'TUNDE OGUNLEYE',
              controller: _acctName,
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(fontSize: 12, color: context.red),
              ),
            ],
            const SizedBox(height: 18),
            DrivioButton(
              label: isEdit ? 'Save changes' : 'Add account',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
