import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item_model.dart';
import '../models/category_model.dart';
import '../models/batch_model.dart';  // ← ADD THIS LINE

import '../services/local_storage_service.dart';
import 'batch_service.dart';
import 'expiry_alert_service.dart';


class InventoryService {
  final String userMobile;
  late final LocalStorageService _localStorage;
  late final BatchService _batchService;
  late final ExpiryAlertService _expiryAlertService;


  InventoryService(this.userMobile) {
    _localStorage = LocalStorageService();
    _initLocalStorage();
    _initBatchServices();  // ← ADD THIS LINE
  }

    // Initialize batch services
  void _initBatchServices() {
    _batchService = BatchService(userMobile);
    _expiryAlertService = ExpiryAlertService(userMobile);
  }
  
    BatchService get batchService => _batchService;
  ExpiryAlertService get expiryAlertService => _expiryAlertService;


  // Initialize local storage
  Future<void> _initLocalStorage() async {
    await _localStorage.init();
    // Load initial data into cache
    _cacheAllData();
  }

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

  // ========== NEW CACHE MANAGEMENT METHODS ==========

  // Cache all data to local storage
  Future<void> _cacheAllData() async {
    try {
      final items = await getAllInventoryItems();
      await _localStorage.saveInventoryItems(items);

      final categories = await getCategoriesWithCount();
      await _localStorage.saveCategories(categories);

      //print('✅ All data cached successfully');
    } catch (e) {
      //print('❌ Error caching data: $e');
    }
  }

  // Refresh cache from Firebase
  Future<void> refreshCache() async {
    await _cacheAllData();
  }

  // Clear all cache
  Future<void> clearCache() async {
    await _localStorage.clearAllCache();
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return _localStorage.getCacheStats();
  }

  // ========== ENHANCED SEARCH METHODS ==========

  // Search in local storage first (instant results), then fallback to Firebase
  Stream<List<InventoryItem>> enhancedSearch(String query) {
    if (query.isEmpty) {
      return getInventoryItems();
    }

    // Save search query to history
    _localStorage.saveSearchQuery(query);

    // First, try to get results from local storage
    final localResults = _localStorage.searchItems(query);

    if (localResults.isNotEmpty) {
      // If we have local results, return them immediately as a stream
      return Stream.value(localResults);
    } else {
      // If no local results, fallback to Firebase search
      return searchInventoryItems(query);
    }
  }

  // Pure local search (offline first)
  List<InventoryItem> searchLocally(String query) {
    if (query.isEmpty) return [];

    // Save to search history
    _localStorage.saveSearchQuery(query);

    // Search in local storage
    return _localStorage.searchItems(query);
  }

