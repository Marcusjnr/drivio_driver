import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/widgets/detail_scaffold.dart';

/// Help & support: one channel, a real person on live chat. The page's
/// whole job is to get the driver into that chat with zero ceremony —
/// headline, the support line, one button. The chat opens in-app
/// (tawk.to WebView) already knowing the driver's name and email.
class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  static const String _phoneDisplay = '+234 906 846 3168';

  void _openChat() => AppNavigation.push<void>(AppRoutes.supportChat);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return DetailScaffold(
      title: l10n.helpTitle,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          l10n.helpEyebrow,
          style: AppTextStyles.eyebrow.copyWith(color: context.textDim),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.helpHeadline,
          style: AppTextStyles.displayLg.copyWith(
            color: context.text,
            fontSize: 30,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.helpBody,
          style: AppTextStyles.bodySm.copyWith(
            color: context.textDim,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),

        // The support line — tappable, same action as the button, and
        // the number is visible so drivers can save it.
        InkWell(
          onTap: _openChat,
          borderRadius: AppRadius.base.resolve(TextDirection.ltr),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: AppRadius.base,
              border: Border.all(color: context.border),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    DrivioIcons.chat,
                    size: 20,
                    color: context.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.helpSupportLineTitle,
                        style: AppTextStyles.bodySm.copyWith(
                          color: context.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _phoneDisplay,
                        style: AppTextStyles.captionSm.copyWith(
                          color: context.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Pill(text: l10n.helpWhatsAppPill, tone: PillTone.accent),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeight,
          child: FilledButton(
            onPressed: _openChat,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: AppRadius.base),
            ),
            child: Text(
              l10n.helpChatCta,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            l10n.helpTripHint,
            textAlign: TextAlign.center,
            style: AppTextStyles.captionSm.copyWith(color: context.textDim),
          ),
        ),
      ],
    );
  }
}
