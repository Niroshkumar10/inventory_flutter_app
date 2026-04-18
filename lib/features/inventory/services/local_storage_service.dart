import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inventory_item_model.dart';
import '../models/category_model.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static const String INVENTORY_ITEMS_KEY = 'inventory_items';
  static const String CATEGORIES_KEY = 'categories';
  static const String SEARCH_HISTORY_KEY = 'search_history';
  static const String SEARCH_HISTORY_WITH_TIME_KEY = 'search_history_with_time';
  static const String LAST_SYNC_KEY = 'last_sync_timestamp';
  static const int CACHE_DURATION_HOURS = 24;

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ========== INVENTORY ITEMS METHODS ==========

// In saveInventoryItems method:
Future<void> saveInventoryItems(List<InventoryItem> items) async {
  try {
    // Use toCacheMap() instead of toMap()
    final itemsJson = items.map((item) => item.toCacheMap()).toList();
    await _prefs.setString(INVENTORY_ITEMS_KEY, jsonEncode(itemsJson));
    await _prefs.setInt(LAST_SYNC_KEY, DateTime.now().millisecondsSinceEpoch);
    //print('✅ Saved ${items.length} items to local storage');
  } catch (e) {
    //print('❌ Error saving items to local storage: $e');
  }
}

// In getInventoryItems method:
List<InventoryItem> getInventoryItems() {
  try {
    final itemsString = _prefs.getString(INVENTORY_ITEMS_KEY);
    if (itemsString == null) return [];

    final List<dynamic> itemsJson = jsonDecode(itemsString);
    return itemsJson.map((json) {
      // Use fromCacheMap instead of fromMap
      return InventoryItem.fromCacheMap(
        Map<String, dynamic>.from(json),
        json['id'] ?? '',
      );
    }).toList();
  } catch (e) {
    //print('❌ Error reading items from local storage: $e');
    return [];
  }
}

// In addInventoryItem method:
Future<void> addInventoryItem(InventoryItem item) async {
  final items = getInventoryItems();
  items.add(item);
  await saveInventoryItems(items);
}

// In updateInventoryItem method:
Future<void> updateInventoryItem(InventoryItem updatedItem) async {
  final items = getInventoryItems();
  final index = items.indexWhere((item) => item.id == updatedItem.id);
  if (index != -1) {
    items[index] = updatedItem;
    await saveInventoryItems(items);
  }
}
// In local_storage_service.dart - add this method

// Update all items with a specific category to a new category name
Future<void> updateItemsCategory(String oldCategoryName, String newCategoryName) async {
  try {
    final items = getInventoryItems(); // Assuming you have this method
    final updatedItems = items.map((item) {
      if (item.category == oldCategoryName) {
        return item.copyWith(category: newCategoryName);
      }
      return item;
    }).toList();
    
    await saveInventoryItems(updatedItems); // Assuming you have this method
    //print('✅ Updated items category from "$oldCategoryName" to "$newCategoryName" in cache');
  } catch (e) {
    //print('❌ Error updating items category in cache: $e');
  }
}
  // Delete inventory item
  Future<void> deleteInventoryItem(String id) async {
    final items = getInventoryItems();
    items.removeWhere((item) => item.id == id);
    await saveInventoryItems(items);
  }

  // ========== CATEGORIES METHODS ==========

// In LocalStorageService, update saveCategories:
Future<void> saveCategories(List<Category> categories) async {
  try {
    final categoriesJson = categories.map((category) => category.toCacheMap()).toList();
    await _prefs.setString(CATEGORIES_KEY, jsonEncode(categoriesJson));
    //print('✅ Saved ${categories.length} categories to local storage');
  } catch (e) {
    //print('❌ Error saving categories to local storage: $e');
  }
}

