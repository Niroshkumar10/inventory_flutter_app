import 'package:cloud_firestore/cloud_firestore.dart'; // ← ADD THIS


class Supplier {
  String id;
  String name;
  String phone;
  String email;
  String address;
  String userMobile; // Owner of this supplier
  DateTime createdAt;
  DateTime updatedAt;

  Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.userMobile,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create new supplier for current user
  factory Supplier.create({
    required String name,
    required String phone,
    required String userMobile,
    String email = '',
    String address = '',
  }) {
    final now = DateTime.now();
    return Supplier(
      id: '', // Will be set when added to Firestore
      name: name,
      phone: phone,
      email: email,
      address: address,
      userMobile: userMobile,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'userMobile': userMobile,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map, String id) {
    return Supplier(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      userMobile: map['userMobile'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Supplier copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      userMobile: userMobile,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}