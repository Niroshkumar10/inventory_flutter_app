import 'package:cloud_firestore/cloud_firestore.dart';

class Sale {
  final String id;
  final String customerId;
  final String customerName;
  final double totalAmount;
  final double paidAmount;
  final DateTime date;

  Sale({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.totalAmount,
    required this.paidAmount,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'date': date,
    };
  }

  factory Sale.fromMap(String id, Map<String, dynamic> map) {
    return Sale(
      id: id,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
    );
  }
}
