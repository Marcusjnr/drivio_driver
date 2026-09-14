import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

/// Once-per-launch nudge for a driver with no saved bank account.
/// Trips are cash-in-hand, so this account is NOT for earnings — it's
/// where Drivio sends promo payouts and bonuses (e.g. reimbursing a
/// Drivio-funded rider discount). Shown over the idle home shell on
/// open; the CTA routes into the existing add-bank-account flow
/// (`AppRoutes.addBankAccount`), which verifies the account with
/// Paystack server-side and persists it in `driver_payout_accounts`.
/// Dismissable — it returns on the next app open, never again within
/// the same launch.
class AddBankPromptSheet extends ConsumerWidget {
  const AddBankPromptSheet({
    super.key,
    required this.onAdd,
    required this.onDismiss,
  });

  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GestureDetector(
          onTap: onDismiss,
          child: Container(color: Colors.black.withValues(alpha: 0.55)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: BottomSheetCard(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: context.coral.withValues(alpha: 0.16),
                    border: Border.all(
                      color: context.coral.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🏦', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(height: 14),
                const Pill(text: 'PROMOS & REWARDS', tone: PillTone.accent),
                const SizedBox(height: 10),
                Text(
                  'Add your\nbank account.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1.copyWith(color: context.text),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 290,
                  child: Text(
                    'When Drivio runs a promo or bonus, we pay it straight '
                    'into your bank account. Add yours so you never miss a '
                    'payout. It takes under a minute.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: context.textDim,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                DrivioButton(label: 'Add bank account', onPressed: onAdd),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    'Not now',
                    style: TextStyle(color: context.textDim, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
