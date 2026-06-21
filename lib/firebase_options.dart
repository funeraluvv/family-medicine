import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAlkd6Lij5KbPHjdJnaKBhc0e5ee6pUp5Q',
    appId: '1:917025588783:android:8634cdba83941d99a4a8da',
    messagingSenderId: '917025588783',
    projectId: 'family-medicine-d5cac',
    storageBucket: 'family-medicine-d5cac.firebasestorage.app',
  );
}