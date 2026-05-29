import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBrxM2EcenCmPOtobsy8Zrjhmdqve7ijWI',
    appId: '1:427747618567:web:6b129084151a2bd3f15fa2',
    messagingSenderId: '427747618567',
    projectId: 'tijuana-barreras-gdg-chdv',
    authDomain: 'tijuana-barreras-gdg-chdv.firebaseapp.com',
    storageBucket: 'tijuana-barreras-gdg-chdv.firebasestorage.app',
    measurementId: 'G-E21JY98H0Q',
  );

  

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDqYwu5A4rBjOyd2kjuvhdHCpy-zXANdD8',
    appId: '1:427747618567:android:71d49756d45deaa8f15fa2',
    messagingSenderId: '427747618567',
    projectId: 'tijuana-barreras-gdg-chdv',
    storageBucket: 'tijuana-barreras-gdg-chdv.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBrxM2EcenCmPOtobsy8ZrjhmdqvE7ijWI',
    appId: '1:427747618567:ios:tijuana-barreras-gdg-chdv',
    messagingSenderId: '427747618567',
    projectId: 'tijuana-barreras-gdg-chdv',
    storageBucket: 'tijuana-barreras-gdg-chdv.firebasestorage.app',
    iosBundleId: 'com.example.tijuanaSinBarreras',
  );
}