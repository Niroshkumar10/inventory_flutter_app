import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LedgerEntry {
  final String id;
  final String partyId;
  final String partyName;
  final String partyType;
  final DateTime date;
  final String type;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final String reference;
  final String notes;
  final String status;
  final String? createdBy;
  final DateTime? createdAt;

  LedgerEntry({
    required this.id,
    required this.partyId,
    required this.partyName,
    required this.partyType,
    required this.date,
    required this.type,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    this.reference = '',
    this.notes = '',
    this.status = 'pending',
    this.createdBy,
    this.createdAt,
  });

  // Factory constructor for creating new entries
  factory LedgerEntry.create({
    required String type,
    required String partyId,
    required String partyType,
    required String partyName,
    required String description,
    required double debit,
    required double credit,
    String reference = '',
    String notes = '',
    String status = 'pending',
    required String userMobile,
  }) {
    return LedgerEntry(
      id: '', // Will be assigned by Firestore
      partyId: partyId,
      partyName: partyName,
      partyType: partyType,
      date: DateTime.now(),
      type: type,
      description: description,
      debit: debit,
      credit: credit,
      balance: 0, // Will be calculated by service
      reference: reference,
      notes: notes,
      status: status,
      createdBy: userMobile,
      createdAt: DateTime.now(),
    );
  }

  // Factory method to create from map (for Firestore)
  factory LedgerEntry.fromMap(Map<String, dynamic> map, String documentId) {
    return LedgerEntry(
      id: documentId,
      partyId: map['partyId'] ?? '',
      partyName: map['partyName'] ?? '',
      partyType: map['partyType'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      debit: (map['debit'] ?? 0).toDouble(),
      credit: (map['credit'] ?? 0).toDouble(),
      balance: (map['balance'] ?? 0).toDouble(),
      reference: map['reference'] ?? '',
      notes: map['notes'] ?? '',
      status: map['status'] ?? 'pending',
      createdBy: map['createdBy'],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : null,
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'partyId': partyId,
      'partyName': partyName,
      'partyType': partyType,
      'date': Timestamp.fromDate(date),
      'type': type,
      'description': description,
      'debit': debit,
      'credit': credit,
      'balance': balance,
      'reference': reference,
      'notes': notes,
      'status': status,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  // Copy with method
  LedgerEntry copyWith({
    String? id,
    String? partyId,
    String? partyName,
    String? partyType,
    DateTime? date,
    String? type,
    String? description,
    double? debit,
    double? credit,
    double? balance,
    String? reference,
    String? notes,
    String? status,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      partyType: partyType ?? this.partyType,
      date: date ?? this.date,
      type: type ?? this.type,
      description: description ?? this.description,
      debit: debit ?? this.debit,
      credit: credit ?? this.credit,
      balance: balance ?? this.balance,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Helper getters for UI
  String get typeLabel {
    switch (type) {
      case 'sale':
        return 'Sale';
      case 'purchase':
        return 'Purchase';
      case 'payment':
        return 'Payment Received';
      case 'receipt':
        return 'Payment Made';
      default:
        return type;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'sale':
        return Icons.shopping_cart;
      case 'purchase':
        return Icons.shopping_bag;
      case 'payment':
        return Icons.download;
      case 'receipt':
        return Icons.upload;
      default:
        return Icons.receipt;
    }
  }

  Color get typeColor {
    switch (type) {
      case 'sale':
        return Colors.green;
      case 'purchase':
        return Colors.orange;
      case 'payment':
        return Colors.blue;
      case 'receipt':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Status color getter
  Color get statusColor {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'paid':
      case 'completed':
        return Colors.green;
      case 'pending':
      case 'due':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Status label getter
  String get statusLabel {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'paid':
      case 'completed':
        return 'Paid';
      case 'pending':
      case 'due':
        return 'Pending';
      case 'overdue':
        return 'Overdue';
      case 'cancelled':
        return 'Cancelled';
      default:
        if (status.isEmpty) return '';
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  bool isDebit() {
    return type == 'sale' || type == 'payment';
  }

  double get amount {
    return debit > 0 ? debit : credit;
  }
}