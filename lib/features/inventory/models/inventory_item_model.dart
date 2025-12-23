import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String? imageUrl;
  final String userMobile; // Add userMobile field
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
    final String? supplierName; // Add this


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
    this.imageUrl,
    required this.userMobile, // Add to constructor
        this.supplierName, // Add this

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
      'supplierName': supplierName, // Add this
      'imageUrl': imageUrl,
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
      imageUrl: map['imageUrl']?.toString(),
      userMobile: map['userMobile']?.toString() ?? '', // Parse userMobile
      supplierName: map['supplierName'] as String?, // Add this

      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      isActive: map['isActive'] ?? true,
    );
  }

  // For direct Firestore conversion (without FieldValue)
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
      'imageUrl': imageUrl,
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
      imageUrl: data['imageUrl'],
      userMobile: data['userMobile'] ?? '', // Get userMobile
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      isActive: data['isActive'] ?? true,
    );
  }

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
    String? imageUrl,
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
      imageUrl: imageUrl ?? this.imageUrl,
      userMobile: userMobile ?? this.userMobile, // Copy userMobile
      createdAt: this.createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
    );
  }
  
  bool get isLowStock => quantity <= lowStockThreshold;
  double get totalValue => price * quantity;
  double get profitMargin => price > 0 ? ((price - cost) / price) * 100 : 0;
}