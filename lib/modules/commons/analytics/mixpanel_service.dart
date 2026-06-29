import 'dart:async';

import 'package:drivio_driver/modules/commons/config/env.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

/// Thin wrapper around the Mixpanel SDK. Initialised once at startup from
/// the token + server URL in `.env` (see [Env]). While the token is still
/// the placeholder it stays a no-op, so the app runs fine until real keys
/// are dropped in. Resolve with `locator<MixpanelService>()`.
class MixpanelService {
  Mixpanel? _mixpanel;

  /// The underlying SDK instance, or null until configured + initialised.
  Mixpanel? get instance => _mixpanel;
  bool get isReady => _mixpanel != null;

  /// Placeholder shipped in `.env`; swapped for a real token before launch.
  static const String _placeholderToken = 'YOUR_MIXPANEL_PROJECT_TOKEN';

  /// Identifies this app + environment on every event (super properties).
  static const String appType = 'driver';
  static const String environment = 'production';

  Future<void> init() async {
    final String token = Env.mixpanelToken.trim();
    if (token.isEmpty || token == _placeholderToken) {
      // Not configured yet — skip init so nothing is sent with a fake token.
      return;
    }

    _mixpanel = await Mixpanel.init(token, trackAutomaticEvents: true);

    final String serverUrl = Env.mixpanelServerUrl.trim();
    if (serverUrl.isNotEmpty) {
      _mixpanel!.setServerURL(serverUrl);
    }

    // Attached to every event sent from this app.
    unawaited(_mixpanel!.registerSuperProperties(<String, dynamic>{
      'app_type': appType,
      'environment': environment,
    }));
  }

  void track(String event, {Map<String, dynamic>? properties}) {
    _mixpanel?.track(event, properties: properties);
  }

  /// Tie events to a (hashed) user and optionally stamp profile props. Call
  /// right after authentication resolves.
  void identifyUser(String distinctId, {Map<String, dynamic>? profile}) {
    final Mixpanel? mp = _mixpanel;
    if (mp == null) {
      return;
    }
    unawaited(mp.identify(distinctId));
    if (profile != null) {
      setProfile(profile);
    }
  }

  /// Update evolving Mixpanel People properties.
  void setProfile(Map<String, dynamic> props) {
    final People? people = _mixpanel?.getPeople();
    if (people == null) {
      return;
    }
    props.forEach(people.set);
  }

  /// Set first-touch People properties (signup date, KYC, etc.).
  void setProfileOnce(Map<String, dynamic> props) {
    final People? people = _mixpanel?.getPeople();
    if (people == null) {
      return;
    }
    props.forEach(people.setOnce);
  }

  void registerSuperProperties(Map<String, dynamic> props) {
    _mixpanel?.registerSuperProperties(props);
  }

  void reset() {
    _mixpanel?.reset();
  }
}
