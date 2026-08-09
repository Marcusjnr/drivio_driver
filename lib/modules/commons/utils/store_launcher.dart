import 'package:url_launcher/url_launcher.dart';

import 'package:drivio_driver/modules/commons/logging/app_logger.dart';
import 'package:drivio_driver/modules/commons/notifications/app_notifier.dart';

/// Opens the app's store listing in the store app itself (external mode,
/// so Play Store / App Store handles it rather than an in-app WebView).
/// Surfaces a friendly error instead of throwing: this is called from the
/// forced-update screen where an unhandled failure would strand the user.
Future<void> openStoreListing(String url) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || url.trim().isEmpty) {
    AppLogger.w('openStoreListing: bad url', data: <String, dynamic>{'url': url});
    AppNotifier.error(message: "Couldn't open the store. Try again shortly.");
    return;
  }
  try {
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      AppNotifier.error(message: "Couldn't open the store. Try again shortly.");
    }
  } catch (e, st) {
    AppLogger.w('openStoreListing failed', error: e, stackTrace: st);
    AppNotifier.error(message: "Couldn't open the store. Try again shortly.");
  }
}
