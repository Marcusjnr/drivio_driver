// Firebase options for the PROD flavor (project drivio-prod-f96f6).
// Values from the Firebase apps registered for the production bundle IDs.
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
    apiKey: 'AIzaSyBYJShQRhOKvGUj-s_LSvp4aP-Gbs-iFmA',
    appId: '1:528026822679:android:428ac2507d862f94c9d452',
    messagingSenderId: '528026822679',
    projectId: 'drivio-prod-f96f6',
    storageBucket: 'drivio-prod-f96f6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAYcnQ6dTPtUHPEY14Kxdz5su6mparWTYY',
    appId: '1:528026822679:ios:7174af28d714b42dc9d452',
    messagingSenderId: '528026822679',
    projectId: 'drivio-prod-f96f6',
    storageBucket: 'drivio-prod-f96f6.firebasestorage.app',
    iosBundleId: 'com.drivedrivio.drivio-driver',
  );
}
