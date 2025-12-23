import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item_model.dart';
import '../models/category_model.dart';

class InventoryService {
  final String userMobile;
  
  InventoryService(this.userMobile);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user's inventory subcollection reference
  CollectionReference get _userInventoryCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('inventory');
  }

  // Get user's categories collection reference
  CollectionReference get _userCategoriesCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('categories');
  }

  // Get user's suppliers collection reference
  CollectionReference get _userSuppliersCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('suppliers');
  }

  // Get stock adjustments subcollection reference
  CollectionReference _getStockAdjustmentsCollection(String inventoryId) {
    return _userInventoryCollection
        .doc(inventoryId)
        .collection('stockAdjustments');
  }

  // Add inventory item
  Future<String> addInventoryItem(InventoryItem item) async {
    try {
      // Verify SKU doesn't already exist for this user
      final skuExists = await _skuExistsForUser(item.sku);
      if (skuExists) {
        throw Exception('SKU "${item.sku}" already exists for this user');
      }
      
      // Prepare data with server timestamps
      final itemData = item.toMap();
      
      // Add to user's inventory subcollection
      final docRef = await _userInventoryCollection.add(itemData);
      
      // Update category item count if category exists
      if (item.category.isNotEmpty && item.category != 'Uncategorized') {
        await updateCategoryItemCount(item.category, increment: 1);
      }
      
      return docRef.id;
    } catch (e) {
      print('❌ Error adding inventory item: $e');
      throw Exception('Failed to add inventory item: $e');
    }
  }

  // Update inventory item
