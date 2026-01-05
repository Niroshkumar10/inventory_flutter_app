import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LedgerEntry {
  String id;
  DateTime date;
  String type; // 'sale', 'purchase', 'payment', 'receipt'
  String partyId;
  String partyType; // 'customer', 'supplier'
  String partyName;
  String description;
  double debit;
  double credit;
  double balance;
  String reference;
  String notes;
  String userMobile;
  String status; // 'paid', 'pending', 'cancelled'

  LedgerEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.partyId,
    required this.partyType,
    required this.partyName,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    required this.reference,
    required this.notes,
    required this.userMobile,
    this.status = 'completed',
  });

  // Factory constructor for creating new entries
  factory LedgerEntry.create({
    required String type,
    required String partyId,
    required String partyType,
    required String partyName,
    required String description,
    double debit = 0,
    double credit = 0,
    String reference = '',
    String notes = '',
    required String userMobile,
    String status = 'completed',
  }) {
    return LedgerEntry(
      id: '',
      date: DateTime.now(),
      type: type,
      partyId: partyId,
      partyType: partyType,
      partyName: partyName,
      description: description,
      debit: debit,
      credit: credit,
      balance: 0, // Will be calculated when saving
      reference: reference,
      notes: notes,
      userMobile: userMobile,
      status: status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': FieldValue.serverTimestamp(),
      'type': type,
      'partyId': partyId,
      'partyType': partyType,
      'partyName': partyName,
      'description': description,
      'debit': debit,
      'credit': credit,
      'balance': balance,
      'reference': reference,
      'notes': notes,
      'userMobile': userMobile,
      'status': status,
    };
  }

  factory LedgerEntry.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      if (date is DateTime) return date;
      if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
      return DateTime.now();
    }

    return LedgerEntry(
      id: documentId,
      date: parseDate(map['date']),
      type: map['type']?.toString() ?? '',
      partyId: map['partyId']?.toString() ?? '',
      partyType: map['partyType']?.toString() ?? '',
      partyName: map['partyName']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      debit: (map['debit'] as num?)?.toDouble() ?? 0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      reference: map['reference']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      userMobile: map['userMobile']?.toString() ?? '',
      status: map['status']?.toString() ?? 'completed',
    );
  }

  LedgerEntry copyWith({
    String? id,
    DateTime? date,
    String? type,
    String? partyId,
    String? partyType,
    String? partyName,
    String? description,
    double? debit,
    double? credit,
    double? balance,
    String? reference,
    String? notes,
    String? userMobile,
    String? status,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      type: type ?? this.type,
      partyId: partyId ?? this.partyId,
      partyType: partyType ?? this.partyType,
      partyName: partyName ?? this.partyName,
      description: description ?? this.description,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      balance: balance ?? this.balance,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      userMobile: userMobile ?? this.userMobile,
      status: status ?? this.status,
    );
  }

  // Helper methods
  double get amount => debit > 0 ? debit : credit;
  
  bool isDebit() => debit > 0;
  bool isCredit() => credit > 0;
  
  String get typeLabel {
    switch (type) {
      case 'sale': return 'Sale';
      case 'purchase': return 'Purchase';
      case 'payment': return 'Payment Received';
      case 'receipt': return 'Payment Made';
      default: return type;
    }
  }
  
  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return 'Paid';
      case 'pending':
      case 'due':
        return 'Pending';
      case 'cancelled':
      case 'void':
        return 'Cancelled';
      default:
        return status;
    }
  }
  
  Color get typeColor {
    switch (type) {
      case 'sale': return Colors.green;
      case 'payment': return Colors.green;
      case 'purchase': return Colors.orange;
      case 'receipt': return Colors.red;
      default: return Colors.grey;
    }
  }
  
  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return Colors.green;
      case 'pending':
      case 'due':
        return Colors.orange;
      case 'cancelled':
      case 'void':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  IconData get typeIcon {
    switch (type) {
      case 'sale': return Icons.shopping_cart;
      case 'payment': return Icons.arrow_circle_down;
      case 'purchase': return Icons.inventory;
      case 'receipt': return Icons.arrow_circle_up;
      default: return Icons.receipt;
    }
  }
}

// Ledger Report Model
class LedgerReport {
  final String userMobile;
  final DateTime startDate;
  final DateTime endDate;
  final List<LedgerEntry> entries;
  final Map<String, double> summary;

  LedgerReport({
    required this.userMobile,
    required this.startDate,
    required this.endDate,
    required this.entries,
    required this.summary,
  });

  double get totalDebit => summary['totalDebit'] ?? 0;
  double get totalCredit => summary['totalCredit'] ?? 0;
  double get netBalance => summary['netBalance'] ?? 0;
  int get totalEntries => entries.length;
}