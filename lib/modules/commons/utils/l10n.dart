import 'package:flutter/widgets.dart';

import 'package:drivio_driver/l10n/gen/app_localizations.dart';

export 'package:drivio_driver/l10n/gen/app_localizations.dart';

/// Shorthand for the generated localizations: `context.l10n.helpTitle`.
/// New user-facing strings belong in `lib/l10n/app_en.arb`, not inline.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
