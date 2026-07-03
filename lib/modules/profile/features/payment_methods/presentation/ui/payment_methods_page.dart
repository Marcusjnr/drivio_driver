import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/wallet.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/profile/features/payment_methods/presentation/logic/controller/payout_account_controller.dart';

/// Trips are paid in cash — the driver collects the fare directly, so there
/// is no in-app balance and nothing to pay out to a bank. This page is now
/// purely a record of the driver's own Drivio subscription charges, derived
/// from `wallet_ledger.subscription_debit` entries.
class PaymentMethodsPage extends ConsumerWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PayoutAccountState state =
        ref.watch(payoutAccountControllerProvider);

    return DetailScaffold(
      title: 'Subscription & billing',
      subtitle: 'Your Drivio subscription charges',
      children: <Widget>[
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...<Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: AppRadius.base,
              border: Border.all(color: context.border),
            ),
            child: Row(
              children: <Widget>[
                const Text('💵', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Riders pay you in cash at the end of each trip — you keep '
                    '100%. Your subscription is the only thing Drivio charges.',
                    style: AppTextStyles.captionSm.copyWith(
                      color: context.textDim,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
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
