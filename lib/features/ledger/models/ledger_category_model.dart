// lib/features/ledger/models/ledger_category_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Fixed vocabulary of category icons. Firestore only stores primitives, so
/// an [IconData] can't be serialized directly — instead we store one of
/// these string keys on the category document and resolve it back to an
/// [IconData] here. Both the category picker UI and the Add Entry chip grid
/// read from this single map so they always stay in sync.
const Map<String, IconData> kLedgerCategoryIcons = {
  'business': Icons.business_center_outlined,
  'storefront': Icons.storefront_outlined,
  'home': Icons.home_work_outlined,
  'salary': Icons.groups_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'food': Icons.restaurant_outlined,
  'transport': Icons.local_shipping_outlined,
  'electricity': Icons.bolt_outlined,
  'phone': Icons.phone_outlined,
  'rent': Icons.house_outlined,
  'maintenance': Icons.build_outlined,
  'health': Icons.local_hospital_outlined,
  'education': Icons.school_outlined,
  'entertainment': Icons.movie_outlined,
  'travel': Icons.flight_outlined,
  'gift': Icons.card_giftcard_outlined,
  'interest': Icons.trending_up_rounded,
  'refund': Icons.replay_circle_filled_outlined,
  'supplies': Icons.inventory_2_outlined,
  'other': Icons.more_horiz_rounded,
};

const String kDefaultLedgerCategoryIcon = 'other';

/// Resolves a stored icon key to its [IconData], falling back to a generic
/// "other" icon for unknown/legacy keys.
IconData ledgerCategoryIconFor(String iconKey) =>
    kLedgerCategoryIcons[iconKey] ??
    kLedgerCategoryIcons[kDefaultLedgerCategoryIcon]!;

class LedgerCategory {
  final String id;
  final String name;
  final String type; // 'income' or 'expense'
  final String icon; // key into kLedgerCategoryIcons
  final String userMobile;
  final DateTime createdAt;
  final int sortOrder;

  LedgerCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.userMobile,
    required this.createdAt,
    this.sortOrder = 0,
  });

  // Create a new category for the current user
  factory LedgerCategory.create({
    required String name,
    required String type,
    required String userMobile,
    String icon = kDefaultLedgerCategoryIcon,
    int sortOrder = 0,
  }) {
    return LedgerCategory(
      id: '',
      name: name,
      type: type,
      icon: icon,
      userMobile: userMobile,
      createdAt: DateTime.now(),
      sortOrder: sortOrder,
    );
  }

  factory LedgerCategory.fromMap(Map<String, dynamic> map, String documentId) {
    return LedgerCategory(
      id: documentId,
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? 'expense',
      icon: map['icon']?.toString() ?? kDefaultLedgerCategoryIcon,
      userMobile: map['userMobile']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      sortOrder: ((map['sortOrder'] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'icon': icon,
      'userMobile': userMobile,
      'createdAt': Timestamp.fromDate(createdAt),
      'sortOrder': sortOrder,
    };
  }

  LedgerCategory copyWith({
    String? id,
    String? name,
    String? type,
    String? icon,
    String? userMobile,
    DateTime? createdAt,
    int? sortOrder,
  }) {
    return LedgerCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      userMobile: userMobile ?? this.userMobile,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  IconData get iconData => ledgerCategoryIconFor(icon);
}
