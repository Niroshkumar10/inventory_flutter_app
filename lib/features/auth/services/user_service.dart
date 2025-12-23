// lib/features/auth/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  /// 🔐 Ensure Firebase Auth user exists
  Future<User> ensureAuthUser() async {
    if (_auth.currentUser != null) {
      return _auth.currentUser!;
    }

    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }

  /// 🔍 Check user exists by mobile
  Future<bool> userExists(String mobile) async {
    final query = await _db
        .collection('users')
        .where('mobile', isEqualTo: mobile)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  /// 🛡️ Ensure Firestore profile exists (FIX FOR YOUR ISSUE)
  Future<void> ensureUserProfile({
    required String uid,
    required String mobile,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'userId': uid,
        'mobile': mobile,
        'name': '',
        'location': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// 💾 Save new user
  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.userId).set(user.toMap());
  }
}