// Update inventory item
Future<void> updateInventoryItem(InventoryItem item) async {
  try {
    print('🔄 Updating item with ID: ${item.id}');
    
    if (item.id.isEmpty) {
      throw Exception('Inventory item ID is required for update');
    }
    
    // Verify SKU doesn't already exist for this user (excluding current item)
    final skuExists = await _skuExistsForUser(item.sku, excludeId: item.id);
    if (skuExists) {
      throw Exception('SKU "${item.sku}" already exists for this user');
    }
    
    // Get old item to check category changes
    print('📋 Getting old item data...');
    final oldItem = await getInventoryItem(item.id);
    print('📋 Old category: ${oldItem.category}, New category: ${item.category}');
    
    // Prepare update data
    final itemData = {
      'name': item.name,
      'description': item.description,
      'sku': item.sku,
      'category': item.category,
      'price': item.price,
      'cost': item.cost,
      'quantity': item.quantity,
      'lowStockThreshold': item.lowStockThreshold,
      'unit': item.unit,
      'location': item.location,
      'supplierId': item.supplierId,
      'supplierName': item.supplierName,
      'imageUrl': item.imageUrl,
      'userMobile': item.userMobile,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    print('📋 Update data: $itemData');
    
    // Perform update
    await _userInventoryCollection.doc(item.id).update(itemData);
    print('✅ Item updated successfully in Firestore');
    
    // Update category counts if category changed
    if (oldItem.category != item.category) {
      print('🔄 Category changed from "${oldItem.category}" to "${item.category}"');
      if (oldItem.category.isNotEmpty && oldItem.category != 'Uncategorized') {
        print('➖ Decrementing count for old category: ${oldItem.category}');
        await updateCategoryItemCount(oldItem.category, increment: -1);
      }
      if (item.category.isNotEmpty && item.category != 'Uncategorized') {
        print('➕ Incrementing count for new category: ${item.category}');
        await updateCategoryItemCount(item.category, increment: 1);
      }
    }
    
    print('✅ All updates completed successfully');
  } catch (e, stackTrace) {
    print('❌ Error updating inventory item: $e');
    print('Stack trace: $stackTrace');
    throw Exception('Failed to update inventory item: $e');
  }
}
  // Delete inventory item (soft delete)
  Future<void> deleteInventoryItem(String id) async {
    try {
      final item = await getInventoryItem(id);
      
      await _userInventoryCollection.doc(id).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Decrement category count
      if (item.category.isNotEmpty && item.category != 'Uncategorized') {
        await updateCategoryItemCount(item.category, increment: -1);
      }
    } catch (e) {
      print('❌ Error deleting inventory item: $e');
      throw Exception('Failed to delete inventory item: $e');
    }
  }

  // Get inventory item by ID
  Future<InventoryItem> getInventoryItem(String id) async {
    try {
      final doc = await _userInventoryCollection.doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return InventoryItem.fromMap(data, doc.id);
      } else {
        throw Exception('Inventory item not found');
      }
    } catch (e) {
      print('❌ Error getting inventory item: $e');
      throw Exception('Failed to get inventory item: $e');
    }
  }

  // Get all active inventory items for this user
  Stream<List<InventoryItem>> getInventoryItems() {
    return _userInventoryCollection
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .handleError((error) {
          print('❌ Stream error: $error');
          throw error;
        })
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return [];
          
          return snapshot.docs.map((doc) {
            return InventoryItem.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  // Search inventory items for this user
  Stream<List<InventoryItem>> searchInventoryItems(String query) {
    return _userInventoryCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) {
                return InventoryItem.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                );
              })
              .where((item) =>
                  item.name.toLowerCase().contains(query.toLowerCase()) ||
                  item.sku.toLowerCase().contains(query.toLowerCase()) ||
                  (item.description?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
                  item.category.toLowerCase().contains(query.toLowerCase()))
              .toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return items;
        });
  }

  // Get low stock items for this user
  Stream<List<InventoryItem>> getLowStockItems() {
    return _userInventoryCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                return InventoryItem.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                );
              })
              .where((item) => item.isLowStock)
              .toList()
              ..sort((a, b) => a.quantity.compareTo(b.quantity));
        });
  }

  // Get items by category for this user
  Future<List<InventoryItem>> getItemsByCategory(String category) async {
    try {
      final snapshot = await _userInventoryCollection
          .where('isActive', isEqualTo: true)
          .where('category', isEqualTo: category)
          .get();
      
      return snapshot.docs
          .map((doc) {
            return InventoryItem.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          })
          .toList();
    } catch (e) {
      print('❌ Error getting items by category: $e');
      return [];
    }
  }

  Future<List<InventoryItem>> getAllInventoryItems() async {
    try {
      final snapshot = await _userInventoryCollection.get();
      
      return snapshot.docs.map((doc) {
        return InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('Error getting all items: $e');
      return [];
    }
  }

  // Get all categories for this user
  Future<List<String>> getCategories() async {
    try {
      final snapshot = await _userCategoriesCollection
          .orderBy('name')
          .get();
      
      final categories = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return data['name'] as String? ?? '';
          })
          .where((name) => name.isNotEmpty)
          .toList();
      
      // Add 'Uncategorized' if no categories exist
      if (categories.isEmpty) {
        return ['Uncategorized'];
      }
      
      return categories;
    } catch (e) {
      print('❌ Error getting categories: $e');
      return ['Uncategorized'];
    }
  }

  // Add new category
