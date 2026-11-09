// File generated for default platform configuration.
// Can be updated/overwritten by running: flutterfire configure --project=xo-neon-online

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] used by [FirebaseService].
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
      case TargetPlatform.windows:
        return windows;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDemo-WebApiKeyPlaceholderForXoNeon',
    appId: '1:100000000000:web:abcdef1234567890',
    messagingSenderId: '100000000000',
    projectId: 'xo-neon-online',
    authDomain: 'xo-neon-online.firebaseapp.com',
    databaseURL: 'https://xo-neon-online-default-rtdb.firebaseio.com',
    storageBucket: 'xo-neon-online.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDemo-AndroidApiKeyPlaceholderForXoNeon',
    appId: '1:100000000000:android:abcdef1234567890',
    messagingSenderId: '100000000000',
    projectId: 'xo-neon-online',
    databaseURL: 'https://xo-neon-online-default-rtdb.firebaseio.com',
    storageBucket: 'xo-neon-online.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDemo-IosApiKeyPlaceholderForXoNeon',
    appId: '1:100000000000:ios:abcdef1234567890',
    messagingSenderId: '100000000000',
    projectId: 'xo-neon-online',
    databaseURL: 'https://xo-neon-online-default-rtdb.firebaseio.com',
    storageBucket: 'xo-neon-online.appspot.com',
    iosBundleId: 'com.antigravity.xo.xoNeonApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDemo-WindowsApiKeyPlaceholderForXoNeon',
    appId: '1:100000000000:web:abcdef1234567890',
    messagingSenderId: '100000000000',
    projectId: 'xo-neon-online',
    authDomain: 'xo-neon-online.firebaseapp.com',
    databaseURL: 'https://xo-neon-online-default-rtdb.firebaseio.com',
    storageBucket: 'xo-neon-online.appspot.com',
  );
}
