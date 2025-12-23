import 'package:cloud_firestore/cloud_firestore.dart';

class Purchase {
  final String id;
  final String supplierId;
  final String supplierName;
  final double totalAmount;
  final double paidAmount;
  final DateTime date;

  Purchase({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.totalAmount,
    required this.paidAmount,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'supplierName': supplierName,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'date': date,
    };
  }

  factory Purchase.fromMap(String id, Map<String, dynamic> map) {
    return Purchase(
      id: id,
      supplierId: map['supplierId'] ?? '',
      supplierName: map['supplierName'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
    );
  }
}
