// lib/features/bill/models/bill_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Bill {
  String id;
  String type; // 'sales', 'purchase'
  String invoiceNumber;
  DateTime date;
  String partyName; // Supplier for purchase, Customer for sales
  String partyPhone;
  String partyAddress;
  List<BillItem> items;
  double subtotal;
  double gstRate;
  double gstAmount;
  double totalAmount;
  double amountPaid;
  double amountDue;
  String paymentStatus; // 'paid', 'partial', 'due'
  bool isGST;
  String notes;
  String userMobile; // Owner of this bill
  DateTime createdAt;
  DateTime updatedAt;

  Bill({
    required this.id,
    required this.type,
    required this.invoiceNumber,
    required this.date,
    required this.partyName,
    required this.partyPhone,
    required this.partyAddress,
    required this.items,
    required this.subtotal,
    required this.gstRate,
    required this.gstAmount,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountDue,
    required this.paymentStatus,
    required this.isGST,
    required this.notes,
    required this.userMobile,
    required this.createdAt,
    required this.updatedAt,
  });

  // Create new bill for current user
  factory Bill.create({
    required String type,
    required String invoiceNumber,
    required String partyName,
    required String userMobile,
    String partyPhone = '',
    String partyAddress = '',
    List<BillItem> items = const [],
    double subtotal = 0.0,
    double gstRate = 0.0,
    double gstAmount = 0.0,
    double totalAmount = 0.0,
    double amountPaid = 0.0,
    double amountDue = 0.0,
    String paymentStatus = 'due',
    bool isGST = true,
    String notes = '',
  }) {
    final now = DateTime.now();
    return Bill(
      id: '',
      type: type,
      invoiceNumber: invoiceNumber,
      date: now,
      partyName: partyName,
      partyPhone: partyPhone,
      partyAddress: partyAddress,
      items: items,
      subtotal: subtotal,
      gstRate: gstRate,
      gstAmount: gstAmount,
      totalAmount: totalAmount,
      amountPaid: amountPaid,
      amountDue: amountDue,
      paymentStatus: paymentStatus,
      isGST: isGST,
      notes: notes,
      userMobile: userMobile,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'invoiceNumber': invoiceNumber,
      'date': FieldValue.serverTimestamp(),
      'partyName': partyName,
      'partyPhone': partyPhone,
      'partyAddress': partyAddress,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'gstRate': gstRate,
      'gstAmount': gstAmount,
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'amountDue': amountDue,
      'paymentStatus': paymentStatus,
      'isGST': isGST,
      'notes': notes,
      'userMobile': userMobile,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Bill.fromMap(Map<String, dynamic> map, String id) {
    return Bill(
      id: id,
      type: map['type'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      partyName: map['partyName'] ?? '',
      partyPhone: map['partyPhone'] ?? '',
      partyAddress: map['partyAddress'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => BillItem.fromMap(item))
              .toList() ??
          [],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      gstRate: (map['gstRate'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (map['gstAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
      amountDue: (map['amountDue'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: map['paymentStatus'] ?? 'due',
      isGST: map['isGST'] ?? true,
      notes: map['notes'] ?? '',
      userMobile: map['userMobile'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Bill copyWith({
    String? id,
    String? type,
    String? partyName,
    String? partyPhone,
    String? partyAddress,
    List<BillItem>? items,
    double? subtotal,
    double? gstRate,
    double? gstAmount,
    double? totalAmount,
    double? amountPaid,
    double? amountDue,
    String? paymentStatus,
    bool? isGST,
    String? notes,
  }) {
    return Bill(
      id: id ?? this.id,
      type: type ?? this.type,
      invoiceNumber: invoiceNumber,
      date: date,
      partyName: partyName ?? this.partyName,
      partyPhone: partyPhone ?? this.partyPhone,
      partyAddress: partyAddress ?? this.partyAddress,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      gstRate: gstRate ?? this.gstRate,
      gstAmount: gstAmount ?? this.gstAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      amountDue: amountDue ?? this.amountDue,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      isGST: isGST ?? this.isGST,
      notes: notes ?? this.notes,
      userMobile: userMobile,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Helper method to calculate totals from items
  void calculateTotals() {
    subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    gstAmount = isGST ? (subtotal * gstRate / 100) : 0.0;
    totalAmount = subtotal + gstAmount;
    amountDue = totalAmount - amountPaid;
    
    if (amountDue <= 0) {
      paymentStatus = 'paid';
    } else if (amountPaid > 0) {
      paymentStatus = 'partial';
    } else {
      paymentStatus = 'due';
    }
  }
}

class BillItem {
  String description;
  int quantity;
  double price;
  double total;

  BillItem({
    required this.description,
    required this.quantity,
    required this.price,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'price': price,
      'total': total,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      description: map['description'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  BillItem copyWith({
    String? description,
    int? quantity,
    double? price,
  }) {
    return BillItem(
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      total: (quantity ?? this.quantity) * (price ?? this.price),
    );
  }
}