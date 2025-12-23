import 'package:cloud_firestore/cloud_firestore.dart';

class Ledger {
  String id;
  String customerId; // optional if supplier
  String supplierId; // optional if customer
  DateTime date;
  String description;
  double debit;
  double credit;
  double balance;

  Ledger({
    required this.id,
    this.customerId = '',
    this.supplierId = '',
    required this.date,
    required this.description,
    this.debit = 0,
    this.credit = 0,
    this.balance = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'supplierId': supplierId,
      'date': date,
      'description': description,
      'debit': debit,
      'credit': credit,
      'balance': balance,
    };
  }

  factory Ledger.fromMap(Map<String, dynamic> map, String id) {
    return Ledger(
      id: id,
      customerId: map['customerId'] ?? '',
      supplierId: map['supplierId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      description: map['description'] ?? '',
      debit: map['debit']?.toDouble() ?? 0,
      credit: map['credit']?.toDouble() ?? 0,
      balance: map['balance']?.toDouble() ?? 0,
    );
  }
}
