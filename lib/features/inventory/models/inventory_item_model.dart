
// ./lib/features/inventory/models/inventory_item_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InventoryItem {
  final String id;
  final String name;
  final String description;
  final String sku;
  final String category;
  final double price;
  final double cost;
  final int quantity;
  final int lowStockThreshold;
  final String unit;
  final String? location;
  final String? supplierId;
  final String? supplierName;
  final String? imageUrl;
  final String userMobile;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final DateTime? expiryDate;
  final bool trackExpiry;
  final bool trackByBatch;

  InventoryItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.sku,
    this.category = 'Uncategorized',
    required this.price,
    required this.cost,
    required this.quantity,
    this.lowStockThreshold = 10,
    this.unit = 'pcs',
    this.location,
    this.supplierId,
    this.supplierName,
    this.imageUrl,
    this.expiryDate,
    this.trackExpiry = false,
    this.trackByBatch = false,
    required this.userMobile,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Helper function to parse date from Firestore
  static DateTime _parseDate(dynamic date) {
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

  // ============ EXPIRY HELPER GETTERS ============
  
  bool get isExpired {
    if (!trackExpiry || expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }
  
  bool get isNearExpiry {
    if (!trackExpiry || expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
  }
  
  int get daysUntilExpiry {
    if (expiryDate == null) return -1;
    return expiryDate!.difference(DateTime.now()).inDays;
  }
  
  String get expiryStatus {
    if (!trackExpiry) return 'Not tracked';
    if (isExpired) return 'Expired';
    if (isNearExpiry) return 'Expiring soon';
    return 'Valid';
  }
  
  Color get expiryStatusColor {
    if (!trackExpiry) return Colors.grey;
    if (isExpired) return Colors.red;
    if (isNearExpiry) return Colors.orange;
    return Colors.green;
  }

  // ============ EXISTING GETTERS ============
  
  bool get isLowStock => quantity <= lowStockThreshold;
  double get totalValue => price * quantity;
  double get profitMargin => price > 0 ? ((price - cost) / price) * 100 : 0;
  bool get isDeleted => !isActive;
  
  // Get effective quantity (for batch items, stock is in batches, not in quantity field)
int get effectiveQuantity => quantity; // quantity is always the source of truth

  // ============ CONVERSION METHODS ============
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'sku': sku,
      'category': category,
      'price': price,
      'cost': cost,
      'quantity': quantity,
      'lowStockThreshold': lowStockThreshold,
      'unit': unit,
      'location': location,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'imageUrl': imageUrl,
      'expiryDate': expiryDate != null 
          ? Timestamp.fromDate(expiryDate!)
          : null,
      'trackExpiry': trackExpiry,
      'trackByBatch': trackByBatch,
      'userMobile': userMobile,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }

  static InventoryItem fromMap(Map<String, dynamic> map, String documentId) {
    return InventoryItem(
      id: documentId,
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      sku: map['sku']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Uncategorized',
      price: (map['price'] ?? 0).toDouble(),
      cost: (map['cost'] ?? 0).toDouble(),
      quantity: map['quantity'] is int ? map['quantity'] : int.parse(map['quantity']?.toString() ?? '0'),
      lowStockThreshold: map['lowStockThreshold'] is int ? map['lowStockThreshold'] : int.parse(map['lowStockThreshold']?.toString() ?? '10'),
      unit: map['unit']?.toString() ?? 'pcs',
      location: map['location']?.toString(),
      supplierId: map['supplierId']?.toString(),
      supplierName: map['supplierName']?.toString(),
      imageUrl: map['imageUrl']?.toString(),
      expiryDate: map['expiryDate'] != null ? _parseDate(map['expiryDate']) : null,
      trackExpiry: map['trackExpiry'] ?? false,
      trackByBatch: map['trackByBatch'] ?? false,
      userMobile: map['userMobile']?.toString() ?? '',
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'sku': sku,
      'category': category,
      'price': price,
      'cost': cost,
      'quantity': quantity,
      'lowStockThreshold': lowStockThreshold,
      'unit': unit,
      'location': location,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'imageUrl': imageUrl,
      'expiryDate': expiryDate?.toIso8601String(),
      'trackExpiry': trackExpiry,
      'trackByBatch': trackByBatch,
      'userMobile': userMobile,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  static InventoryItem fromFirestore(String id, Map<String, dynamic> data) {
    return InventoryItem(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      sku: data['sku'] ?? '',
      category: data['category'] ?? 'Uncategorized',
      price: (data['price'] ?? 0).toDouble(),
      cost: (data['cost'] ?? 0).toDouble(),
      quantity: data['quantity'] is int ? data['quantity'] : int.parse(data['quantity']?.toString() ?? '0'),
      lowStockThreshold: data['lowStockThreshold'] is int ? data['lowStockThreshold'] : int.parse(data['lowStockThreshold']?.toString() ?? '10'),
      unit: data['unit'] ?? 'pcs',
      location: data['location'],
      supplierId: data['supplierId'],
      supplierName: data['supplierName'],
      imageUrl: data['imageUrl'],
      expiryDate: data['expiryDate'] != null ? _parseDate(data['expiryDate']) : null,
      trackExpiry: data['trackExpiry'] ?? false,
      trackByBatch: data['trackByBatch'] ?? false,
      userMobile: data['userMobile'] ?? '',
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      isActive: data['isActive'] ?? true,
    );
  }

  // ✅ FIXED copyWith method - includes trackByBatch
  InventoryItem copyWith({
    String? id,
    String? name,
    String? description,
    String? sku,
    String? category,
    double? price,
    double? cost,
    int? quantity,
    int? lowStockThreshold,
    String? unit,
    String? location,
    String? supplierId,
    String? supplierName,
    String? imageUrl,
    DateTime? expiryDate,
    bool? trackExpiry,
    bool? trackByBatch,
    String? userMobile,
    bool? isActive,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      unit: unit ?? this.unit,
      location: location ?? this.location,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      imageUrl: imageUrl ?? this.imageUrl,
      expiryDate: expiryDate ?? this.expiryDate,
      trackExpiry: trackExpiry ?? this.trackExpiry,
      trackByBatch: trackByBatch ?? this.trackByBatch,
      userMobile: userMobile ?? this.userMobile,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sku': sku,
      'category': category,
      'price': price,
      'cost': cost,
      'quantity': quantity,
      'lowStockThreshold': lowStockThreshold,
      'unit': unit,
      'location': location,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'imageUrl': imageUrl,
      'expiryDate': expiryDate?.toIso8601String(),
      'trackExpiry': trackExpiry,
      'trackByBatch': trackByBatch,
      'userMobile': userMobile,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory InventoryItem.fromCacheMap(Map<String, dynamic> map, String id) {
    return InventoryItem(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      sku: map['sku'] ?? '',
      category: map['category'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      cost: (map['cost'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 0,
      lowStockThreshold: map['lowStockThreshold'] ?? 5,
      unit: map['unit'] ?? 'pcs',
      location: map['location'] ?? '',
      supplierId: map['supplierId'] ?? '',
      supplierName: map['supplierName'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      expiryDate: map['expiryDate'] != null ? DateTime.parse(map['expiryDate']) : null,
      trackExpiry: map['trackExpiry'] ?? false,
      trackByBatch: map['trackByBatch'] ?? false,
      userMobile: map['userMobile'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      isActive: map['isActive'] ?? true,
    );
  }
}