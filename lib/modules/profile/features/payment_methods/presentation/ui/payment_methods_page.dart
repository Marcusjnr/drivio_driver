import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/payout_account.dart';
import 'package:drivio_driver/modules/commons/types/wallet.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/profile/features/payment_methods/presentation/logic/controller/payout_account_controller.dart';
import 'package:drivio_driver/modules/profile/features/payment_methods/presentation/ui/payout_account_sheet.dart';

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
    final PayoutDraft? draft = await showPayoutAccountSheet(
      context,
      existing: existing,
      loadBanks: () =>
          ref.read(payoutAccountControllerProvider.notifier).loadBanks(),
    );
    if (draft == null) return;
    final String? accountName = await ref
        .read(payoutAccountControllerProvider.notifier)
        .saveAccount(
          bankName: draft.bankName,
          bankCode: draft.bankCode,
          accountNumber: draft.accountNumber,
        );
    if (accountName == null) {
      final String? err =
          ref.read(payoutAccountControllerProvider).error;
      AppNotifier.error(
        message: err ?? "Couldn't save bank details. Try again in a moment.",
      );
    } else {
      AppNotifier.success(message: 'Bank account verified — $accountName.');
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
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.accountName,
                      style: AppTextStyles.captionSm
                          .copyWith(fontSize: 11, color: context.textDim),
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
            style: AppTextStyles.caption.copyWith(
              color: context.text,
              fontWeight: FontWeight.w700,
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
            'No billing activity yet. Charges show up after each renewal.',
            textAlign: TextAlign.center,
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
                  style: AppTextStyles.caption.copyWith(
                    color: context.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtDate(entry.createdAt),
                  style: AppTextStyles.captionSm
                      .copyWith(fontSize: 11, color: context.textDim),
                ),
              ],
            ),
          ),
          Text(
            '−${NairaFormatter.format(entry.amountMinor ~/ 100)}',
            style: AppTextStyles.bodySm.copyWith(
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

