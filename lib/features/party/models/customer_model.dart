import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String mobile;
  final String address;
  final String userMobile;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.mobile,
    required this.address,
    required this.userMobile,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'address': address,
      'userMobile': userMobile,
      'createdAt': FieldValue.serverTimestamp(), // Use FieldValue for Firestore
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
      createdAt: parseDate(map['createdAt']), // Use the parser
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? mobile,
    String? address,
    String? userMobile,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      userMobile: userMobile ?? this.userMobile,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}