import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

class LiveDot extends ConsumerStatefulWidget {
  const LiveDot({super.key, this.color, this.size = 10});

  final Color? color;
  final double size;

  @override
  ConsumerState<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends ConsumerState<LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color c = widget.color ?? context.accent;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          AnimatedBuilder(
            animation: _ctrl,
            builder: (BuildContext _, Widget? __) {
              final double t = _ctrl.value;
              return Opacity(
                opacity: (1 - t) * 0.6,
                child: Transform.scale(
                  scale: 1 + t * 1.6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: widget.size * 0.7,
            height: widget.size * 0.7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
