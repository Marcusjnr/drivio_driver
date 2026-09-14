import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/withdrawal_repository.dart';
import 'package:drivio_driver/modules/commons/types/payout_account.dart';

/// Values entered in the payout-account sheet. The caller persists them via
/// its controller, which calls `driver-payout-recipient` to resolve + verify
/// the account server-side.
class PayoutDraft {
  const PayoutDraft({
    required this.bankName,
    required this.bankCode,
    required this.accountNumber,
  });
  final String bankName;
  final String bankCode;
  final String accountNumber;
}

/// Shows the add/edit payout-account bottom sheet. Returns the entered draft,
/// or null if the driver cancelled. Shared by the Manage-payment screen and
/// the Withdraw screen so a driver can add their bank without leaving the
/// withdrawal flow.
Future<PayoutDraft?> showPayoutAccountSheet(
  BuildContext context, {
  PayoutAccount? existing,
  required Future<List<PaystackBank>> Function() loadBanks,
}) {
  return showModalBottomSheet<PayoutDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) =>
        _PayoutSheet(existing: existing, loadBanks: loadBanks),
  );
}

class _PayoutSheet extends StatefulWidget {
  const _PayoutSheet({this.existing, required this.loadBanks});
  final PayoutAccount? existing;
  final Future<List<PaystackBank>> Function() loadBanks;

  @override
  State<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<_PayoutSheet> {
  // Existing rows only have the last 4 — leave the field empty so the
  // driver re-enters the full number when editing.
  final TextEditingController _acctNumber = TextEditingController();

  List<PaystackBank> _banks = const <PaystackBank>[];
  PaystackBank? _selectedBank;
  bool _banksLoading = true;
  bool _banksError = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    setState(() {
      _banksLoading = true;
      _banksError = false;
    });
    try {
      final List<PaystackBank> banks = await widget.loadBanks();
      if (!mounted) return;
      setState(() {
        _banks = banks;
        _banksLoading = false;
        if (widget.existing != null) {
          for (final PaystackBank b in banks) {
            if (b.name == widget.existing!.bankName) {
              _selectedBank = b;
              break;
            }
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _banksLoading = false;
        _banksError = true;
      });
    }
  }

  @override
  void dispose() {
    _acctNumber.dispose();
    super.dispose();
  }

  bool _validate() {
    if (_selectedBank == null) {
      setState(() => _error = 'Please pick your bank.');
      return false;
    }
    final String acct = _acctNumber.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(acct)) {
      setState(() => _error = 'Account number must be 10 digits (NUBAN format).');
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  void _save() {
    if (!_validate()) return;
    Navigator.of(context).pop(
      PayoutDraft(
        bankName: _selectedBank!.name,
        bankCode: _selectedBank!.code,
        accountNumber: _acctNumber.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existing != null;
    // Keyboard inset while typing; gesture-bar clearance otherwise.
    final double keyboard = MediaQuery.of(context).viewInsets.bottom;
    final double safe = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard > 0 ? keyboard : safe),
      child: Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
              "Pick your bank and enter your account number. We'll confirm "
              'the account name with your bank.',
              style: AppTextStyles.caption.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 16),
            PayoutBankPicker(
              banks: _banks,
              selected: _selectedBank,
              loading: _banksLoading,
              hasError: _banksError,
              onRetry: _loadBanks,
              onChanged: (PaystackBank? b) => setState(() => _selectedBank = b),
            ),
            const SizedBox(height: 12),
            DrivioInput(
              label: 'Account number',
              hint: isEdit ? 'Re-enter to update' : '10-digit NUBAN',
              controller: _acctNumber,
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
            const SizedBox(height: 18),
            DrivioButton(
              label: isEdit ? 'Save changes' : 'Verify & add',
              disabled: _banksLoading || _banksError,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bank picker backed by the `paystack-banks` list. Shows a spinner while
/// loading and a retry affordance if the list fails to load. Tapping the
/// field opens a searchable bottom sheet instead of a plain dropdown —
/// Paystack's Nigerian list runs to hundreds of entries (every microfinance
/// bank included), so type-to-filter is the only way to find yours fast.
class PayoutBankPicker extends StatelessWidget {
  const PayoutBankPicker({
    super.key,
    required this.banks,
    required this.selected,
    required this.loading,
    required this.hasError,
    required this.onRetry,
    required this.onChanged,
  });

  final List<PaystackBank> banks;
  final PaystackBank? selected;
  final bool loading;
  final bool hasError;
  final VoidCallback onRetry;
  final ValueChanged<PaystackBank?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        height: 56,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderStrong),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading banks…',
              style: AppTextStyles.body.copyWith(color: context.textDim),
            ),
          ],
        ),
      );
    }
    if (hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderStrong),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                "Couldn't load banks.",
                style: AppTextStyles.body.copyWith(color: context.textDim),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final PaystackBank? picked = await _showBankSearchSheet(
          context,
          banks: banks,
          selected: selected,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderStrong),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                selected?.name ?? 'Select bank',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  color: selected == null ? context.textMuted : context.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down_rounded, color: context.textDim),
          ],
        ),
      ),
    );
  }
}

/// Opens the searchable bank list. Resolves with the tapped bank, or null
/// when dismissed without choosing.
Future<PaystackBank?> _showBankSearchSheet(
  BuildContext context, {
  required List<PaystackBank> banks,
  PaystackBank? selected,
}) {
  return showModalBottomSheet<PaystackBank>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext _) =>
        _BankSearchSheet(banks: banks, selected: selected),
  );
}

class _BankSearchSheet extends StatefulWidget {
  const _BankSearchSheet({required this.banks, this.selected});

  final List<PaystackBank> banks;
  final PaystackBank? selected;

  @override
  State<_BankSearchSheet> createState() => _BankSearchSheetState();
}

class _BankSearchSheetState extends State<_BankSearchSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    // setState-only listener: the filter itself derives from the
    // controller's text at build time.
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<PaystackBank> get _filtered {
    final String q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.banks;
    return widget.banks
        .where((PaystackBank b) => b.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<PaystackBank> filtered = _filtered;
    // Fixed tall sheet (75% of screen) so the list doesn't jump around as
    // the filter narrows; the keyboard inset rides underneath it.
    final double height = MediaQuery.sizeOf(context).height * 0.75;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
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
              'Select bank',
              style: AppTextStyles.h2.copyWith(color: context.text),
            ),
            const SizedBox(height: 12),
            // Search box. No autofocus: the list paints first, and one tap
            // brings the keyboard only when the driver actually wants to
            // type — the big banks are usually a scroll away.
            TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.body.copyWith(color: context.text),
              decoration: InputDecoration(
                hintText: 'Search banks…',
                hintStyle: AppTextStyles.body.copyWith(
                  color: context.textMuted,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: context.textDim,
                ),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: context.textDim,
                        ),
                        onPressed: _query.clear,
                      ),
                filled: true,
                fillColor: context.surface2,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.accent),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No banks match "${_query.text.trim()}".',
                        style: AppTextStyles.bodySm.copyWith(
                          color: context.textDim,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.only(
                        top: 4,
                        bottom: MediaQuery.paddingOf(context).bottom + 12,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (BuildContext _, int _) =>
                          Divider(height: 1, color: context.border),
                      itemBuilder: (BuildContext _, int i) {
                        final PaystackBank bank = filtered[i];
                        final bool isSelected =
                            bank.code == widget.selected?.code;
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(bank),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    bank.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.body.copyWith(
                                      color: context.text,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: context.accent,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
