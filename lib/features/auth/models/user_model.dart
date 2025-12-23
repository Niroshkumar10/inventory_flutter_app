// lib/features/auth/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String mobile;
  final String name;
  final String location;
  final DateTime createdAt;

  UserModel({
    required this.userId,
    required this.mobile,
    required this.name,
    required this.location,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'mobile': mobile,
      'name': name,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId'] ?? '',
      mobile: map['mobile'] ?? '',
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}