  // Advanced local search with filters
  List<InventoryItem> advancedLocalSearch({
    String? query,
    String? category,
    String? supplierId,
    bool? lowStockOnly,
    double? minPrice,
    double? maxPrice,
  }) {
    return _localStorage.advancedSearch(
      query: query,
      category: category,
      supplierId: supplierId,
      lowStockOnly: lowStockOnly,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
  }

  // Get search history
  List<String> getSearchHistory() {
    return _localStorage.getSearchHistory();
  }

  // Clear search history
  Future<void> clearSearchHistory() async {
    await _localStorage.clearSearchHistory();
  }

  // Get search suggestions based on partial input
  List<String> getSearchSuggestions(String partial) {
    return _localStorage.getSuggestions(partial);
  }

  // Get recent searches with timestamps
  List<Map<String, dynamic>> getRecentSearchesWithTime() {
    return _localStorage.getSearchHistoryWithTime();
  }

  // Add this method to your InventoryService class
  List<InventoryItem> searchItemsLocally({String? query}) {
    if (query == null || query.isEmpty) return [];

    // Get items from local storage
    final cachedItems = _localStorage.getInventoryItems();

    // Filter based on query
    final lowerQuery = query.toLowerCase();
    return cachedItems.where((item) {
      return item.name.toLowerCase().contains(lowerQuery) ||
          item.sku.toLowerCase().contains(lowerQuery) ||
          item.description.toLowerCase().contains(lowerQuery) ||
          item.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // ========== ENHANCED CRUD METHODS WITH CACHE SYNC ==========

  // Add inventory item with cache update
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

      // Update cache
      final newItem = item.copyWith(id: docRef.id);
      await _localStorage.addInventoryItem(newItem);

      return docRef.id;
    } catch (e) {
      //print('❌ Error adding inventory item: $e');
      throw Exception('Failed to add inventory item: $e');
    }
  }

  // Update inventory item with cache update
Future<void> updateInventoryItem(InventoryItem item) async {
  try {
    //print('🔄 Updating item with ID: ${item.id}');
    
    if (item.id.isEmpty) {
      throw Exception('Inventory item ID is required for update');
    }

    // Prepare update data with proper Timestamp conversion
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
      'trackExpiry': item.trackExpiry,
      'trackByBatch': item.trackByBatch,  // ← ADD THIS LINE
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Convert expiryDate to Timestamp if it exists
    if (item.expiryDate != null) {
      itemData['expiryDate'] = Timestamp.fromDate(item.expiryDate!);
    } else {
      itemData['expiryDate'] = null;
    }

    // Perform update
    await _userInventoryCollection.doc(item.id).update(itemData);
    //print('✅ Item updated successfully in Firestore');

    // Update cache
    await _localStorage.updateInventoryItem(item);

    //print('✅ All updates completed successfully');
  } catch (e, stackTrace) {
    //print('❌ Error updating inventory item: $e');
    //print('Stack trace: $stackTrace');
    throw Exception('Failed to update inventory item: $e');
  }
} 
  // Delete inventory item (soft delete) with cache update
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

      // Delete from cache
      await _localStorage.deleteInventoryItem(id);
    } catch (e) {
      //print('❌ Error deleting inventory item: $e');
      throw Exception('Failed to delete inventory item: $e');
    }
  }

