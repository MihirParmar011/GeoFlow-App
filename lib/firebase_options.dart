import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDC6TCgzPl8_3SUU59OYHYSboimZ8kpuYk',
    appId: '1:1011942886407:web:20a639fdc70ecfe6662ea2',
    messagingSenderId: '1011942886407',
    projectId: 'geoflow-011',
    authDomain: 'geoflow-011.firebaseapp.com',
    storageBucket: 'geoflow-011.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDC6TCgzPl8_3SUU59OYHYSboimZ8kpuYk',
    appId: '1:1011942886407:android:a9d46be3a6f3c7e2662ea2',
    messagingSenderId: '1011942886407',
    projectId: 'geoflow-011',
    storageBucket: 'geoflow-011.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDC6TCgzPl8_3SUU59OYHYSboimZ8kpuYk',
    appId: '1:1011942886407:ios:67c39f5a542edc13662ea2',
    messagingSenderId: '1011942886407',
    projectId: 'geoflow-011',
    storageBucket: 'geoflow-011.firebasestorage.app',
    iosBundleId: 'com.example.geoflow',
  );
}