// Update getCategories:
List<Category> getCategories() {
  try {
    final categoriesString = _prefs.getString(CATEGORIES_KEY);
    if (categoriesString == null) return [];

    final List<dynamic> categoriesJson = jsonDecode(categoriesString);
    return categoriesJson.map((json) {
      return Category.fromCacheMap(Map<String, dynamic>.from(json));
    }).toList();
  } catch (e) {
    //print('❌ Error reading categories from local storage: $e');
    return [];
  }
}
  // Add category
  Future<void> addCategory(Category category) async {
    final categories = getCategories();
    categories.add(category);
    await saveCategories(categories);
  }

  // Update category
  Future<void> updateCategory(Category updatedCategory) async {
    final categories = getCategories();
    final index = categories.indexWhere((c) => c.id == updatedCategory.id);
    if (index != -1) {
      categories[index] = updatedCategory;
      await saveCategories(categories);
    }
  }

  // Delete category
  Future<void> deleteCategory(String id) async {
    final categories = getCategories();
    categories.removeWhere((c) => c.id == id);
    await saveCategories(categories);
  }

  // ========== SEARCH METHODS ==========

  // Basic search in local storage
  List<InventoryItem> searchItems(String query) {
    if (query.isEmpty) return [];
    
    final items = getInventoryItems();
    final lowerQuery = query.toLowerCase();
    
    return items.where((item) {
      return item.name.toLowerCase().contains(lowerQuery) ||
             item.sku.toLowerCase().contains(lowerQuery) ||
             item.description.toLowerCase().contains(lowerQuery) ||
             item.category.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // Advanced search with filters
  List<InventoryItem> advancedSearch({
    String? query,
    String? category,
    String? supplierId,
    bool? lowStockOnly,
    double? minPrice,
    double? maxPrice,
  }) {
    final items = getInventoryItems();
    
    return items.where((item) {
      bool matches = true;

      if (query != null && query.isNotEmpty) {
        final lowerQuery = query.toLowerCase();
        matches = matches && (
          item.name.toLowerCase().contains(lowerQuery) ||
          item.sku.toLowerCase().contains(lowerQuery) ||
          item.description.toLowerCase().contains(lowerQuery)
        );
      }

      if (category != null && category.isNotEmpty && category != 'All') {
        matches = matches && item.category == category;
      }

      if (supplierId != null && supplierId.isNotEmpty) {
        matches = matches && item.supplierId == supplierId;
      }

      if (lowStockOnly == true) {
        matches = matches && item.isLowStock;
      }

      if (minPrice != null) {
        matches = matches && item.price >= minPrice;
      }

      if (maxPrice != null) {
        matches = matches && item.price <= maxPrice;
      }

      return matches;
    }).toList();
  }

  // Save search query to history
  Future<void> saveSearchQuery(String query) async {
    try {
      // Simple history (just strings)
      List<String> history = _prefs.getStringList(SEARCH_HISTORY_KEY) ?? [];
      history.remove(query);
      history.insert(0, query);
      if (history.length > 10) {
        history = history.sublist(0, 10);
      }
      await _prefs.setStringList(SEARCH_HISTORY_KEY, history);

      // History with timestamps
      List<String> historyWithTime = _prefs.getStringList(SEARCH_HISTORY_WITH_TIME_KEY) ?? [];
      final searchEntry = jsonEncode({
        'query': query,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Remove old entry with same query
      historyWithTime.removeWhere((entry) {
        try {
          final Map<String, dynamic> map = jsonDecode(entry);
          return map['query'] == query;
        } catch (_) {
          return false;
        }
      });
      
      historyWithTime.insert(0, searchEntry);
      if (historyWithTime.length > 20) {
        historyWithTime = historyWithTime.sublist(0, 20);
      }
      await _prefs.setStringList(SEARCH_HISTORY_WITH_TIME_KEY, historyWithTime);
      
    } catch (e) {
      //print('❌ Error saving search history: $e');
    }
  }

  // Get search history (simple)
  List<String> getSearchHistory() {
    return _prefs.getStringList(SEARCH_HISTORY_KEY) ?? [];
  }

  // Get search history with timestamps
  List<Map<String, dynamic>> getSearchHistoryWithTime() {
    try {
      final historyWithTime = _prefs.getStringList(SEARCH_HISTORY_WITH_TIME_KEY) ?? [];
      return historyWithTime.map((entry) {
        try {
          return jsonDecode(entry) as Map<String, dynamic>;
        } catch (_) {
          return {'query': entry, 'timestamp': 0};
        }
      }).toList();
    } catch (e) {
      //print('❌ Error getting search history with time: $e');
      return [];
    }
  }

  // Clear search history
  Future<void> clearSearchHistory() async {
    await _prefs.remove(SEARCH_HISTORY_KEY);
    await _prefs.remove(SEARCH_HISTORY_WITH_TIME_KEY);
  }

  // Get suggestions based on partial input
  List<String> getSuggestions(String partial) {
    if (partial.isEmpty) return [];
    
    final items = getInventoryItems();
    final suggestions = <String>{};
    final lowerPartial = partial.toLowerCase();
    
    for (var item in items) {
      if (item.name.toLowerCase().contains(lowerPartial)) {
        suggestions.add(item.name);
      }
      if (item.sku.toLowerCase().contains(lowerPartial)) {
        suggestions.add(item.sku);
      }
    }
    
    return suggestions.take(5).toList();
  }

  // ========== CACHE MANAGEMENT METHODS ==========

  // Clear all cache
  Future<void> clearAllCache() async {
    await _prefs.remove(INVENTORY_ITEMS_KEY);
    await _prefs.remove(CATEGORIES_KEY);
    await _prefs.remove(LAST_SYNC_KEY);
    //print('✅ Cleared all local cache');
  }

  // Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final items = getInventoryItems();
    final categories = getCategories();
    final lastSync = _prefs.getInt(LAST_SYNC_KEY);
    
    return {
      'itemsCount': items.length,
      'categoriesCount': categories.length,
      'lastSync': lastSync,
      'lastSyncFormatted': lastSync != null 
          ? DateTime.fromMillisecondsSinceEpoch(lastSync).toString()
          : 'Never',
      'cacheValid': isCacheValid(),
    };
  }

  // Check if cache is valid
  bool isCacheValid() {
    final lastSync = _prefs.getInt(LAST_SYNC_KEY);
    if (lastSync == null) return false;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffHours = (now - lastSync) / (1000 * 60 * 60);
    
    return diffHours < CACHE_DURATION_HOURS;
  }

  // Get item by ID
  InventoryItem? getItemById(String id) {
    final items = getInventoryItems();
    try {
      return items.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get category by ID
  Category? getCategoryById(String id) {
    final categories = getCategories();
    try {
      return categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get category by name
  Category? getCategoryByName(String name) {
    final categories = getCategories();
    try {
      return categories.firstWhere((category) => category.name == name);
    } catch (e) {
      return null;
    }
  }

  // Get items by category
  List<InventoryItem> getItemsByCategory(String categoryName) {
    final items = getInventoryItems();
    return items.where((item) => item.category == categoryName).toList();
  }

  // Get low stock items
  List<InventoryItem> getLowStockItems() {
    final items = getInventoryItems();
    return items.where((item) => item.isLowStock).toList();
  }

  // Get total inventory value from cache
  double getTotalInventoryValue() {
    final items = getInventoryItems();
    double total = 0.0;
    for (var item in items) {
      total += item.totalValue;
    }
    return total;
  }

  // Check if cache has data
  bool hasData() {
    return getInventoryItems().isNotEmpty;
  }

  // Get cache age in hours
  double getCacheAgeHours() {
    final lastSync = _prefs.getInt(LAST_SYNC_KEY);
    if (lastSync == null) return -1;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSync) / (1000 * 60 * 60);
  }
}