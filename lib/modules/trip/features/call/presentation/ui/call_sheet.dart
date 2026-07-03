import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/data/call_repository.dart';
import 'package:drivio_driver/modules/commons/types/call.dart';
import 'package:drivio_driver/modules/trip/features/call/logic/call_controller.dart';

/// The two-option call sheet: Regular Call (native dialer, counterpart's
/// number) and Free Call (Agora voice over internet). Contact identity is
/// fetched from `get_trip_contact` (active-trip participants only).
Future<void> showCallSheet(
  BuildContext context,
  WidgetRef ref, {
  required String tripId,
}) async {
  final _CallChoice? choice = await showModalBottomSheet<_CallChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext _) => _CallSheet(tripId: tripId),
  );
  if (choice == null || !context.mounted) {
    return;
  }

  switch (choice.kind) {
    case _CallKind.regular:
      final String? phone = choice.contact?.phoneE164;
      if (phone == null || phone.isEmpty) {
        AppNotifier.warning(
          message: "Their number isn't available right now. Try a free call.",
        );
        return;
      }
      // Opens the dialer pre-filled — never places the call itself.
      final Uri uri = Uri(scheme: 'tel', path: phone);
      if (!await launchUrl(uri)) {
        AppNotifier.error(message: "Couldn't open the phone app.");
      }
    case _CallKind.free:
      final bool ok = await ref
          .read(activeCallControllerProvider.notifier)
          .startOutgoing(tripId);
      if (!context.mounted) {
        return;
      }
      if (ok) {
        AppNavigation.push<void>(AppRoutes.call);
      } else {
        final String? err = ref.read(activeCallControllerProvider).error;
        AppNotifier.error(
          message: err ?? "Couldn't start the call. Try again.",
        );
        ref.read(activeCallControllerProvider.notifier).reset();
      }
  }
}

enum _CallKind { regular, free }

class _CallChoice {
  const _CallChoice(this.kind, this.contact);
  final _CallKind kind;
  final TripContact? contact;
}

class _CallSheet extends ConsumerStatefulWidget {
  const _CallSheet({required this.tripId});
  final String tripId;

  @override
  ConsumerState<_CallSheet> createState() => _CallSheetState();
}

class _CallSheetState extends ConsumerState<_CallSheet> {
  TripContact? _contact;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final TripContact? c = await locator<CallRepository>().getTripContact(
        widget.tripId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _contact = c;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String who = _contact?.displayName ?? 'your rider';
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
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
              'Call $who',
              style: AppTextStyles.h2.copyWith(color: context.text),
            ),
            const SizedBox(height: 14),
            _OptionRow(
              icon: DrivioIcons.phone,
              title: 'Regular call',
              subtitle: _loading
                  ? 'Loading number…'
                  : (_contact?.phoneE164 ?? 'Number unavailable'),
              trailing: 'Uses your network',
              enabled: !_loading,
              onTap: () => Navigator.of(
                context,
              ).pop(_CallChoice(_CallKind.regular, _contact)),
            ),
            const SizedBox(height: 10),
            _OptionRow(
              icon: Icons.wifi_calling_3_rounded,
              title: 'Free call',
              subtitle: 'Voice over internet — no airtime used',
              trailing: 'Free',
              enabled: true,
              onTap: () => Navigator.of(
                context,
              ).pop(_CallChoice(_CallKind.free, _contact)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.surface2,
            borderRadius: AppRadius.md,
            border: Border.all(color: context.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: context.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTextStyles.bodySm.copyWith(
                        color: context.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.captionSm.copyWith(
                        fontSize: 11,
                        color: context.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Pill(text: trailing.toUpperCase(), tone: PillTone.accent),
            ],
          ),
        ),
      ),
    );
  }
}
