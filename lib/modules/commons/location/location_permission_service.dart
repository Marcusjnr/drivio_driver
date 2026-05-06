import 'package:geolocator/geolocator.dart';

/// Normalised view of "can we use the device's location right now?"
/// Wraps the noisier `LocationPermission` + `isLocationServiceEnabled`
/// dance so callers don't need to reason about both. Returned by
/// [LocationPermissionService].
enum LocationPermState {
  /// Initial value — no check has run yet.
  unknown,

  /// User has granted while-in-use or always permission AND device
  /// location services are on. Streaming can start.
  granted,

  /// User declined this time but can be asked again.
  denied,

  /// User picked "Don't ask again" / iOS denied-forever. The OS won't
  /// surface a prompt to us anymore — the only path to re-grant is
  /// the system Settings app.
  permanentlyDenied,

  /// App-level permission may be fine, but device location services
  /// are disabled (airplane / GPS toggle off). Caller should ask the
  /// driver to flip the system toggle.
  serviceDisabled;

  /// True when the app has everything it needs to start streaming.
  bool get isUsable => this == LocationPermState.granted;
}

/// Single point of contact for location-permission state. Splash uses
/// it to ask up-front; the online-toggle uses it as a gate when the
/// driver tries to start a shift without permission.
class LocationPermissionService {
  const LocationPermissionService();

  /// Read the current permission + service state without prompting
  /// the user. Safe to call from any rebuild — pure status check.
  Future<LocationPermState> currentState() async {
    final bool service = await Geolocator.isLocationServiceEnabled();
    final LocationPermission perm = await Geolocator.checkPermission();
    return _normalise(perm, service);
  }

  /// Triggers the system permission prompt (no-op if already
  /// granted or permanently denied — those paths return the current
  /// status). Resolves once the user has dismissed the dialog.
  Future<LocationPermState> request() async {
    final bool service = await Geolocator.isLocationServiceEnabled();
    if (!service) return LocationPermState.serviceDisabled;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return _normalise(perm, service);
  }

  /// Open the platform's app-settings screen so a permanently-denied
  /// driver can flip the toggle manually. Returns true if the deep-
  /// link succeeded.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Same idea but for the device's location-services screen.
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static LocationPermState _normalise(
    LocationPermission perm,
    bool serviceEnabled,
  ) {
    if (!serviceEnabled) return LocationPermState.serviceDisabled;
    switch (perm) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermState.granted;
      case LocationPermission.deniedForever:
        return LocationPermState.permanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationPermState.denied;
    }
  }
}
