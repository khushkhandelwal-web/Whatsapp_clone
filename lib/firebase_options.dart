
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAjXvUJuvBRf-x1mH1VuyHdNmS8ofrGHxE',
    appId: '1:870793547651:web:bc1234bc985ebe930470b6',
    messagingSenderId: '870793547651',
    projectId: 'second-fa840',
    authDomain: 'second-fa840.firebaseapp.com',
    databaseURL: 'https://second-fa840-default-rtdb.firebaseio.com',
    storageBucket: 'second-fa840.firebasestorage.app',
    measurementId: 'G-PL794JXNE5',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAgXFCtdTMI1qi-jRwWhR9a0XefdAp_Sfg',
    appId: '1:870793547651:ios:5440c1e20ec0b0fb0470b6',
    messagingSenderId: '870793547651',
    projectId: 'second-fa840',
    databaseURL: 'https://second-fa840-default-rtdb.firebaseio.com',
    storageBucket: 'second-fa840.firebasestorage.app',
    iosClientId: '870793547651-58llvf62acmghl88ndl71mdqp628jodm.apps.googleusercontent.com',
    iosBundleId: 'com.example.whatsappClone',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAgXFCtdTMI1qi-jRwWhR9a0XefdAp_Sfg',
    appId: '1:870793547651:ios:5440c1e20ec0b0fb0470b6',
    messagingSenderId: '870793547651',
    projectId: 'second-fa840',
    databaseURL: 'https://second-fa840-default-rtdb.firebaseio.com',
    storageBucket: 'second-fa840.firebasestorage.app',
    iosClientId: '870793547651-58llvf62acmghl88ndl71mdqp628jodm.apps.googleusercontent.com',
    iosBundleId: 'com.example.whatsappClone',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAjXvUJuvBRf-x1mH1VuyHdNmS8ofrGHxE',
    appId: '1:870793547651:web:fbaa1f8b3db5ca7d0470b6',
    messagingSenderId: '870793547651',
    projectId: 'second-fa840',
    authDomain: 'second-fa840.firebaseapp.com',
    databaseURL: 'https://second-fa840-default-rtdb.firebaseio.com',
    storageBucket: 'second-fa840.firebasestorage.app',
    measurementId: 'G-83F4BXX9HT',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCEMd2ZDYnxqHjw9hgeRv13gygEkcXUKKc',
    appId: '1:870793547651:android:abeb673e68cbc9ce0470b6',
    messagingSenderId: '870793547651',
    projectId: 'second-fa840',
    databaseURL: 'https://second-fa840-default-rtdb.firebaseio.com',
    storageBucket: 'second-fa840.firebasestorage.app',
  );

}