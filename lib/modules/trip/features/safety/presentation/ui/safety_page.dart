import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/types/trusted_contact.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';
import 'package:drivio_driver/modules/trip/features/safety/presentation/logic/controller/safety_controller.dart';
import 'package:drivio_driver/modules/trip/features/safety/presentation/logic/controller/trusted_contacts_controller.dart';

/// Per spec DRV-080: 3-second long-press on the SOS bell raises a
/// `safety_events` row with the driver's location + active trip context,
/// so on-call ops can page emergency response.
const Duration _kHoldToActivate = Duration(seconds: 3);

class SafetyPage extends ConsumerStatefulWidget {
  const SafetyPage({super.key});

  @override
  ConsumerState<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends ConsumerState<SafetyPage> {
  String? _tripId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tripId ??= ModalRoute.of(context)?.settings.arguments as String?;
  }

  @override
  Widget build(BuildContext context) {
    final SafetyState state = ref.watch(safetyControllerProvider);
    final SafetyController c = ref.read(safetyControllerProvider.notifier);

    return DetailScaffold(
      title: 'Safety toolkit',
      subtitle: 'All tools at your fingertips',
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                context.red.withValues(alpha: 0.14),
                context.red.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: AppRadius.lg,
            border: Border.all(color: context.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: <Widget>[
              if (state.hasFired)
                _HelpOnTheWay(onDismiss: c.dismissConfirmation)
              else
                _HoldToActivate(
                  isTriggering: state.isTriggering,
                  onActivated: () async {
                    final bool ok = await c.triggerSos(tripId: _tripId);
                    if (!ok && mounted) {
                      AppNotifier.error(
                        message: ref.read(safetyControllerProvider).error ??
                            "SOS didn't go through. Try again.",
                      );
                    }
                  },
                ),
              const SizedBox(height: 14),
              Text(
                state.hasFired
                    ? "Help is on the way"
                    : 'Hold 3 seconds to alert Trust',
                style: AppTextStyles.h2.copyWith(color: context.text),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 280,
                child: Text(
                  state.hasFired
                      ? 'Drivio Trust has your live location and trip context. They will call the emergency line if needed.'
                      : 'Drivio shares your live location with our Trust team and any trusted contacts.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: context.textDim,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        DetailGroup(
          title: 'QUICK ACTIONS',
          children: const <Widget>[
            _SafetyRow(
                emoji: '📍',
                title: 'Share trip status',
                sub: 'Send live ETA to trusted contacts'),
            _SafetyRow(
                emoji: '🎙️',
                title: 'Record audio',
                sub: 'Encrypted, only auditable in a report'),
            _SafetyRow(
                emoji: '💬',
                title: 'Contact Trust team',
                sub: '24/7 in-app support — typical reply 2 min'),
            _SafetyRow(
                emoji: '⚠️',
                title: 'Report a rider',
                sub: 'File an incident after the trip',
                isLast: true),
          ],
        ),
        const _TrustedContactsSection(),
        const SizedBox(height: 14),
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style:
                  TextStyle(fontSize: 11, color: context.textDim, height: 1.6),
              children: <InlineSpan>[
                const TextSpan(
                    text:
                        'Drivio drivers get free roadside assistance 24/7.\nDial '),
                TextSpan(
                  text: '0800-DRIVIO',
                  style: TextStyle(
                      color: context.text, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' anytime.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 3-second hold-to-activate button. Fills a ring around the SOS circle
/// while the driver presses; releasing early cancels.
class _HoldToActivate extends StatefulWidget {
  const _HoldToActivate({
    required this.isTriggering,
    required this.onActivated,
  });

  final bool isTriggering;
  final VoidCallback onActivated;

  @override
  State<_HoldToActivate> createState() => _HoldToActivateState();
}

class _HoldToActivateState extends State<_HoldToActivate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: _kHoldToActivate,
      vsync: this,
    )..addStatusListener((AnimationStatus s) {
        if (s == AnimationStatus.completed && !_fired) {
          _fired = true;
          widget.onActivated();
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _begin() {
    if (widget.isTriggering) return;
    _fired = false;
    _ctrl.forward(from: 0);
  }

  void _cancel() {
    if (!_fired && _ctrl.isAnimating) {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _begin(),
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      child: SizedBox(
        width: 124,
        height: 124,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // Progress ring.
            AnimatedBuilder(
              animation: _ctrl,
              builder: (BuildContext context, _) {
                return SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _ctrl.value,
                    strokeWidth: 5,
                    color: context.red,
                    backgroundColor: context.red.withValues(alpha: 0.18),
                  ),
                );
              },
            ),
            // SOS circle.
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: context.red,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: context.red.withValues(alpha: 0.4),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: widget.isTriggering
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: context.bg,
                      ),
                    )
                  : const Text('🚨', style: TextStyle(fontSize: 36)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpOnTheWay extends StatelessWidget {
  const _HelpOnTheWay({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.accent, width: 5),
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: context.accent,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: context.accent.withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: onDismiss,
              child: Icon(DrivioIcons.check,
                  color: context.accentInk, size: 38),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({
    required this.emoji,
    required this.title,
    required this.sub,
    this.isLast = false,
  });
  final String emoji;
  final String title;
  final String sub;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: context.border)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(fontSize: 11, color: context.textDim),
                ),
              ],
            ),
          ),
          Icon(DrivioIcons.chevron, size: 14, color: context.textMuted),
        ],
      ),
    );
  }
}

/// Reads/writes the calling driver's trusted contacts. Cap is enforced
/// server-side (3) — the UI greys out the "Add" row once we hit it.
class _TrustedContactsSection extends ConsumerWidget {
  const _TrustedContactsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrustedContactsState state =
        ref.watch(trustedContactsControllerProvider);
    final TrustedContactsController c =
        ref.read(trustedContactsControllerProvider.notifier);

    if (state.isLoading) {
      return const DetailGroup(
        title: 'TRUSTED CONTACTS',
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        ],
      );
    }

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < state.contacts.length; i++) {
      final TrustedContact contact = state.contacts[i];
      rows.add(_ContactRow(
        contact: contact,
        onTap: () => _openEditSheet(context, ref, contact),
      ));
    }

    final bool addEnabled = !state.isFull && !state.isMutating;
    rows.add(
      InkWell(
        onTap: addEnabled
            ? () => _openAddSheet(context, ref)
            : null,
        child: Opacity(
          opacity: addEnabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                Icon(DrivioIcons.plus, size: 16, color: context.accent),
                const SizedBox(width: 10),
                Text(
                  state.isFull
                      ? 'Maximum $kTrustedContactsCap contacts reached'
                      : 'Add contact',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: state.isFull ? context.textDim : context.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DetailGroup(
          title: 'TRUSTED CONTACTS',
          children: rows,
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    state.error!,
                    style: TextStyle(fontSize: 11, color: context.red),
                  ),
                ),
                GestureDetector(
                  onTap: c.clearError,
                  child: Text(
                    'DISMISS',
                    style: AppTextStyles.eyebrow
                        .copyWith(color: context.textDim),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    // Sheet always returns `_ContactSheetResult` regardless of mode; the
    // add path simply ignores the `deleted` flag (Remove button is hidden
    // when there's no `existing` contact).
    final _ContactSheetResult? result =
        await showModalBottomSheet<_ContactSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) =>
          const _ContactSheet(title: 'New trusted contact'),
    );
    if (result == null || result.draft == null) return;
    final _ContactDraft draft = result.draft!;
    await ref.read(trustedContactsControllerProvider.notifier).add(
          name: draft.name,
          phoneE164: draft.phoneE164,
          isPrimary: draft.isPrimary,
        );
  }

  Future<void> _openEditSheet(
    BuildContext context,
    WidgetRef ref,
    TrustedContact contact,
  ) async {
    final _ContactSheetResult? result =
        await showModalBottomSheet<_ContactSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _ContactSheet(
        title: 'Edit contact',
        existing: contact,
      ),
    );
    if (result == null) return;
    final TrustedContactsController c =
        ref.read(trustedContactsControllerProvider.notifier);
    if (result.deleted) {
      await c.remove(contact.id);
      return;
    }
    final _ContactDraft draft = result.draft!;
    final bool changedFields =
        draft.name != contact.name || draft.phoneE164 != contact.phoneE164;
    if (changedFields) {
      await c.update(
        id: contact.id,
        name: draft.name == contact.name ? null : draft.name,
        phoneE164:
            draft.phoneE164 == contact.phoneE164 ? null : draft.phoneE164,
      );
    }
    if (draft.isPrimary && !contact.isPrimary) {
      await c.setPrimary(contact.id);
    }
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.onTap});

  final TrustedContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.border)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          contact.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.text,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (contact.isPrimary) ...<Widget>[
                        const SizedBox(width: 8),
                        const Pill(text: 'PRIMARY', tone: PillTone.accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.maskedPhone,
                    style: TextStyle(fontSize: 12, color: context.textDim),
                  ),
                ],
              ),
            ),
            Icon(DrivioIcons.chevron, size: 14, color: context.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Returned from the contact bottom sheet. `deleted=true` means the user
/// tapped "Remove contact"; otherwise `draft` carries the new field
/// values.
class _ContactSheetResult {
  const _ContactSheetResult({this.draft, this.deleted = false});
  final _ContactDraft? draft;
  final bool deleted;
}

class _ContactDraft {
  const _ContactDraft({
    required this.name,
    required this.phoneE164,
    required this.isPrimary,
  });
  final String name;
  final String phoneE164;
  final bool isPrimary;
}

class _ContactSheet extends StatefulWidget {
  const _ContactSheet({required this.title, this.existing});

  final String title;
  final TrustedContact? existing;

  @override
  State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?.phoneE164 ?? '+234');
  late bool _isPrimary = widget.existing?.isPrimary ?? false;
  String? _validationError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool _validate() {
    final String name = _name.text.trim();
    final String phone = _phone.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = 'Name is required.');
      return false;
    }
    // Light E.164 sanity check — server has the authoritative validation.
    final RegExp e164 = RegExp(r'^\+\d{8,15}$');
    if (!e164.hasMatch(phone)) {
      setState(() => _validationError =
          'Phone must be in international format e.g. +2348012345678.');
      return false;
    }
    setState(() => _validationError = null);
    return true;
  }

  void _save() {
    if (!_validate()) return;
    Navigator.of(context).pop(
      _ContactSheetResult(
        draft: _ContactDraft(
          name: _name.text.trim(),
          phoneE164: _phone.text.trim(),
          isPrimary: _isPrimary,
        ),
      ),
    );
  }

  void _delete() {
    Navigator.of(context).pop(const _ContactSheetResult(deleted: true));
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
            const SizedBox(height: 18),
            Text(widget.title,
                style: AppTextStyles.h2.copyWith(color: context.text)),
            const SizedBox(height: 4),
            Text(
              "Drivio shares your live location with this person if you trigger SOS.",
              style: AppTextStyles.caption.copyWith(color: context.textDim),
            ),
            const SizedBox(height: 18),
            DrivioInput(
              label: 'Name',
              hint: 'e.g. Bisi (wife)',
              controller: _name,
              autofocus: !isEdit,
            ),
            const SizedBox(height: 12),
            DrivioInput(
              label: 'Phone (international format)',
              hint: '+2348012345678',
              controller: _phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Primary contact',
                        style: TextStyle(
                            fontSize: 14,
                            color: context.text,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Always called first in an emergency.',
                        style: TextStyle(
                            fontSize: 11, color: context.textDim, height: 1.4),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _isPrimary,
                  onChanged: (bool v) => setState(() => _isPrimary = v),
                  activeTrackColor: context.accent,
                ),
              ],
            ),
            if (_validationError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _validationError!,
                style: TextStyle(fontSize: 12, color: context.red),
              ),
            ],
            const SizedBox(height: 18),
            DrivioButton(
              label: isEdit ? 'Save changes' : 'Add contact',
              onPressed: _save,
            ),
            if (isEdit) ...<Widget>[
              const SizedBox(height: 8),
              DrivioButton(
                label: 'Remove contact',
                variant: DrivioButtonVariant.ghost,
                onPressed: _delete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
