import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase configuration for the shared UniShip backend
/// (same project as the web app: uniship-4c1a1).
class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'AIzaSyDuH4AWkiBm2Th1szxniBpL85B6eF5VgeA',
    authDomain: 'uniship-4c1a1.firebaseapp.com',
    projectId: 'uniship-4c1a1',
    storageBucket: 'uniship-4c1a1.firebasestorage.app',
    messagingSenderId: '1051779016295',
    appId: '1:1051779016295:web:a122849323d2fe29e696c2',
    measurementId: 'G-6BW6XCZP1F',
  );
}
