import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web platform not configured for Firebase.');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          '${defaultTargetPlatform.name} is not supported.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD09ztuxeNS_tXcnE2E8hMstL8oXQ9ghpM',
    appId: '1:986052833183:android:9b98e5c7cdf35865b917aa',
    messagingSenderId: '986052833183',
    projectId: 'f1-iq-2026',
    storageBucket: 'f1-iq-2026.firebasestorage.app');
}
