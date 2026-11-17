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
    apiKey: 'AIzaSyAPRCI3zZxN4GjD3O2XVAtG5D0RmgYyagE',
    appId: '1:529380866939:web:968170d053e18d88791bde',
    messagingSenderId: '529380866939',
    projectId: 'xo-neon-online',
    authDomain: 'xo-neon-online.firebaseapp.com',
    databaseURL: 'https://xo-neon-online-default-rtdb.firebaseio.com',
    storageBucket: 'xo-neon-online.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBax8MOmBZVLZuQUzyzkBo0P1vg0SzTLTo',
    appId: '1:529380866939:android:e24155eb01c74fa7791bde',
    messagingSenderId: '529380866939',
    projectId: 'xo-neon-online',
    databaseURL: 'https://xo-neon-online-default-rtdb.firebaseio.com',
    storageBucket: 'xo-neon-online.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD6zysK9TXdt1TPWR7Yaq4GHAbVyAmHMSI',
    appId: '1:529380866939:ios:fd681c04adad0965791bde',
    messagingSenderId: '529380866939',
    projectId: 'xo-neon-online',
    databaseURL: 'https://xo-neon-online-default-rtdb.firebaseio.com',
    storageBucket: 'xo-neon-online.appspot.com',
    iosBundleId: 'com.antigravity.xo.xoNeonApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAPRCI3zZxN4GjD3O2XVAtG5D0RmgYyagE',
    appId: '1:529380866939:web:968170d053e18d88791bde',
    messagingSenderId: '529380866939',
    projectId: 'xo-neon-online',
    authDomain: 'xo-neon-online.firebaseapp.com',
    databaseURL: 'https://xo-neon-online-default-rtdb.firebaseio.com',
    storageBucket: 'xo-neon-online.appspot.com',
  );
}
