import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';

class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final ThemeModeController c = ref.read(themeModeProvider.notifier);
    return DetailScaffold(
      title: 'Appearance',
      subtitle: "Pick how Drivio looks. Dark works best behind a wheel.",
      children: <Widget>[
        DetailGroup(
          title: 'THEME',
          children: <Widget>[
            _ModeRow(
              title: 'Match my system',
              subtitle: 'Follow the device theme automatically.',
              icon: Icons.brightness_auto_rounded,
              selected: mode == ThemeMode.system,
              onTap: () => c.followSystem(),
            ),
            _Divider(),
            _ModeRow(
              title: 'Light',
              subtitle: 'Bright UI for daytime use.',
              icon: Icons.light_mode_rounded,
              selected: mode == ThemeMode.light,
              onTap: () => c.setMode(ThemeMode.light),
            ),
            _Divider(),
            _ModeRow(
              title: 'Dark',
              subtitle: 'Easy on the eyes through a windscreen.',
              icon: Icons.dark_mode_rounded,
              selected: mode == ThemeMode.dark,
              onTap: () => c.setMode(ThemeMode.dark),
              isLast: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeRow extends ConsumerWidget {
  const _ModeRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(14))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: AppDurations.fast,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? context.accent.withValues(alpha: 0.18)
                    : context.surface3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? context.accent.withValues(alpha: 0.45)
                      : Colors.transparent,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 18,
                color: selected ? context.accent : context.textDim,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTextStyles.h3.copyWith(color: context.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(color: context.textDim),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _SelectionIndicator(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? context.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? context.accent : context.borderStrong,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Icon(Icons.check_rounded, size: 14, color: context.accentInk)
          : null,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(height: 1, color: context.border),
    );
  }
}
