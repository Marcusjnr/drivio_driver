import 'package:flutter/material.dart';

import 'package:drivio_driver/modules/commons/notifications/app_notification_controller.dart';
import 'package:drivio_driver/modules/commons/notifications/app_notification_data.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';

/// Wraps the entire app and renders the active notification banner
/// over the top of [child], anchored below the safe area.
///
/// Mount this inside `MaterialApp.builder` so it has access to the
/// theme + media query — but ABOVE the route subtree, so the banner
/// stays put while pages animate beneath it.
class AppNotificationHost extends StatefulWidget {
  const AppNotificationHost({
    super.key,
    required this.controller,
    required this.child,
  });

  final AppNotificationController controller;
  final Widget child;

  @override
  State<AppNotificationHost> createState() => _AppNotificationHostState();
}

class _AppNotificationHostState extends State<AppNotificationHost>
    with SingleTickerProviderStateMixin {
  static const Duration _enter = Duration(milliseconds: 320);
  static const Duration _exit = Duration(milliseconds: 220);

  late final AnimationController _anim;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  AppNotificationData? _displayed;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: _enter,
      reverseDuration: _exit,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.65),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    widget.controller.current.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant AppNotificationHost old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.current.removeListener(_onChange);
      widget.controller.current.addListener(_onChange);
    }
  }

  void _onChange() {
    final AppNotificationData? next = widget.controller.current.value;
    if (next != null) {
      setState(() => _displayed = next);
      _anim.forward(from: 0);
    } else {
      _anim.reverse().whenComplete(() {
        if (!mounted) return;
        setState(() => _displayed = null);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.current.removeListener(_onChange);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppNotificationData? data = _displayed;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (data != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: true,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: SlideTransition(
                  position: _slide,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _NotificationBanner(
                          data: data,
                          onDismiss: widget.controller.hide,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({required this.data, required this.onDismiss});

  final AppNotificationData data;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final _Palette p = _paletteFor(context, data.type);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.border, width: 1),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(p.icon, color: p.iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (data.title != null && data.title!.trim().isNotEmpty) ...<Widget>[
                    Text(
                      data.title!,
                      style: TextStyle(
                        color: p.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    data.message,
                    style: TextStyle(
                      color: p.textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkResponse(
              onTap: onDismiss,
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 16, color: p.dimColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.bg,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.dimColor,
  });

  final Color bg;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final Color dimColor;
}

_Palette _paletteFor(BuildContext context, AppNotificationType type) {
  final bool dark = context.isDark;
  switch (type) {
    case AppNotificationType.success:
      return _Palette(
        bg: dark ? const Color(0xFF0E3B26) : const Color(0xFFDCFCE7),
        border: dark ? const Color(0xFF064E3B) : const Color(0xFFBBF7D0),
        icon: Icons.check_circle_rounded,
        iconColor: dark ? const Color(0xFFA7F3D0) : const Color(0xFF16A34A),
        textColor: dark ? const Color(0xFFD1FAE5) : const Color(0xFF064E3B),
        dimColor: dark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D),
      );
    case AppNotificationType.error:
      return _Palette(
        bg: dark ? const Color(0xFF3B0F0F) : const Color(0xFFFEE2E2),
        border: dark ? const Color(0xFF4F1414) : const Color(0xFFFECACA),
        icon: Icons.cancel_rounded,
        iconColor: dark ? const Color(0xFFFCA5A5) : const Color(0xFFEF4444),
        textColor: dark ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D),
        dimColor: dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
      );
    case AppNotificationType.warning:
      return _Palette(
        bg: dark ? const Color(0xFF3D2F07) : const Color(0xFFFEF9C3),
        border: dark ? const Color(0xFF78350F) : const Color(0xFFFEF08A),
        icon: Icons.warning_amber_rounded,
        iconColor: dark ? const Color(0xFFFEF08A) : const Color(0xFFEAB308),
        textColor: dark ? const Color(0xFFFEF08A) : const Color(0xFF713F12),
        dimColor: dark ? const Color(0xFFFDE68A) : const Color(0xFFA16207),
      );
    case AppNotificationType.info:
      return _Palette(
        bg: dark ? const Color(0xFF10283F) : const Color(0xFFE6F1FB),
        border: dark ? const Color(0xFF143A59) : const Color(0xFFCCE3F7),
        icon: Icons.info_rounded,
        iconColor: dark ? const Color(0xFF3BB4E6) : const Color(0xFF07478C),
        textColor: dark ? const Color(0xFFDBEAFE) : const Color(0xFF0C4A6E),
        dimColor: dark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
      );
    case AppNotificationType.neutral:
      return _Palette(
        bg: context.surface,
        border: context.borderStrong,
        icon: Icons.info_outline_rounded,
        iconColor: context.textDim,
        textColor: context.text,
        dimColor: context.textMuted,
      );
  }
}
