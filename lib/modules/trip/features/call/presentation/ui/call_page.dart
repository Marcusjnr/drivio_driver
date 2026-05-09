import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

enum _CallState { ringing, active }

class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key});

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  _CallState _state = _CallState.ringing;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String mm = (_seconds ~/ 60).toString().padLeft(2, '0');
    final String ss = (_seconds % 60).toString().padLeft(2, '0');
    return ScreenScaffold(
      background: const Color(0xFF0A0D10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Column(
              children: <Widget>[
                const SizedBox(height: 40),
                Text(
                  _state == _CallState.ringing
                      ? 'CALLING RIDER…'
                      : 'ON CALL',
                  style: AppTextStyles.eyebrow.copyWith(
                    color: context.textDim,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                const Avatar(name: 'Rider', variant: 3, size: 112),
                const SizedBox(height: 20),
                Text(
                  'Rider',
                  style: AppTextStyles.screenTitleSm
                      .copyWith(color: context.text),
                ),
                const SizedBox(height: 6),
                Text(
                  _state == _CallState.ringing ? 'Ringing…' : '$mm:$ss',
                  style: AppTextStyles.mono.copyWith(
                    fontSize: 14,
                    color: context.textDim,
                    letterSpacing: 1.2,
                  ),
                ),
                if (_state == _CallState.ringing) ...<Widget>[
                  const SizedBox(height: 16),
                  const _RingingDots(),
                ],
              ],
            ),
            Column(
              children: <Widget>[
                if (_state == _CallState.active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        _CircleBtn(icon: DrivioIcons.mute, label: 'Mute'),
                        _CircleBtn(icon: DrivioIcons.speaker, label: 'Speaker'),
                        _CircleBtn(icon: DrivioIcons.user, label: 'Keypad'),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    if (_state == _CallState.ringing) ...<Widget>[
                      _BigBtn(
                        bg: context.red,
                        icon: DrivioIcons.callEnd,
                        onTap: () => AppNavigation.pop(),
                      ),
                      _BigBtn(
                        bg: context.accent,
                        icon: DrivioIcons.check,
                        onTap: () {
                          setState(() => _state = _CallState.active);
                          _timer = Timer.periodic(const Duration(seconds: 1),
                              (Timer _) => setState(() => _seconds++));
                        },
                      ),
                    ] else
                      _BigBtn(
                        bg: context.red,
                        icon: DrivioIcons.callEnd,
                        onTap: () => AppNavigation.pop(),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Your number stays private. Both sides see a relay.',
                  style: AppTextStyles.captionSm
                      .copyWith(fontSize: 11, color: context.textDim),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingingDots extends ConsumerStatefulWidget {
  const _RingingDots();
  @override
  ConsumerState<_RingingDots> createState() => _RingingDotsState();
}

class _RingingDotsState extends ConsumerState<_RingingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (BuildContext _, Widget? __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (int i) {
            final double t = (_ctrl.value + i * 0.2) % 1;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: 0.3 + (1 - (t - 0.5).abs() * 2) * 0.7,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: context.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _CircleBtn extends ConsumerWidget {
  const _CircleBtn({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: context.surface,
            shape: BoxShape.circle,
            border: Border.all(color: context.border),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 22, color: context.text),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTextStyles.micro.copyWith(
            color: context.textDim,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _BigBtn extends StatelessWidget {
  const _BigBtn({required this.bg, required this.icon, required this.onTap});
  final Color bg;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Icon(icon, size: 24, color: Colors.white),
        ),
      ),
    );
  }
}
