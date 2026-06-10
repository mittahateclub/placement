import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Mirrors the web app's AuthContext: Firebase Auth session + the
/// `users/{uid}` profile document (role, university, name, photo).
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<User?>? _sub;

  User? user;
  String? role;
  String? universityId;
  String? universityName;
  String? userName;
  String? userPhotoUrl;
  bool loading = true;

  bool get isStudent => role == 'student' || role == 'user' || role == null;
  bool get isUniAdmin => role == 'university_admin';
  bool get isSuperAdmin => role == 'super_admin';

  AuthService() {
    _sub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? firebaseUser) async {
    user = firebaseUser;
    if (firebaseUser != null) {
      await refreshProfile();
    } else {
      role = null;
      universityId = null;
      universityName = null;
      userName = null;
      userPhotoUrl = null;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final firebaseUser = user;
    if (firebaseUser == null) return;
    try {
      final doc =
          await _db.collection('users').doc(firebaseUser.uid).get();
      final data = doc.data();
      role = (data?['role'] as String?) ?? 'student';
      universityId = data?['universityId'] as String?;
      universityName = data?['universityName'] as String?;
      userName = data?['name'] as String?;
      userPhotoUrl = data?['photoURL'] as String?;
    } catch (_) {
      role = 'student';
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  /// Creates a Firebase Auth user without replacing the current admin
  /// session, by using a secondary Firebase app instance.
  Future<String> createManagedAccount({
    required String email,
    required String password,
  }) async {
    final secondary = await Firebase.initializeApp(
      name: 'account-factory',
      options: Firebase.app().options,
    );
    try {
      final cred = await FirebaseAuth.instanceFor(app: secondary)
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;
      await FirebaseAuth.instanceFor(app: secondary).signOut();
      return uid;
    } finally {
      await secondary.delete();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
