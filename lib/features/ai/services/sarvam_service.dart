// lib/features/ai/services/sarvam_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../inventory/services/inventory_repo_service.dart';
import '../../inventory/models/inventory_item_model.dart';

class SarvamService {
  final String apiKey;
  final String baseUrl;
  final InventoryService inventoryRepo;
  
  SarvamService({
    required this.apiKey,
    required this.baseUrl,
    required this.inventoryRepo,
  });

  // Get inventory context for AI
  Future<Map<String, dynamic>> _getInventoryContext() async {
    try {
      final items = await inventoryRepo.getAllInventoryItems();
      final stats = await inventoryRepo.getInventoryStats();
      
      // Calculate values by category
      Map<String, double> categoryValues = {};
      Map<String, int> categoryCounts = {};
      
      for (var item in items) {
        final category = item.category;
        final value = item.price * item.quantity;
        
        categoryValues[category] = (categoryValues[category] ?? 0) + value;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
      
      // Format items for display
      final itemsList = items.map((item) => {
        'id': item.id,
        'name': item.name,
        'sku': item.sku,
        'quantity': item.quantity,
        'price': item.price,
        'cost': item.cost,
        'category': item.category,
        'location': item.location,
        'supplier': item.supplierName,
        'isLowStock': item.isLowStock,
        'totalValue': item.price * item.quantity,
      }).toList();
      
      // Fix null safety issues with where clause
      final suppliers = items
          .map((i) => i.supplierName)
          .where((s) => s != null && s.isNotEmpty)
          .toSet()
          .toList();
          
      final locations = items
          .map((i) => i.location)
          .where((l) => l != null && l.isNotEmpty)
          .toSet()
          .toList();
      
      return {
        'stats': stats,
        'items': itemsList,
        'itemsCount': items.length,
        'lowStockItems': items.where((i) => i.isLowStock).map((i) => i.toMap()).toList(),
        'categories': items.map((i) => i.category).toSet().toList(),
        'categoryValues': categoryValues,
        'categoryCounts': categoryCounts,
        'totalValue': stats['totalValue'],
        'suppliers': suppliers,
        'locations': locations,
      };
    } catch (e) {
      print('Error getting inventory context: $e');
      return {};
    }
  }

  // Query inventory with AI
  Future<String> queryInventory(String userQuery) async {
    try {
      final context = await _getInventoryContext();
      final items = context['items'] as List;
      final itemsCount = context['itemsCount'] as int;
      final categories = context['categories'] as List;
      final suppliers = context['suppliers'] as List;
      final locations = context['locations'] as List;
      final totalValue = context['totalValue'] as double;
      final categoryValues = context['categoryValues'] as Map<String, double>;
      final categoryCounts = context['categoryCounts'] as Map<String, int>;
      
      final query = userQuery.toLowerCase().trim();
      
      // ========== GREETINGS ==========
      if (query == 'hi' || query == 'hello' || query == 'hey' || query == 'help') {
        return '''👋 Hello! I'm your AI inventory assistant.

📊 **Inventory Summary:**
• Total Items: **$itemsCount**
• Categories: **${categories.length}**
• Low Stock Items: **${context['lowStockItems'].length}**
• Total Value: **₹${totalValue.toStringAsFixed(2)}**

💡 **You can ask me:**
• "List all items"
• "Show [category] items" (e.g., "Show grocery items")
• "Low stock items"
• "Search [item name]"
• "Items by supplier [supplier name]"
• "Items in location [location]"
• "Inventory value"
• "Category summary"
• "Item details for [SKU or name]"
• "supplier"
• "Export inventory report"''';
      }
      
      // ========== INVENTORY VALUE QUERY ==========
      else if (query.contains('inventory value') || 
               query.contains('total value') || 
               query.contains('inventory worth') ||
               query == 'value' ||
               query == 'total') {
        
        if (items.isEmpty) {
          return '📭 Your inventory is empty. No value to display.';
        }
        
        String response = '💰 **Total Inventory Value: ₹${totalValue.toStringAsFixed(2)}**\n\n';
        response += '📊 **Breakdown by Category:**\n';
        
        // Sort categories by value (highest first)
        var sortedCategories = categoryValues.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        for (var entry in sortedCategories) {
          final percentage = ((entry.value / totalValue) * 100).toStringAsFixed(1);
          final itemCount = categoryCounts[entry.key] ?? 0;
          response += '• **${entry.key}**\n';
          response += '  - Value: ₹${entry.value.toStringAsFixed(2)} ($percentage%)\n';
          response += '  - Items: $itemCount\n\n';
        }
        
        // Add summary
        response += '📈 **Summary:**\n';
        response += '• Average value per item: ₹${(totalValue / itemsCount).toStringAsFixed(2)}\n';
        response += '• Highest value category: **${sortedCategories.first.key}**\n';
        
        return response;
      }
      
      // ========== LIST ALL ITEMS ==========
      else if (query.contains('list all items') || 
               query.contains('show all items') || 
               query == 'items' ||
               query.contains('all items')) {
        if (items.isEmpty) {
          return '📭 Your inventory is empty. No items to display.';
        }
        
        String response = '📋 **All Items (${items.length})**\n\n';
        
        // Group by category for better organization
        Map<String, List> itemsByCategory = {};
        for (var item in items) {
          final category = item['category'] ?? 'Uncategorized';
          itemsByCategory.putIfAbsent(category, () => []).add(item);
        }
        
        itemsByCategory.forEach((category, categoryItems) {
          response += '**$category** (${categoryItems.length} items):\n';
          for (var item in categoryItems) {
            response += '  • ${item['name']} - Qty: ${item['quantity']}, SKU: ${item['sku']}\n';
          }
          response += '\n';
        });
        
        return response;
      }
      
      // ========== CATEGORY SPECIFIC ITEMS ==========
      else {
        // Try to extract category from query
        String? targetCategory;
        
        // Check for "show me X items" pattern
        final showMeMatch = RegExp(r'show me (\w+) items').firstMatch(query);
        if (showMeMatch != null) {
          targetCategory = showMeMatch.group(1);
        }
        
        // Check for "X items" pattern
        final itemsMatch = RegExp(r'(\w+) items').firstMatch(query);
        if (itemsMatch != null && targetCategory == null) {
          targetCategory = itemsMatch.group(1);
        }
        
        // Check for "in X category" pattern
        final categoryMatch = RegExp(r'in (\w+) category').firstMatch(query);
        if (categoryMatch != null) {
          targetCategory = categoryMatch.group(1);
        }
        
        // Check if query directly matches a category name
        if (targetCategory == null) {
          for (var category in categories) {
            if (query.contains(category.toString().toLowerCase())) {
              targetCategory = category.toString().toLowerCase();
              break;
            }
          }
        }
        
        // If we found a category, show items in that category
        if (targetCategory != null) {
          final categoryItems = items.where((item) => 
            item['category'].toString().toLowerCase().contains(targetCategory!)
          ).toList();
          
          if (categoryItems.isEmpty) {
            return '❌ No items found in category: **$targetCategory**\n\nAvailable categories: ${categories.join(', ')}';
          }
          
          // Calculate category total value
          double categoryTotal = 0;
          for (var item in categoryItems) {
            categoryTotal += item['price'] * item['quantity'];
          }
          
          String response = '📦 **${categoryItems.length} items in ${targetCategory} category**\n';
          response += '💰 Category Value: ₹${categoryTotal.toStringAsFixed(2)}\n\n';
          
          for (var item in categoryItems) {
            response += '• **${item['name']}**\n';
            response += '  SKU: ${item['sku']}\n';
            response += '  Quantity: ${item['quantity']}\n';
            response += '  Price: ₹${item['price']}\n';
            response += '  Value: ₹${(item['price'] * item['quantity']).toStringAsFixed(2)}\n';
            response += '  Location: ${item['location']}\n';
            if (item['isLowStock'] == true) {
              response += '  ⚠️ **LOW STOCK**\n';
            }
            response += '\n';
          }
          return response;
        }
      }
      
      // ========== SEARCH BY NAME/SKU ==========
      if (query.contains('search') || query.contains('find')) {
        // Extract search term
        final searchTerm = query
            .replaceAll('search', '')
            .replaceAll('find', '')
            .replaceAll('for', '')
            .trim();
        
        if (searchTerm.isEmpty) {
          return '🔍 What would you like to search for? Try: "search rice" or "find item with SKU 123"';
        }
        
        final matchingItems = items.where((item) {
          return item['name'].toString().toLowerCase().contains(searchTerm) ||
                 item['sku'].toString().toLowerCase().contains(searchTerm) ||
                 item['category'].toString().toLowerCase().contains(searchTerm);
        }).toList();
        
        if (matchingItems.isEmpty) {
          return '❌ No items found matching "$searchTerm"';
        }
        
        String response = '🔍 **Found ${matchingItems.length} items matching "$searchTerm":**\n\n';
        for (var item in matchingItems) {
          response += '• **${item['name']}**\n';
          response += '  SKU: ${item['sku']}, Qty: ${item['quantity']}\n';
          response += '  Category: ${item['category']}, Location: ${item['location']}\n';
          response += '  Value: ₹${(item['price'] * item['quantity']).toStringAsFixed(2)}\n\n';
        }
        return response;
      }
      
      // ========== LOW STOCK ITEMS ==========
      else if (query.contains('low stock') || query.contains('low quantity')) {
        final lowStock = items.where((item) => item['isLowStock'] == true).toList();
        if (lowStock.isEmpty) {
          return '✅ **Great news!** No items are currently low in stock.';
        }
        
        String response = '⚠️ **${lowStock.length} items with low stock:**\n\n';
        for (var item in lowStock) {
          response += '• **${item['name']}**\n';
          response += '  Current Stock: ${item['quantity']} units\n';
          response += '  SKU: ${item['sku']}\n';
          response += '  Category: ${item['category']}\n\n';
        }
        return response;
      }
      
      // ========== CATEGORY SUMMARY ==========
      else if (query.contains('category summary') || query.contains('categories summary')) {
        if (categories.isEmpty) {
          return 'No categories found in your inventory.';
        }
        
        String response = '📊 **Category Summary:**\n\n';
        
        // Sort categories by value
        var sortedCategories = categoryValues.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        for (var entry in sortedCategories) {
          final category = entry.key;
          final value = entry.value;
          final count = categoryCounts[category] ?? 0;
          final percentage = ((value / totalValue) * 100).toStringAsFixed(1);
          
          response += '**$category**\n';
          response += '  • Items: $count\n';
          response += '  • Total Value: ₹${value.toStringAsFixed(2)}\n';
          response += '  • % of Total: $percentage%\n\n';
        }
        
        return response;
      }
      
      // ========== SUPPLIER SPECIFIC ITEMS ==========
      else if (query.contains('supplier') || query.contains('suppliers')) {
        // Check if asking for items from a specific supplier
        for (var supplier in suppliers) {
          if (query.contains(supplier.toString().toLowerCase())) {
            final supplierItems = items.where((item) => 
              item['supplier'].toString().toLowerCase().contains(supplier.toString().toLowerCase())
            ).toList();
            
            if (supplierItems.isEmpty) {
              return 'No items found from supplier: $supplier';
            }
            
            double supplierValue = 0;
            for (var item in supplierItems) {
              supplierValue += item['price'] * item['quantity'];
            }
            
            String response = '📦 **Items from $supplier (${supplierItems.length}):**\n';
            response += '💰 Total Value: ₹${supplierValue.toStringAsFixed(2)}\n\n';
            
            for (var item in supplierItems) {
              response += '• ${item['name']} - Qty: ${item['quantity']}, Price: ₹${item['price']}\n';
            }
            return response;
          }
        }
        
        // Just show suppliers list
        if (suppliers.isEmpty) {
          return 'No suppliers found in your inventory.';
        }
        
        String response = '**Suppliers in your inventory:**\n';
        for (var supplier in suppliers) {
          final count = items.where((item) => item['supplier'] == supplier).length;
          response += '• $supplier ($count items)\n';
        }
        return response;
      }
      
      
      // ========== LOCATION SPECIFIC ITEMS ==========
      else if (query.contains('location') || query.contains('aisle')) {
        // Check if asking for items in a specific location
        for (var location in locations) {
          if (query.contains(location.toString().toLowerCase())) {
            final locationItems = items.where((item) => 
              item['location'].toString().toLowerCase().contains(location.toString().toLowerCase())
            ).toList();
            
            if (locationItems.isEmpty) {
              return 'No items found in location: $location';
            }
            
            String response = '📦 **Items in $location (${locationItems.length}):**\n\n';
            for (var item in locationItems) {
              response += '• ${item['name']} - Qty: ${item['quantity']}\n';
            }
            return response;
          }
        }
        
        // Just show locations list
        if (locations.isEmpty) {
          return 'No locations found in your inventory.';
        }
        
        String response = '**Storage locations in your inventory:**\n';
        for (var location in locations) {
          final count = items.where((item) => item['location'] == location).length;
          response += '• $location ($count items)\n';
        }
        return response;
      }
      
      // ========== ITEM DETAILS BY SKU OR NAME ==========
      else if (query.contains('details') || query.contains('info about')) {
        final searchTerm = query
            .replaceAll('details', '')
            .replaceAll('info about', '')
            .replaceAll('for', '')
            .trim();
        
        if (searchTerm.isEmpty) {
          return 'Please specify which item you want details for. Example: "details for SKU123" or "info about rice"';
        }
        
        final matchingItems = items.where((item) {
          return item['name'].toString().toLowerCase().contains(searchTerm) ||
                 item['sku'].toString().toLowerCase().contains(searchTerm);
        }).toList();
        
        if (matchingItems.isEmpty) {
          return 'No items found matching "$searchTerm"';
        }
        
        if (matchingItems.length > 1) {
          String response = 'Found multiple items. Please be more specific:\n\n';
          for (var item in matchingItems) {
            response += '• ${item['name']} (SKU: ${item['sku']})\n';
          }
          return response;
        }
        
        final item = matchingItems.first;
        return '''📄 **Item Details: ${item['name']}**

**Basic Info:**
• SKU: ${item['sku']}
• Category: ${item['category']}
• Location: ${item['location']}
• Supplier: ${item['supplier']}

**Stock Info:**
• Current Quantity: ${item['quantity']}
• Unit Price: ₹${item['price']}
• Total Value: ₹${(item['price'] * item['quantity']).toStringAsFixed(2)}
${item['isLowStock'] == true ? '⚠️ **LOW STOCK WARNING**' : ''}

**Additional Info:**
• Cost Price: ₹${item['cost']}
• Profit Margin: ${(((item['price'] - item['cost']) / item['cost'] * 100)).toStringAsFixed(1)}%''';
      }
      
      // ========== EXPORT REPORT ==========
      else if (query.contains('export') || query.contains('report')) {
        return '''📊 **Inventory Report Summary**

**Overview:**
• Total Items: $itemsCount
• Total Categories: ${categories.length}
• Total Suppliers: ${suppliers.length}
• Total Value: ₹${totalValue.toStringAsFixed(2)}

**Stock Status:**
• In Stock: ${items.where((i) => i['quantity'] > 0).length} items
• Low Stock: ${items.where((i) => i['isLowStock']).length} items
• Out of Stock: ${items.where((i) => i['quantity'] == 0).length} items

**Top Categories by Value:**
${categoryValues.entries.toList()
  ..sort((a, b) => b.value.compareTo(a.value))
  ..take(3)
  .map((e) => '• ${e.key}: ₹${e.value.toStringAsFixed(2)}')
  .join('\n')}

To get a detailed CSV export, please use the export feature in the app.''';
      }
      
      // ========== DEFAULT RESPONSE ==========
      else {
        return '''I understand you're asking about "$userQuery". 

Here's what I can help you with:

📋 **View Items:**
• "List all items"
• "Show [category] items" (e.g., "Show grocery items")
• "Low stock items"

🔍 **Search:**
• "Search [item name]"
• "Find [SKU]"
• "Items by supplier [name]"

📊 **Analytics:**
• "Inventory value"
• "Category summary"
• "Export report"

❓ **Help:**
• Type "help" to see this menu again

What would you like to do?''';
      }
    } catch (e) {
      print('Error in queryInventory: $e');
      return 'Sorry, I encountered an error processing your request. Please try again.';
    }
  }

  // Search items with AI understanding
  Future<List<InventoryItem>> searchWithAI(String query) async {
    return inventoryRepo.searchLocally(query);
  }
}