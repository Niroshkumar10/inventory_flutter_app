
// lib/features/auth/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String mobile;
  final String name;
  final String location;
    final String? password; // NEW: Add password field

  final DateTime createdAt;

  UserModel({
    required this.userId,
    required this.mobile,
    required this.name,
    required this.location,
        this.password, // NEW: Optional password

    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'mobile': mobile,
      'name': name,
      'location': location,
            if (password != null) 'password': password, // NEW: Only save if exists

      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId'] ?? '',
      mobile: map['mobile'] ?? '',
      name: map['name'] ?? '',
      location: map['location'] ?? '',
            password: map['password'], // NEW

      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}