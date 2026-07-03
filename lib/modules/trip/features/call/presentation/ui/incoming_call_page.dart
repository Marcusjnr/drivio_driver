import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/trip/features/call/logic/call_controller.dart';
import 'package:drivio_driver/modules/trip/features/call/presentation/ui/call_page.dart';

const Color _kBg = Color(0xFF0C2A2D);
const Color _kIvory = Color(0xFFF2ECDF);
const Color _kIvoryDim = Color(0xFFB9C4C0);

/// Full-screen in-app incoming call (foreground ring path — background and
/// killed-state rings come through the native call UI instead). Accept joins
/// the channel and hands off to [CallPage].
class IncomingCallPage extends ConsumerStatefulWidget {
  const IncomingCallPage({super.key});

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<CallState>(activeCallControllerProvider, (
      CallState? prev,
      CallState next,
    ) {
      if (_handled || !mounted) {
        return;
      }
      if (next.phase == CallPhase.connecting ||
          next.phase == CallPhase.connected) {
        _handled = true;
        AppNavigation.replace<void, void>(AppRoutes.call);
        return;
      }
      if (next.phase.isTerminal || next.phase == CallPhase.idle) {
        _handled = true;
        ref.read(activeCallControllerProvider.notifier).reset();
        if (AppNavigation.canPop()) {
          AppNavigation.pop<void>();
        }
      }
    });

    final CallState state = ref.watch(activeCallControllerProvider);
    final ActiveCallController c = ref.read(
      activeCallControllerProvider.notifier,
    );

    // Stale-route guard: if this page is visible while nothing is ringing
    // (e.g. it was left under a call screen that just popped), leave.
    if (!_handled &&
        state.phase != CallPhase.incomingRinging &&
        state.phase != CallPhase.connecting &&
        state.phase != CallPhase.connected) {
      _handled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && AppNavigation.canPop()) {
          AppNavigation.pop<void>();
        }
      });
    }
    final String who = state.contact?.displayName ?? 'Rider';

    return Scaffold(
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
                glowing: true,
                coral: context.coral,
              ),
              const SizedBox(height: 34),
              Text(
                who,
                style: AppTextStyles.h1.copyWith(color: _kIvory, fontSize: 40),
              ),
              const SizedBox(height: 12),
              const Text(
                'Incoming free call…',
                style: TextStyle(color: _kIvoryDim, fontSize: 17),
              ),
              const Spacer(flex: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _AnswerAction(
                    color: context.coral,
                    icon: DrivioIcons.callEnd,
                    label: 'Decline',
                    onTap: () => unawaited(c.decline()),
                  ),
                  _AnswerAction(
                    color: const Color(0xFF2FA36B),
                    icon: DrivioIcons.phone,
                    label: 'Accept',
                    onTap: () => unawaited(c.answer()),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerAction extends StatelessWidget {
  const _AnswerAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 82,
            height: 82,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, size: 34, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: _kIvoryDim, fontSize: 14)),
      ],
    );
  }
}