// Update the addCategory method in InventoryService (around line 274)
Future<void> addCategory(String name, {String? description}) async { // Add description parameter
  try {
    // Check if category already exists
    final existingCategories = await getCategories();
    if (existingCategories.contains(name)) {
      throw Exception('Category "$name" already exists');
    }
    
    // Add to categories collection
    await _userCategoriesCollection.add({
      'name': name,
      'itemCount': 0,
      'description': description, // Use the parameter here
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    print('❌ Error adding category: $e');
    throw Exception('Failed to add category: $e');
  }
}
  // Check if SKU already exists for this user
  Future<bool> _skuExistsForUser(String sku, {String? excludeId}) async {
    try {
      final query = _userInventoryCollection
          .where('sku', isEqualTo: sku)
          .where('isActive', isEqualTo: true);
      
      final snapshot = await query.get();
      
      if (excludeId != null) {
        return snapshot.docs.any((doc) => doc.id != excludeId);
      }
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking SKU: $e');
      return false;
    }
  }

  // Public method to check SKU (for UI validation)
  Future<bool> skuExists(String sku, {String? excludeId}) async {
    return _skuExistsForUser(sku, excludeId: excludeId);
  }

  // Get inventory stats for this user
  Future<Map<String, dynamic>> getInventoryStats() async {
    try {
      final snapshot = await _userInventoryCollection
          .where('isActive', isEqualTo: true)
          .get();
      
      double totalValue = 0.0;
      final items = <InventoryItem>[];
      
      for (final doc in snapshot.docs) {
        final item = InventoryItem.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        items.add(item);
        totalValue += item.totalValue;
      }
      
      final totalItems = items.length;
      final inStockItems = items.where((item) => item.quantity > 0).length;
      final lowStockItems = items.where((item) => item.isLowStock && item.quantity > 0).length;
      final outOfStockItems = items.where((item) => item.quantity <= 0).length;
      
      return {
        'totalItems': totalItems,
        'inStockItems': inStockItems,
        'lowStockItems': lowStockItems,
        'outOfStockItems': outOfStockItems,
        'totalValue': totalValue,
      };
    } catch (e) {
      print('❌ Error getting inventory stats: $e');
      return {
        'totalItems': 0,
        'inStockItems': 0,
        'lowStockItems': 0,
        'outOfStockItems': 0,
        'totalValue': 0,
      };
    }
  }

  // Adjust stock quantity
  Future<void> adjustStock(String id, int adjustment, String reason) async {
    try {
      final item = await getInventoryItem(id);
      final newQuantity = item.quantity + adjustment;
      
      if (newQuantity < 0) {
        throw Exception('Cannot set negative stock quantity');
      }

      // Update the quantity
      await _userInventoryCollection.doc(id).update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log stock adjustment in subcollection
      await _getStockAdjustmentsCollection(id).add({
        'previousQuantity': item.quantity,
        'adjustment': adjustment,
        'newQuantity': newQuantity,
        'reason': reason,
        'adjustedAt': FieldValue.serverTimestamp(),
        'adjustedBy': userMobile,
      });
    } catch (e) {
      print('❌ Error adjusting stock: $e');
      throw Exception('Failed to adjust stock: $e');
    }
  }

  // Get total inventory value for this user
  Future<double> getTotalInventoryValue() async {
    try {
      final snapshot = await _userInventoryCollection
          .where('isActive', isEqualTo: true)
          .get();
      
      double totalValue = 0.0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final quantity = data['quantity'] is int ? data['quantity'] : int.parse(data['quantity']?.toString() ?? '0');
        final price = (data['price'] ?? 0).toDouble();
        totalValue += (price * quantity);
      }
      
      return totalValue;
    } catch (e) {
      print('❌ Error getting total inventory value: $e');
      return 0.0;
    }
  }

  Future<List<Category>> getCategoriesWithCount() async {
    try {
      final snapshot = await _userCategoriesCollection
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Category.fromMap(data, doc.id);
      }).toList();
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }

  // Get categories for dropdown (name only)
  Future<List<String>> getCategoriesForDropdown() async {
    try {
      final snapshot = await _userCategoriesCollection
          .orderBy('name')
          .get();
      
      return snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error getting categories for dropdown: $e');
      return [];
    }
  }

  Future<void> updateCategory(String id, String name, {String? description}) async {
    try {
      await _userCategoriesCollection.doc(id).update({
        'name': name,
        'description': description,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating category: $e');
      throw Exception('Failed to update category');
    }
  }

// Add these methods anywhere in your InventoryService class:

// 1. DELETE CATEGORY METHOD
Future<void> deleteCategory(String id, String name) async {
  try {
    // Check if category is being used by any items
    final itemsSnapshot = await _userInventoryCollection
        .where('category', isEqualTo: name)
        .where('isActive', isEqualTo: true)
        .get();

    if (itemsSnapshot.docs.isNotEmpty) {
      throw Exception('Cannot delete category "$name" because it has ${itemsSnapshot.docs.length} item(s)');
    }

    await _userCategoriesCollection.doc(id).delete();
    
    print('✅ Category "$name" deleted successfully');
  } catch (e) {
    print('❌ Error deleting category: $e');
    rethrow;
  }
}

// 2. HARD DELETE ITEM METHOD (optional)
Future<void> permanentlyDeleteItem(String id) async {
  try {
    final item = await getInventoryItem(id);
    
    // Delete the item document
    await _userInventoryCollection.doc(id).delete();
    
    // Decrement category count
    if (item.category.isNotEmpty && item.category != 'Uncategorized') {
      await updateCategoryItemCount(item.category, increment: -1);
    }
    
    print('✅ Item permanently deleted: ${item.name}');
  } catch (e) {
    print('❌ Error permanently deleting item: $e');
    throw Exception('Failed to delete item: $e');
  }
}
  Stream<List<Category>> streamCategories() {
    return _userCategoriesCollection
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Category.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  // Get items by category
  Stream<List<InventoryItem>> streamItemsByCategory(String category) {
    return _userInventoryCollection
        .where('category', isEqualTo: category)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return InventoryItem.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  // Update item count for categories
  Future<void> updateCategoryItemCount(String categoryName, {required int increment}) async {
    try {
      // Find the category document by name
      final querySnapshot = await _userCategoriesCollection
          .where('name', isEqualTo: categoryName)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final currentCount = data['itemCount'] ?? 0;
        await doc.reference.update({
          'itemCount': currentCount + increment,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Category doesn't exist in categories collection, create it
        await _userCategoriesCollection.add({
          'name': categoryName,
          'itemCount': increment > 0 ? 1 : 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating category count: $e');
    }
  }

  // ========== SUPPLIER METHODS ========== //

  // Get all suppliers for this user
  Future<List<String>> getSuppliers() async {
    try {
      final snapshot = await _userSuppliersCollection
          .orderBy('name')
          .get();
      
      final suppliers = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return data['name'] as String? ?? '';
          })
          .where((name) => name.isNotEmpty)
          .toList();
      
      return suppliers;
    } catch (e) {
      print('❌ Error getting suppliers: $e');
      return [];
    }
  }

  // Add new supplier
  Future<void> addSupplier(String name, {String? contact, String? email, String? phone}) async {
    try {
      // Check if supplier already exists
      final existingSuppliers = await getSuppliers();
      if (existingSuppliers.contains(name)) {
        throw Exception('Supplier "$name" already exists');
      }
      
      // Add to suppliers collection
      await _userSuppliersCollection.add({
        'name': name,
        'contact': contact,
        'email': email,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
    } catch (e) {
      print('❌ Error adding supplier: $e');
      throw Exception('Failed to add supplier: $e');
    }
  }

  // Get suppliers for dropdown (name only)
  Future<List<String>> getSuppliersForDropdown() async {
    try {
      final snapshot = await _userSuppliersCollection
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();
      
      return snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error getting suppliers for dropdown: $e');
      return [];
    }
  }

  // Get supplier details by name
  Future<Map<String, dynamic>?> getSupplierDetails(String name) async {
    try {
      final querySnapshot = await _userSuppliersCollection
          .where('name', isEqualTo: name)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting supplier details: $e');
      return null;
    }
  }

  // Get supplier details by ID
  Future<Map<String, dynamic>?> getSupplierById(String id) async {
    try {
      final doc = await _userSuppliersCollection.doc(id).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting supplier by ID: $e');
      return null;
    }
  }

  // Update supplier
  Future<void> updateSupplier(String id, String name, {String? contact, String? email, String? phone}) async {
    try {
      await _userSuppliersCollection.doc(id).update({
        'name': name,
        'contact': contact,
        'email': email,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating supplier: $e');
      throw Exception('Failed to update supplier');
    }
  }

  // Delete supplier (soft delete)
  Future<void> deleteSupplier(String id) async {
    try {
      await _userSuppliersCollection.doc(id).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error deleting supplier: $e');
      throw Exception('Failed to delete supplier');
    }
  }

  // Get supplier items count
  Future<int> getSupplierItemCount(String supplierName) async {
    try {
      final snapshot = await _userInventoryCollection
          .where('supplierName', isEqualTo: supplierName)
          .where('isActive', isEqualTo: true)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting supplier item count: $e');
      return 0;
    }
  }
}