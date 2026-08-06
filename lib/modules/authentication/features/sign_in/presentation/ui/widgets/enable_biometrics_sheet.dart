import 'package:flutter/material.dart';

import 'package:drivio_driver/modules/commons/all.dart';

/// Offered once, straight after a successful password sign in, while the
/// password that would be stored is the one just proved to work.
///
/// Returns true to enable, false or null to decline. Declining is
/// remembered so the offer does not come back every sign in.
Future<bool?> showEnableBiometricsSheet(
  BuildContext context, {
  required bool isFaceId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => _EnableBiometricsSheet(isFaceId: isFaceId),
  );
}

class _EnableBiometricsSheet extends StatelessWidget {
  const _EnableBiometricsSheet({required this.isFaceId});

  final bool isFaceId;

  @override
  Widget build(BuildContext context) {
    final String name = isFaceId ? 'Face ID' : 'your fingerprint';

    return BottomSheetCard(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.coral.withValues(alpha: 0.14),
              border: Border.all(color: context.coral.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(
              isFaceId ? Icons.face_outlined : Icons.fingerprint_rounded,
              size: 28,
              color: context.coral,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sign in with $name',
            textAlign: TextAlign.center,
            style: AppTextStyles.h1.copyWith(color: context.text),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 300,
            child: Text(
              'Skip typing your password every time. You can turn this off '
              'in Settings whenever you want.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: context.textDim,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 22),
          DrivioButton(
            label: 'Turn it on',
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Not now',
              style: TextStyle(color: context.textDim, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
