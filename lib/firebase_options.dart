import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return web; // <--- Принудительно используем Web-конфиг для Windows, чтобы приложение не падало!
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDuPX1R3pYAICqTEnAnR8nU1qy3cnA0rAQ',
    appId: '1:1058899397110:web:fca47fe627b1aa6abf5fd7',
    messagingSenderId: '1058899397110',
    projectId: 'mserviceapp-79557',
    authDomain: 'mserviceapp-79557.firebaseapp.com',
    storageBucket: 'mserviceapp-79557.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDuPX1R3pYAICqTEnAnR8nU1qy3cnA0rAQ',
    appId: '1:1058899397110:android:335c9832bfcfba75bf5fd7',
    messagingSenderId: '1058899397110',
    projectId: 'mserviceapp-79557',
    storageBucket: 'mserviceapp-79557.firebasestorage.app',
  );
}
