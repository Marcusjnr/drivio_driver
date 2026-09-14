import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';

enum DriverTab { drive, earnings, pricing, support, profile }

class DriverTabBar extends ConsumerWidget {
  const DriverTabBar({super.key, required this.active, this.onSelect});

  final DriverTab active;
  final ValueChanged<DriverTab>? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<_Tab> tabs = const <_Tab>[
      _Tab(id: DriverTab.drive, label: 'Drive', icon: DrivioIcons.car, route: AppRoutes.home),
      _Tab(id: DriverTab.earnings, label: 'Earnings', icon: DrivioIcons.trendingUp, route: AppRoutes.earnings),
      _Tab(id: DriverTab.pricing, label: 'Pricing', icon: DrivioIcons.bolt, route: AppRoutes.pricing),
      _Tab(id: DriverTab.support, label: 'Support', icon: DrivioIcons.chat, route: AppRoutes.supportChat),
      // Profile moved to the top-left of the Drive screen — no longer a
      // bottom-nav tab. Enum value kept so pages can still mark it active.
      // _Tab(id: DriverTab.profile, label: 'Profile', icon: DrivioIcons.user, route: AppRoutes.profileHub),
    ];
    // ScreenScaffold wraps pages in SafeArea(bottom: false), so this bar
    // sits flush against the physical screen edge and must clear the
    // system navigation itself. The old fixed 14px was fine on notchless
    // phones but left the tabs half-covered by gesture bars (~24–34px)
    // and 3-button navigation (~48px). Grow the bar by the real inset;
    // keep 14px as the floor so inset-less devices still get breathing
    // room and the bar never gets shorter than it was.
    final double systemInset = MediaQuery.paddingOf(context).bottom;
    final double bottomPad = systemInset > 14 ? systemInset : 14;
    return Container(
      height: (AppDimensions.tabBarHeight - 14) + bottomPad,
      decoration: BoxDecoration(
        color: context.bg.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: context.border)),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Row(
        children: tabs.map((_Tab t) {
          final bool isActive = t.id == active;
          final Color color = isActive ? context.accent : context.textMuted;
          return Expanded(
            child: InkWell(
              onTap: () {
                if (onSelect != null) {
                  onSelect!(t.id);
                  return;
                }
                if (!isActive) {
                  AppNavigation.replace<void, void>(t.route);
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(t.icon, size: 22, color: color),
                  const SizedBox(height: 2),
                  Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Tab {
  const _Tab({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
  });
  final DriverTab id;
  final String label;
  final IconData icon;
  final String route;
}
