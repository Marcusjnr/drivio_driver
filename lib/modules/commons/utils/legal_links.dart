import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';

import 'package:drivio_driver/modules/commons/notifications/app_notifier.dart';
import 'package:drivio_driver/modules/commons/theme/app_colors.dart';

/// Legal document links, opened in an in-app browser (Custom Tabs on
/// Android, SFSafariViewController on iOS) so the driver never leaves
/// the app mid-flow.
class LegalLinks {
  LegalLinks._();

  static const String termsUrl = 'https://www.drivedrivio.com/terms';
  static const String privacyUrl = 'https://www.drivedrivio.com/privacy';

  static Future<void> openTerms(BuildContext context) =>
      _open(context, termsUrl);

  static Future<void> openPrivacy(BuildContext context) =>
      _open(context, privacyUrl);

  static Future<void> _open(BuildContext context, String url) async {
    try {
      await launchUrl(
        Uri.parse(url),
        customTabsOptions: const CustomTabsOptions(
          colorSchemes: CustomTabsColorSchemes(
            defaultPrams: CustomTabsColorSchemeParams(
              toolbarColor: AppColors.charcoalTeal,
            ),
          ),
          showTitle: true,
          urlBarHidingEnabled: true,
        ),
        safariVCOptions: const SafariViewControllerOptions(
          preferredBarTintColor: AppColors.charcoalTeal,
          preferredControlTintColor: AppColors.ivory,
          barCollapsingEnabled: true,
          dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        ),
      );
    } catch (_) {
      AppNotifier.error(message: "Couldn't open the page. Try again.");
    }
  }
}
