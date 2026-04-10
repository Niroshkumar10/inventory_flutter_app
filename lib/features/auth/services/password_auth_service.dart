// lib/features/auth/services/password_auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class PasswordAuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Hash password using SHA-256 (for demo - use stronger hashing in production)
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Set/Update password for existing user
  Future<bool> setPassword(String mobile, String password) async {
    try {
      final hashedPassword = _hashPassword(password);
      await _db.collection('users').doc(mobile).update({
        'password': hashedPassword,
        'hasPassword': true,
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error setting password: $e');
      return false;
    }
  }

  /// Verify password for login
  Future<bool> verifyPassword(String mobile, String password) async {
    try {
      final doc = await _db.collection('users').doc(mobile).get();
      
      if (!doc.exists) {
        return false;
      }

      final userData = doc.data();
      final storedHash = userData?['password'];
      
      if (storedHash == null) {
        return false; // User doesn't have password set
      }

      final inputHash = _hashPassword(password);
      return storedHash == inputHash;
    } catch (e) {
      print('Error verifying password: $e');
      return false;
    }
  }

  /// Check if user has password set
  Future<bool> hasPassword(String mobile) async {
    try {
      final doc = await _db.collection('users').doc(mobile).get();
      return doc.exists && doc.data()?['password'] != null;
    } catch (e) {
      return false;
    }
  }
}