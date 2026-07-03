import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/trip/features/call/logic/call_controller.dart';

// Brand call-screen palette (Coastal Pulse dark): deep charcoal-teal canvas,
// glowing coral avatar ring, ivory serif identity.
const Color _kBg = Color(0xFF0C2A2D);
const Color _kDisc = Color(0xFF12393C);
const Color _kLine = Color(0xFF2C5457);
const Color _kIvory = Color(0xFFF2ECDF);
const Color _kIvoryDim = Color(0xFFB9C4C0);

/// The live call screen — outgoing ring, connected (timer + controls), and
/// reconnecting states, driven by [activeCallControllerProvider]. Terminal
/// phases show a short status then pop back.
class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key});

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  bool _popScheduled = false;

  void _popSoon() {
    if (_popScheduled) {
      return;
    }
    _popScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) {
        return;
      }
      ref.read(activeCallControllerProvider.notifier).reset();
      if (AppNavigation.canPop()) {
        AppNavigation.pop<void>();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CallState state = ref.watch(activeCallControllerProvider);
    final ActiveCallController c = ref.read(
      activeCallControllerProvider.notifier,
    );

    if (state.phase.isTerminal || state.phase == CallPhase.idle) {
      _popSoon();
    }

    final String who = state.contact?.displayName ?? 'Rider';
    final String mm = (state.connectedSeconds ~/ 60).toString().padLeft(2, '0');
    final String ss = (state.connectedSeconds % 60).toString().padLeft(2, '0');

    final String status = switch (state.phase) {
      CallPhase.outgoingRinging => 'Calling…',
      CallPhase.connecting =>
        state.engineJoined ? 'Waiting for $who…' : 'Connecting…',
      CallPhase.connected => '$mm:$ss',
      CallPhase.reconnecting => 'Reconnecting…',
      CallPhase.declined => 'Call declined',
      CallPhase.missed => 'No answer',
      CallPhase.cancelled => 'Call cancelled',
      CallPhase.failed => state.error ?? 'Call failed',
      CallPhase.ended => 'Call ended',
      _ => '',
    };

    final bool inCall =
        state.phase == CallPhase.connected ||
        state.phase == CallPhase.reconnecting;
    final bool ringing =
        state.phase == CallPhase.outgoingRinging ||
        state.phase == CallPhase.connecting;

    return PopScope(
      canPop: state.phase.isTerminal || state.phase == CallPhase.idle,
      child: Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: <Widget>[
                const Spacer(flex: 2),
                GlowAvatar(
                  url: state.contact?.avatarUrl,
                  name: who,
                  glowing: ringing || inCall,
                  coral: context.coral,
                ),
                const SizedBox(height: 34),
                Text(
                  who,
                  style: AppTextStyles.h1.copyWith(
                    color: _kIvory,
                    fontSize: 40,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: state.phase == CallPhase.reconnecting
                        ? context.amber
                        : _kIvoryDim,
                    fontSize: 17,
                  ),
                ),
                const Spacer(flex: 3),
                if (inCall || ringing)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      RingControl(
                        icon: state.muted ? DrivioIcons.mute : DrivioIcons.mic,
                        active: state.muted,
                        enabled: inCall,
                        coral: context.coral,
                        onTap: c.toggleMute,
                      ),
                      const SizedBox(width: 26),
                      RingControl(
                        icon: DrivioIcons.speaker,
                        active: state.speakerOn,
                        enabled: inCall,
                        coral: context.coral,
                        onTap: c.toggleSpeaker,
                      ),
                    ],
                  ),
                const SizedBox(height: 44),
                if (state.phase.isLive)
                  EndCallButton(
                    coral: context.coral,
                    onTap: () {
                      if (state.phase == CallPhase.outgoingRinging) {
                        unawaited(c.cancelOutgoing());
                      } else {
                        unawaited(c.hangUp());
                      }
                    },
                  ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The big brand avatar disc: photo (or serif initial) on a lighter teal
/// disc, wrapped in a coral ring with a soft glow.
class GlowAvatar extends StatelessWidget {
  const GlowAvatar({
    super.key,
    required this.url,
    required this.name,
    required this.glowing,
    required this.coral,
  });

  final String? url;
  final String name;
  final bool glowing;
  final Color coral;

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = url != null && url!.isNotEmpty;
    return Container(
      width: 196,
      height: 196,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kDisc,
        border: Border.all(color: coral, width: 3),
        boxShadow: glowing
            ? <BoxShadow>[
                BoxShadow(
                  color: coral.withValues(alpha: 0.45),
                  blurRadius: 46,
                  spreadRadius: 6,
                ),
              ]
            : null,
        image: hasPhoto
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTextStyles.h1.copyWith(color: _kIvory, fontSize: 88),
            ),
    );
  }
}

/// Thin-outlined circular control, per the brand call screen.
class RingControl extends StatelessWidget {
  const RingControl({
    super.key,
    required this.icon,
    required this.active,
    required this.enabled,
    required this.coral,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final bool enabled;
  final Color coral;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 74,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? _kIvory : Colors.transparent,
            border: Border.all(color: active ? _kIvory : _kLine, width: 1.4),
          ),
          child: Icon(icon, size: 28, color: active ? _kBg : _kIvory),
        ),
      ),
    );
  }
}

/// Coral end-call button with a soft glow.
class EndCallButton extends StatelessWidget {
  const EndCallButton({super.key, required this.coral, required this.onTap});

  final Color coral;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 82,
        height: 82,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: coral,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: coral.withValues(alpha: 0.5),
              blurRadius: 34,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          DrivioIcons.callEnd,
          size: 34,
          color: Color(0xFF3A1408),
        ),
      ),
    );
  }
}