  // Get inventory item by ID (with cache fallback)
  Future<InventoryItem> getInventoryItem(String id) async {
    try {
      final doc = await _userInventoryCollection.doc(id).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final item = InventoryItem.fromMap(data, doc.id);

        // Update cache
        await _localStorage.updateInventoryItem(item);

        return item;
      } else {
        // Try to get from cache as fallback
        final cachedItems = _localStorage.getInventoryItems();
        final cachedItem = cachedItems.firstWhere(
          (item) => item.id == id,
          orElse: () => throw Exception('Inventory item not found'),
        );
        return cachedItem;
      }
    } catch (e) {
      //print('❌ Error getting inventory item: $e');
      throw Exception('Failed to get inventory item: $e');
    }
  }

  // Get all active inventory items for this user (with cache)
  Stream<List<InventoryItem>> getInventoryItems() {
    return _userInventoryCollection
        .where('isActive', isEqualTo: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .handleError((error) {
      //print('❌ Stream error: $error');
      throw error;
    }).map((snapshot) {
      if (snapshot.docs.isEmpty) return [];

      final items = snapshot.docs.map((doc) {
        return InventoryItem.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();

      // Update cache in background
      _localStorage.saveInventoryItems(items);

      return items;
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
              (item.description.toLowerCase().contains(query.toLowerCase()) ??
                  false) ||
              item.category.toLowerCase().contains(query.toLowerCase()))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // Save search query to history
      _localStorage.saveSearchQuery(query);

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

      return snapshot.docs.map((doc) {
        return InventoryItem.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      //print('❌ Error getting items by category: $e');
      return [];
    }
  }

  Future<List<InventoryItem>> getAllInventoryItems() async {
    try {
      final snapshot = await _userInventoryCollection
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        return InventoryItem.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      //print('Error getting all items: $e');
      return [];
    }
  }

  // Get all categories for this user
  Future<List<String>> getCategories() async {
    try {
      final snapshot = await _userCategoriesCollection.orderBy('name').get();

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
      //print('❌ Error getting categories: $e');
      return ['Uncategorized'];
    }
  }

  // Add new category with cache update
  Future<void> addCategory(String name, {String? description}) async {
    try {
      // Check if category already exists
      final existingCategories = await getCategories();
      if (existingCategories.contains(name)) {
        throw Exception('Category "$name" already exists');
      }

      // Add to categories collection
      final docRef = await _userCategoriesCollection.add({
        'name': name,
        'itemCount': 0,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update cache
      final newCategory = Category(
        id: docRef.id,
        name: name,
        description: description,
        itemCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _localStorage.addCategory(newCategory);
    } catch (e) {
      //print('❌ Error adding category: $e');
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
      //print('❌ Error checking SKU: $e');
      return false;
    }
  }

  // Public method to check SKU (for UI validation)
  Future<bool> skuExists(String sku, {String? excludeId}) async {
    return _skuExistsForUser(sku, excludeId: excludeId);
  }

  // Get inventory stats for this user (with cache fallback)
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
      final lowStockItems =
          items.where((item) => item.isLowStock && item.quantity > 0).length;
      final outOfStockItems = items.where((item) => item.quantity <= 0).length;

      return {
        'totalItems': totalItems,
        'inStockItems': inStockItems,
        'lowStockItems': lowStockItems,
        'outOfStockItems': outOfStockItems,
        'totalValue': totalValue,
      };
    } catch (e) {
      //print('❌ Error getting inventory stats from Firebase, using cache: $e');

      // Fallback to cache
      final cachedItems = _localStorage.getInventoryItems();
      double totalValue = 0.0;
      for (var item in cachedItems) {
        totalValue += item.totalValue;
      }

      return {
        'totalItems': cachedItems.length,
        'inStockItems': cachedItems.where((item) => item.quantity > 0).length,
        'lowStockItems': cachedItems
            .where((item) => item.isLowStock && item.quantity > 0)
            .length,
        'outOfStockItems':
            cachedItems.where((item) => item.quantity <= 0).length,
        'totalValue': totalValue,
        'fromCache': true,
      };
    }
  }

  // Adjust stock quantity with cache update
  Future<void> adjustStock(String id, int adjustment, String reason) async {
    try {
      //print('🛠️ adjustStock called:');
      //print('  Item ID: $id');
      //print('  Adjustment: $adjustment');
      //print('  Reason: $reason');

      final item = await getInventoryItem(id);
      //print('  Current quantity: ${item.quantity}');

      final newQuantity = item.quantity + adjustment;
      //print('  New quantity will be: $newQuantity');

      if (newQuantity < 0) {
        //print('  ❌ ERROR: Cannot set negative stock quantity');
        throw Exception('Cannot set negative stock quantity');
      }

      // Update the quantity
      //print('  📝 Updating Firestore...');
      await _userInventoryCollection.doc(id).update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log stock adjustment in subcollection
      //print('  📝 Logging adjustment...');
      await _getStockAdjustmentsCollection(id).add({
        'previousQuantity': item.quantity,
        'adjustment': adjustment,
        'newQuantity': newQuantity,
        'reason': reason,
        'adjustedAt': FieldValue.serverTimestamp(),
        'adjustedBy': userMobile,
      });

      // Update cache
      final updatedItem = item.copyWith(quantity: newQuantity);
      await _localStorage.updateInventoryItem(updatedItem);

      //print('  ✅ adjustStock completed successfully');
    } catch (e) {
      //print('❌ Error in adjustStock: $e');
      //print('Stack trace: ${e.toString()}');
      throw Exception('Failed to adjust stock: $e');
    }
  }

Future<Batch> purchaseStock({
    required String inventoryId,
    required int quantity,
    required double purchasePrice,
    required DateTime expiryDate,
    DateTime? purchaseDate,
    String? supplierInvoiceNo,
    String? supplierName,
  }) async {
    try {
      final item = await getInventoryItem(inventoryId);
      
      if (!item.trackByBatch) {
        // Non-batch: simple quantity update
        final newQuantity = item.quantity + quantity;
        await _userInventoryCollection.doc(inventoryId).update({
          'quantity': newQuantity,
          'expiryDate': Timestamp.fromDate(expiryDate),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final updatedItem = item.copyWith(
          quantity: newQuantity,
          expiryDate: expiryDate,
        );
        await _localStorage.updateInventoryItem(updatedItem);
        
        return Batch(
          id: '',
          inventoryId: inventoryId,
          batchNumber: 'SINGLE_BATCH',
          quantity: quantity,
          remainingQuantity: quantity,
          purchasePrice: purchasePrice,
          purchaseDate: purchaseDate ?? DateTime.now(),
          expiryDate: expiryDate,
          supplierInvoiceNo: supplierInvoiceNo,
          supplierName: supplierName,
        );
      }
      
      // Batch tracking: create batch then sync quantity
      final newBatch = Batch(
        id: '',
        inventoryId: inventoryId,
        batchNumber: '',
        quantity: quantity,
        remainingQuantity: quantity,
        purchasePrice: purchasePrice,
        purchaseDate: purchaseDate ?? DateTime.now(),
        expiryDate: expiryDate,
        supplierInvoiceNo: supplierInvoiceNo,
        supplierName: supplierName,
      );
      
      final createdBatch = await _batchService.addBatch(inventoryId, newBatch);
      
      // ✅ KEY FIX: sync total batch quantity back to inventory item
      await syncBatchQuantityToItem(inventoryId);
      
      return createdBatch;
      
    } catch (e) {
      //print('❌ Error purchasing stock: $e');
      throw Exception('Failed to purchase stock: $e');
    }
  }
  // Sell stock using FIFO for batch-tracked items
// Sell stock using FIFO for batch-tracked items
Future<List<StockConsumption>> sellStock({
  required String inventoryId,
  required int quantity,
  required String saleId,
  required String soldBy,
  String? specificBatchId,  // ← ADD THIS PARAMETER
}) async {
  try {
    final item = await getInventoryItem(inventoryId);
    
    if (!item.trackByBatch) {
      // Simple stock deduction
      final newQuantity = item.quantity - quantity;
      if (newQuantity < 0) {
        throw Exception('Insufficient stock');
      }
      
      await _userInventoryCollection.doc(inventoryId).update({
        'quantity': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update cache
      final updatedItem = item.copyWith(quantity: newQuantity);
      await _localStorage.updateInventoryItem(updatedItem);
      
      return []; // Return empty list for non-batch items
    }
    
    // Initialize batch service if not already initialized
    if (_batchService == null) {
      _initBatchServices();
    }
    
    // If specific batch is selected, sell from that batch only
    if (specificBatchId != null && specificBatchId.isNotEmpty) {
      return await _batchService.consumeStockFromSpecificBatch(
        inventoryId: inventoryId,
        batchId: specificBatchId,
        quantityToConsume: quantity,
        transactionType: 'SALE',
        reason: 'Sale transaction: $saleId',
        referenceId: saleId,
        consumedBy: soldBy,
      );
    }
    
    // Otherwise use FIFO consumption
    return await _batchService.consumeStockFIFO(
      inventoryId: inventoryId,
      quantityToConsume: quantity,
      transactionType: 'SALE',
      reason: 'Sale transaction: $saleId',
      referenceId: saleId,
      consumedBy: soldBy,
    );
    
  } catch (e) {
    print('❌ Error selling stock: $e');
    throw Exception('Failed to sell stock: $e');
  }
}

// Sync batch total back to inventory item's quantity field
Future<void> syncBatchQuantityToItem(String inventoryId) async {
  try {
    final batchesSnapshot = await _userInventoryCollection
        .doc(inventoryId)
        .collection('batches')
        .where('isActive', isEqualTo: true)
        .where('remainingQuantity', isGreaterThan: 0)
        .get();

    int totalRemaining = 0;
    for (final doc in batchesSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalRemaining += (data['remainingQuantity'] as num?)?.toInt() ?? 0;
    }

    await _userInventoryCollection.doc(inventoryId).update({
      'quantity': totalRemaining,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update cache
    final cachedItems = _localStorage.getInventoryItems();
    final idx = cachedItems.indexWhere((i) => i.id == inventoryId);
    if (idx != -1) {
      final updated = cachedItems[idx].copyWith(quantity: totalRemaining);
      await _localStorage.updateInventoryItem(updated);
    }

    //print('✅ Synced batch quantity: $totalRemaining units for $inventoryId');
  } catch (e) {
    //print('❌ Error syncing batch quantity: $e');
  }
}

 Future<Map<String, dynamic>> getExpiryAlerts() async {
    if (_expiryAlertService == null) {
      _initBatchServices();
    }
    return await _expiryAlertService.getAlertSummary();
  }
  
  // Get detailed near expiry alerts
  Future<List<Map<String, dynamic>>> getNearExpiryAlerts({int daysThreshold = 30}) async {
    if (_expiryAlertService == null) {
      _initBatchServices();
    }
    return await _expiryAlertService.getNearExpiryAlerts(daysThreshold: daysThreshold);
  }
  
  // Write off all expired stock
 Future<int> writeOffExpiredStock(String inventoryId, String userId) async {
    final count = await _batchService.writeOffExpiredBatches(inventoryId, userId);
    
    // ✅ KEY FIX: sync quantity after write-off
    await syncBatchQuantityToItem(inventoryId);
    
    return count;
  }

  // Get batch summary for an item
  Future<Map<String, dynamic>> getBatchSummary(String inventoryId) async {
    if (_batchService == null) {
      _initBatchServices();
    }
    return await _batchService.getStockSummary(inventoryId);
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
        final quantity = data['quantity'] is int
            ? data['quantity']
            : int.parse(data['quantity']?.toString() ?? '0');
        final price = (data['price'] ?? 0).toDouble();
        totalValue += (price * quantity);
      }

      return totalValue;
    } catch (e) {
      //print('❌ Error getting total inventory value: $e');

      // Fallback to cache
      final cachedItems = _localStorage.getInventoryItems();
      double totalValue = 0.0;
      for (var item in cachedItems) {
        totalValue += item.totalValue;
      }
      return totalValue;
    }
  }

  Future<List<Category>> getCategoriesWithCount() async {
    try {
      final snapshot = await _userCategoriesCollection.orderBy('name').get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Category.fromMap(data, doc.id);
      }).toList();
    } catch (e) {
      //print('Error getting categories: $e');
      return [];
    }
  }

  // Get categories for dropdown (name only)
  Future<List<String>> getCategoriesForDropdown() async {
    try {
      final snapshot = await _userCategoriesCollection.orderBy('name').get();

      return snapshot.docs
          .map((doc) =>
              (doc.data() as Map<String, dynamic>)['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      //print('Error getting categories for dropdown: $e');
      return [];
    }
  }
// In inventory_repo_service.dart - updateCategory method

// Update category with item count and update all items with this category
Future<void> updateCategory(String id, String name,
    {String? description, required String oldCategoryName}) async {
  try {
    //print('🔄 Updating category: $oldCategoryName -> $name');
    
    // Start a batch write for atomic operation
    final batch = _firestore.batch();

    // 1. Update the category document
    final categoryRef = _userCategoriesCollection.doc(id);
    batch.update(categoryRef, {
      'name': name,
      'description': description,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update all inventory items that have this category
    if (oldCategoryName != name) {
      //print('🔄 Updating all items from "$oldCategoryName" to "$name"');
      
      // Get all items with the old category name
      final itemsSnapshot = await _userInventoryCollection
          .where('category', isEqualTo: oldCategoryName)
          .where('isActive', isEqualTo: true)
          .get();

      //print('📋 Found ${itemsSnapshot.docs.length} items to update');

      // Update each item in the batch
      for (final doc in itemsSnapshot.docs) {
        batch.update(doc.reference, {
          'category': name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Commit the batch
    await batch.commit();
    //print('✅ Category and related items updated successfully');

    // Update category in cache (if you have local storage)
    // await _localStorage.updateCategory(...);
    
  } catch (e) {
    //print('❌ Error updating category: $e');
    throw Exception('Failed to update category: $e');
  }
}
  // Delete category with cache update
  Future<void> deleteCategory(String id, String name) async {
    try {
      // Check if category is being used by any items
      final itemsSnapshot = await _userInventoryCollection
          .where('category', isEqualTo: name)
          .where('isActive', isEqualTo: true)
          .get();

      if (itemsSnapshot.docs.isNotEmpty) {
        throw Exception(
            'Cannot delete category "$name" because it has ${itemsSnapshot.docs.length} item(s)');
      }

      await _userCategoriesCollection.doc(id).delete();

      // Delete from cache
      await _localStorage.deleteCategory(id);

      //print('✅ Category "$name" deleted successfully');
    } catch (e) {
      //print('❌ Error deleting category: $e');
      rethrow;
    }
  }

  // Permanently delete item with cache update
  Future<void> permanentlyDeleteItem(String id) async {
    try {
      final item = await getInventoryItem(id);

      // Delete the item document
      await _userInventoryCollection.doc(id).delete();

      // Decrement category count
      if (item.category.isNotEmpty && item.category != 'Uncategorized') {
        await updateCategoryItemCount(item.category, increment: -1);
      }

      // Delete from cache
      await _localStorage.deleteInventoryItem(id);

      //print('✅ Item permanently deleted: ${item.name}');
    } catch (e) {
      //print('❌ Error permanently deleting item: $e');
      throw Exception('Failed to delete item: $e');
    }
  }

  Stream<List<Category>> streamCategories() {
    return _userCategoriesCollection
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      final categories = snapshot.docs.map((doc) {
        return Category.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();

      // Update cache
      _localStorage.saveCategories(categories);

      return categories;
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
  Future<void> updateCategoryItemCount(String categoryName,
      {required int increment}) async {
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

        // Update cache
        final updatedCategory = Category(
          id: doc.id,
          name: categoryName,
          description: data['description'],
          itemCount: currentCount + increment,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _localStorage.updateCategory(updatedCategory);
      } else {
        // Category doesn't exist in categories collection, create it
        final docRef = await _userCategoriesCollection.add({
          'name': categoryName,
          'itemCount': increment > 0 ? 1 : 0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Add to cache
        final newCategory = Category(
          id: docRef.id,
          name: categoryName,
          description: null,
          itemCount: increment > 0 ? 1 : 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _localStorage.addCategory(newCategory);
      }
    } catch (e) {
      //print('Error updating category count: $e');
    }
  }

  // ========== SUPPLIER METHODS ========== //

  // Get all suppliers for this user
  Future<List<String>> getSuppliers() async {
    try {
      final snapshot = await _userSuppliersCollection.orderBy('name').get();

      final suppliers = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return data['name'] as String? ?? '';
          })
          .where((name) => name.isNotEmpty)
          .toList();

      return suppliers;
    } catch (e) {
      //print('❌ Error getting suppliers: $e');
      return [];
    }
  }

  // Add new supplier
  Future<void> addSupplier(String name,
      {String? contact, String? email, String? phone}) async {
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
      //print('❌ Error adding supplier: $e');
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
          .map((doc) =>
              (doc.data() as Map<String, dynamic>)['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      //print('Error getting suppliers for dropdown: $e');
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
      //print('Error getting supplier details: $e');
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
      //print('Error getting supplier by ID: $e');
      return null;
    }
  }

  // Update supplier
  Future<void> updateSupplier(String id, String name,
      {String? contact, String? email, String? phone}) async {
    try {
      await _userSuppliersCollection.doc(id).update({
        'name': name,
        'contact': contact,
        'email': email,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      //print('Error updating supplier: $e');
      throw Exception('Failed to update supplier');
    }
  }

  // Get inventory summary for AI context
  Future<Map<String, dynamic>> getInventorySummary() async {
    final items = await getAllInventoryItems();
    final stats = await getInventoryStats();

    return {
      'stats': stats,
      'categories': items.map((i) => i.category).toSet().toList(),
      'recentItems': items.take(10).map((i) => i.toMap()).toList(),
      'lowStockItems':
          items.where((i) => i.isLowStock).map((i) => i.toMap()).toList(),
    };
  }

  // Execute AI actions
  // Execute AI actions
  Future<dynamic> executeAiAction(
      String action, Map<String, dynamic> params) async {
    switch (action) {
      case 'get_item':
        final sku = params['sku'];
        final items = await getAllInventoryItems();
        try {
          return items.firstWhere((i) => i.sku == sku);
        } catch (e) {
          return null; // Return null instead of throwing
        }

      case 'get_low_stock':
        final items = await getAllInventoryItems();
        return items.where((i) => i.isLowStock).toList();

      case 'search':
        final query = params['query'];
        return searchItemsLocally(query: query);

      default:
        throw Exception('Unknown action: $action');
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
      //print('Error deleting supplier: $e');
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
      //print('Error getting supplier item count: $e');
      return 0;
    }
  }
}
