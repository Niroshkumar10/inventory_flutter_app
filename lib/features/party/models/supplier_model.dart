//./lib/features/party/models/supplier_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  String id;
  String name;
  String phone;
  String email;
  String address;
  String userMobile; // Owner of this supplier
  DateTime createdAt;
  DateTime updatedAt;
  final bool isActive;
  
  // New location fields
  double? latitude;
  double? longitude;
  String? locationAddress; // Formatted address from coordinates

  Supplier({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.userMobile,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.latitude,
    this.longitude,
    this.locationAddress,
  });

  // Create new supplier for current user
  factory Supplier.create({
    required String name,
    required String phone,
    required String userMobile,
    String email = '',
    String address = '',
    double? latitude,
    double? longitude,
    String? locationAddress,
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
      latitude: latitude,
      longitude: longitude,
      locationAddress: locationAddress,
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
      'isActive': isActive,
      'latitude': latitude,
      'longitude': longitude,
      'locationAddress': locationAddress,
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
      isActive: map['isActive'] ?? true,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      locationAddress: map['locationAddress'],
    );
  }

  Supplier copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
    double? latitude,
    double? longitude,
    String? locationAddress,
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
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAddress: locationAddress ?? this.locationAddress,
    );
  }
  
  // Helper to check if location is available
  bool get hasLocation => latitude != null && longitude != null;
}