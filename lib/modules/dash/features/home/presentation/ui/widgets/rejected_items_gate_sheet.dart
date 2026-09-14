import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/kyc/features/kyc_home/presentation/logic/controller/kyc_controller.dart';

/// Blocks "Go online" while any document has a live rejection — a driver
/// cannot start accepting trips with a flagged licence, selfie, or vehicle
/// document, even if their overall KYC status is otherwise `approved`.
/// Lists exactly which items are rejected (mirroring `KycGateSheet`'s
/// checklist layout) so the driver knows what to fix without guessing.
class RejectedItemsGateSheet extends ConsumerWidget {
  const RejectedItemsGateSheet({
    super.key,
    required this.onContinue,
    required this.onDismiss,
  });

  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<RejectedDocumentItem> items = ref.watch(
      kycControllerProvider.select((KycState s) => s.rejectedItems),
    );

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
                    color: context.red.withValues(alpha: 0.16),
                    border: Border.all(color: context.red.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(DrivioIcons.close, size: 26, color: context.red),
                ),
                const SizedBox(height: 14),
                const Pill(text: 'ACTION NEEDED', tone: PillTone.red),
                const SizedBox(height: 10),
                Text(
                  'Some documents\nneed fixing.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1.copyWith(color: context.text),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 290,
                  child: Text(
                    "You can't go online until these are sorted out. "
                    'Review what needs fixing below.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: context.textDim,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ...items.map(
                  (RejectedDocumentItem i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RejectedRow(item: i),
                  ),
                ),
                const SizedBox(height: 14),
                DrivioButton(
                  label: 'Review what needs fixing',
                  onPressed: onContinue,
                ),
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

class _RejectedRow extends StatelessWidget {
  const _RejectedRow({required this.item});
  final RejectedDocumentItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(DrivioIcons.close, size: 16, color: context.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: context.red),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Pill(text: 'Re-do', tone: PillTone.red),
        ],
      ),
    );
  }
}
