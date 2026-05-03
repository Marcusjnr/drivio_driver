import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/navigation/app_navigation.dart';
import 'package:drivio_driver/modules/commons/theme/app_text_styles.dart';
import 'package:drivio_driver/modules/commons/theme/context_theme.dart';
import 'package:drivio_driver/modules/commons/widgets/back_button_box.dart';
import 'package:drivio_driver/modules/commons/widgets/screen_scaffold.dart';

class DetailScaffold extends ConsumerWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.footer,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
  });

  final String title;
  final String? subtitle;
  final Widget? badge;
  final Widget? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      bottomBar: footer == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: context.bg,
                border: Border(top: BorderSide(color: context.border)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: footer,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.border)),
            ),
            child: Row(
              children: <Widget>[
                BackButtonBox(onTap: () => AppNavigation.pop()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(color: context.text),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 11, color: context.textDim),
                        ),
                      ],
                    ],
                  ),
                ),
                if (badge != null) badge!,
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailGroup extends ConsumerWidget {
  const DetailGroup({
    super.key,
    required this.title,
    required this.children,
    this.topMargin = 16,
  });

  final String title;
  final List<Widget> children;
  final double topMargin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(top: topMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: AppTextStyles.eyebrow.copyWith(color: context.textDim)),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.border),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}
