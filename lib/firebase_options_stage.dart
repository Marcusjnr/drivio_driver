// Firebase options for the STAGING flavor (project drivio-staging).
// Values from the Firebase apps registered for the .beta bundle IDs.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions are not configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDKv1ibkXMK-PU89LeIGRAh23Vlx6S2MRM',
    appId: '1:420264149110:android:b5682d64655b5cc79e5f57',
    messagingSenderId: '420264149110',
    projectId: 'drivio-staging',
    storageBucket: 'drivio-staging.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAVCzOPWvKsnyllTmRzR9OSk_soHASpi9c',
    appId: '1:420264149110:ios:40e7339f1aa5067d9e5f57',
    messagingSenderId: '420264149110',
    projectId: 'drivio-staging',
    storageBucket: 'drivio-staging.firebasestorage.app',
    iosBundleId: 'com.drivedrivio.drivio-driver.beta',
  );
}
