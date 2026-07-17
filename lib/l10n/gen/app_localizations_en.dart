// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get helpTitle => 'Help & support';

  @override
  String get helpEyebrow => 'SUPPORT';

  @override
  String get helpHeadline => 'Talk to a real person.';

  @override
  String get helpBody =>
      'Our support team is one tap away, right inside the app. Start a chat about a trip, your earnings, your vehicle, or anything else. A person replies, not a bot.';

  @override
  String get helpSupportLineTitle => 'Drivio driver support';

  @override
  String get helpWhatsAppPill => 'LIVE CHAT';

  @override
  String get helpChatCta => 'Chat with support';

  @override
  String get helpTripHint =>
      'If it’s about a trip, include the rider’s name and the trip time so we can sort it out faster.';

  @override
  String get helpPrefillMessage =>
      'Hello Drivio, I\'m a driver and I need some help.';

  @override
  String get helpWhatsAppError => 'Couldn\'t open WhatsApp on this phone.';
}
