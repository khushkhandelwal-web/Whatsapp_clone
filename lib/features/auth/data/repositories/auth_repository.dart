import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User> signInWithEmail(String email, String password) async {
    final c = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password.trim());
    await _saveUser(c.user!);
    return c.user!;
  }

  Future<User> signUpWithEmail(String email, String password) async {
    final c = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password.trim());
    await _saveUser(c.user!);
    return c.user!;
  }

  Future<User> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    final c = await _auth.signInWithPopup(provider);
    await _saveUser(c.user!);
    return c.user!;
  }

  Future<void> signOut() async {
    await _setPresence(online: false);
    await _auth.signOut();
  }

  Future<void> _saveUser(User u) async {
    await _db.collection('users').doc(u.uid).set({
      'uid':   u.uid,
      'email': u.email ?? '',
      'name':  u.displayName ?? u.email!.split('@')[0],
    }, SetOptions(merge: true));
    await _setPresence(online: true);
  }

  Future<void> _setPresence({required bool online}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('presence').doc(uid).set({
      'uid':      uid,
      'online':   online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}