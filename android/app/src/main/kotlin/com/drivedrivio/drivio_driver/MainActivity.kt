package com.drivedrivio.drivio_driver

import io.flutter.embedding.android.FlutterFragmentActivity

// Extends `FlutterFragmentActivity` (not `FlutterActivity`) because
// `local_auth_android`'s BiometricPrompt is hosted as a fragment. With a
// plain `FlutterActivity`, `authenticate(...)` throws
// `PlatformException(no_fragment_activity)` and the biometric sign-in
// and the Settings toggle silently fail. `FlutterFragmentActivity` is
// still an `Activity`, so every other plugin keeps working.
// Same reason kalabash_mobile_v2 does it.
class MainActivity : FlutterFragmentActivity()
