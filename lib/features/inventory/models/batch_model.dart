// lib/features/inventory/models/batch_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Batch {
  final String id;
  final String inventoryId;
  final String batchNumber;
  final int quantity;
  final int remainingQuantity;
  final double purchasePrice;
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final String? supplierInvoiceNo;
  final String? supplierName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Batch({
    required this.id,
    required this.inventoryId,
    required this.batchNumber,
    required this.quantity,
    required this.remainingQuantity,
    required this.purchasePrice,
    required this.purchaseDate,
    required this.expiryDate,
    this.supplierInvoiceNo,
    this.supplierName,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isExpired => DateTime.now().isAfter(expiryDate);
  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
  bool get isNearExpiry => !isExpired && daysUntilExpiry <= 30;
  bool get isFullyConsumed => remainingQuantity <= 0;
  bool get isLowStock => remainingQuantity <= 5;

  Map<String, dynamic> toMap() {
    return {
      'inventoryId': inventoryId,
      'batchNumber': batchNumber,
      'quantity': quantity,
      'remainingQuantity': remainingQuantity,
      'purchasePrice': purchasePrice,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'supplierInvoiceNo': supplierInvoiceNo,
      'supplierName': supplierName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }

  static Batch fromMap(Map<String, dynamic> map, String id) {
    return Batch(
      id: id,
      inventoryId: map['inventoryId'] ?? '',
      batchNumber: map['batchNumber'] ?? '',
      quantity: map['quantity'] ?? 0,
      remainingQuantity: map['remainingQuantity'] ?? 0,
      purchasePrice: (map['purchasePrice'] ?? 0).toDouble(),
      purchaseDate: (map['purchaseDate'] as Timestamp).toDate(),
      expiryDate: (map['expiryDate'] as Timestamp).toDate(),
      supplierInvoiceNo: map['supplierInvoiceNo'],
      supplierName: map['supplierName'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Batch copyWith({
    String? id,
    String? inventoryId,
    String? batchNumber,
    int? quantity,
    int? remainingQuantity,
    double? purchasePrice,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    String? supplierInvoiceNo,
    String? supplierName,
    bool? isActive,
  }) {
    return Batch(
      id: id ?? this.id,
      inventoryId: inventoryId ?? this.inventoryId,
      batchNumber: batchNumber ?? this.batchNumber,
      quantity: quantity ?? this.quantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      supplierInvoiceNo: supplierInvoiceNo ?? this.supplierInvoiceNo,
      supplierName: supplierName ?? this.supplierName,
      isActive: isActive ?? this.isActive,
    );
  }
}

class StockConsumption {
  final String id;
  final String inventoryId;
  final String batchId;
  final int quantityConsumed;
  final String transactionType;
  final String? referenceId;
  final String reason;
  final DateTime consumedAt;
  final String consumedBy;

  StockConsumption({
    required this.id,
    required this.inventoryId,
    required this.batchId,
    required this.quantityConsumed,
    required this.transactionType,
    this.referenceId,
    required this.reason,
    required this.consumedAt,
    required this.consumedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'inventoryId': inventoryId,
      'batchId': batchId,
      'quantityConsumed': quantityConsumed,
      'transactionType': transactionType,
      'referenceId': referenceId,
      'reason': reason,
      'consumedAt': Timestamp.fromDate(consumedAt),
      'consumedBy': consumedBy,
    };
  }

  static StockConsumption fromMap(Map<String, dynamic> map, String id) {
    return StockConsumption(
      id: id,
      inventoryId: map['inventoryId'] ?? '',
      batchId: map['batchId'] ?? '',
      quantityConsumed: map['quantityConsumed'] ?? 0,
      transactionType: map['transactionType'] ?? '',
      referenceId: map['referenceId'],
      reason: map['reason'] ?? '',
      consumedAt: (map['consumedAt'] as Timestamp).toDate(),
      consumedBy: map['consumedBy'] ?? '',
    );
  }
}