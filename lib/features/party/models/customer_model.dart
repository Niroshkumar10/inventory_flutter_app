// ./lib/features/party/models/customer_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String mobile;
  final String address;
  final String userMobile;
  final DateTime createdAt;
  final bool isActive;
  
  // New location fields
  final double? latitude;
  final double? longitude;
  final String? locationAddress; // Formatted address from coordinates

  Customer({
    required this.id,
    required this.name,
    required this.mobile,
    required this.address,
    required this.userMobile,
    required this.createdAt,
    this.isActive = true,
    this.latitude,
    this.longitude,
    this.locationAddress,
  });

  // Create new customer for current user
  factory Customer.create({
    required String name,
    required String mobile,
    required String userMobile,
    String address = '',
    double? latitude,
    double? longitude,
    String? locationAddress,
  }) {
    return Customer(
      id: '',
      name: name,
      mobile: mobile,
      address: address,
      userMobile: userMobile,
      createdAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      locationAddress: locationAddress,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mobile': mobile,
      'address': address,
      'userMobile': userMobile,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
      'latitude': latitude,
      'longitude': longitude,
      'locationAddress': locationAddress,
    };
  }

  static Customer fromMap(Map<String, dynamic> map, String documentId) {
    // Helper function to parse date from Firestore
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      if (date is DateTime) return date;
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      if (date is String) {
        try {
          return DateTime.parse(date);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return Customer(
      id: documentId,
      name: map['name']?.toString() ?? '',
      mobile: map['mobile']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      userMobile: map['userMobile']?.toString() ?? '',
      createdAt: parseDate(map['createdAt']),
      isActive: map['isActive'] ?? true,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      locationAddress: map['locationAddress'],
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? mobile,
    String? address,
    String? userMobile,
    DateTime? createdAt,
    bool? isActive,
    double? latitude,
    double? longitude,
    String? locationAddress,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      userMobile: userMobile ?? this.userMobile,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAddress: locationAddress ?? this.locationAddress,
    );
  }
  
  // Helper to check if location is available
  bool get hasLocation => latitude != null && longitude != null;
}