// lib/features/ai/services/sarvam_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../inventory/services/inventory_repo_service.dart';
import '../../inventory/models/inventory_item_model.dart';
import '../../feedback/services/feedback_service.dart';
import '../../feedback/models/feedback_model.dart';
import '../../party/models/customer_model.dart';
import '../../party/models/supplier_model.dart';

class SarvamService {
  final String apiKey;
  final String baseUrl;
  final InventoryService inventoryRepo;
  FeedbackService? _feedbackService;
  String? _userMobile;

  SarvamService({
    required this.apiKey,
    required this.baseUrl,
    required this.inventoryRepo,
  });

  // Set user mobile for customers/suppliers access
  void setUserMobile(String userMobile) {
    _userMobile = userMobile;
  }

  // Set feedback service (call this after initialization)
  void setFeedbackService(FeedbackService feedbackService) {
    _feedbackService = feedbackService;
  }

  // Get customers list
  Future<List<Map<String, dynamic>>> _getCustomers() async {
    if (_userMobile == null) return [];
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userMobile)
          .collection('customers')
          // .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'mobile': data['mobile'] ?? '',
          'address': data['address'] ?? '',
          'isActive': data['isActive'] ?? true,
        };
      }).toList();
    } catch (e) {
      print('Error getting customers: $e');
      return [];
    }
  }

  // Get suppliers list
  Future<List<Map<String, dynamic>>> _getSuppliers() async {
    if (_userMobile == null) return [];
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userMobile)
          .collection('suppliers')
          // .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'phone': data['phone'] ?? '',
          'email': data['email'] ?? '',
          'address': data['address'] ?? '',
          'isActive': data['isActive'] ?? true,
        };
      }).toList();
    } catch (e) {
      print('Error getting suppliers: $e');
      return [];
    }
  }

  // Get inventory context with expiry information
  Future<Map<String, dynamic>> _getInventoryContext() async {
    try {
      final items = await inventoryRepo.getAllInventoryItems();
      final stats = await inventoryRepo.getInventoryStats();
      
      // Calculate values by category
      Map<String, double> categoryValues = {};
      Map<String, int> categoryCounts = {};
      
      // Expiry tracking
      List<Map<String, dynamic>> expiringSoon = [];
      List<Map<String, dynamic>> expiredItems = [];
      
      for (var item in items) {
        final category = item.category;
        final value = item.price * item.quantity;
        
        categoryValues[category] = (categoryValues[category] ?? 0) + value;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
        
        if (item.trackExpiry && item.expiryDate != null) {
          if (item.isExpired) {
            expiredItems.add({
              'name': item.name,
              'sku': item.sku,
              'expiryDate': item.expiryDate,
              'quantity': item.quantity,
              'daysOverdue': -item.daysUntilExpiry,
            });
          } else if (item.isNearExpiry) {
            expiringSoon.add({
              'name': item.name,
              'sku': item.sku,
              'expiryDate': item.expiryDate,
              'daysLeft': item.daysUntilExpiry,
              'quantity': item.quantity,
              'status': item.expiryStatus,
            });
          }
        }
      }
      
      expiringSoon.sort((a, b) => a['daysLeft'].compareTo(b['daysLeft']));
      
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
        'totalValue': item.totalValue,
        'trackExpiry': item.trackExpiry,
        'expiryDate': item.expiryDate?.toIso8601String(),
        'isExpired': item.isExpired,
        'isNearExpiry': item.isNearExpiry,
        'daysUntilExpiry': item.daysUntilExpiry,
        'expiryStatus': item.expiryStatus,
      }).toList();
      
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
      
      final itemsWithExpiry = items.where((i) => i.trackExpiry && i.expiryDate != null).length;
      
      return {
        'stats': stats,
        'items': itemsList,
        'itemsCount': items.length,
        'lowStockItems': items.where((i) => i.isLowStock).map((i) => i.toMap()).toList(),
        'categories': items.map((i) => i.category).toSet().toList(),
        'categoryValues': categoryValues,
        'categoryCounts': categoryCounts,
        'totalValue': stats['totalValue'] ?? 0,
        'suppliers': suppliers,
        'locations': locations,
        'expiringSoon': expiringSoon,
        'expiredItems': expiredItems,
        'itemsWithExpiry': itemsWithExpiry,
      };
    } catch (e) {
      print('Error getting inventory context: $e');
      return {};
    }
  }

  // Get feedback context with proper null handling
  Future<Map<String, int>> _getFeedbackContext() async {
    if (_feedbackService == null) {
      return {
        'total': 0,
        'pending': 0,
        'reviewed': 0,
        'resolved': 0,
        'client': 0,
        'supplier': 0,
        'avgRating': 0,
      };
    }
    
    try {
      final stats = await _feedbackService!.getFeedbackStats();
      return {
        'total': stats['total'] ?? 0,
        'pending': stats['pending'] ?? 0,
        'reviewed': stats['reviewed'] ?? 0,
        'resolved': stats['resolved'] ?? 0,
        'client': stats['client'] ?? 0,
        'supplier': stats['supplier'] ?? 0,
        'avgRating': stats['avgRating'] ?? 0,
      };
    } catch (e) {
      print('Error getting feedback context: $e');
      return {
        'total': 0,
        'pending': 0,
        'reviewed': 0,
        'resolved': 0,
        'client': 0,
        'supplier': 0,
        'avgRating': 0,
      };
    }
  }

  // Query inventory with AI
  Future<String> queryInventory(String userQuery) async {
    try {
      final context = await _getInventoryContext();
      final feedbackContext = await _getFeedbackContext();
      final customers = await _getCustomers();
      final suppliers = await _getSuppliers();
      
      final items = context['items'] as List;
      final itemsCount = context['itemsCount'] as int;
      final categories = context['categories'] as List;
      final totalValue = context['totalValue'] as double;
      final categoryValues = context['categoryValues'] as Map<String, double>;
      final categoryCounts = context['categoryCounts'] as Map<String, int>;
      final expiringSoon = context['expiringSoon'] as List;
      final expiredItems = context['expiredItems'] as List;
      final itemsWithExpiry = context['itemsWithExpiry'] as int;
      
      final query = userQuery.toLowerCase().trim();
      
      // ========== GREETINGS ==========
      if (query == 'hi' || query == 'hello' || query == 'hey' || query == 'help') {
        String response = '''👋 Hello! I'm your AI inventory assistant.

📊 **Inventory Summary:**
• Total Items: **$itemsCount**
• Categories: **${categories.length}**
• Low Stock Items: **${context['lowStockItems'].length}**
• Total Value: **₹${totalValue.toStringAsFixed(2)}**

👥 **Parties Summary:**
• Customers: **${customers.length}**
• Suppliers: **${suppliers.length}**

⏰ **Expiry Alerts:**
• Expiring Soon: **${expiringSoon.length}**
• Expired Items: **${expiredItems.length}**

⭐ **Feedback Summary:**
• Total: **${feedbackContext['total']}**
• Avg Rating: **${feedbackContext['avgRating']}/5**
• Pending: **${feedbackContext['pending']}**

💡 **You can ask me:**
• "List all items"
• "Show customers" / "Show suppliers"
• "Low stock items"
• "Expiring soon"
• "expired items"
• "Feedback summary"
• "Pending feedback"
• "Search [item name]"''';
        return response;
      }
      
      // ========== SHOW CUSTOMERS ==========
      else if (query.contains('show customers') || 
               query.contains('list customers') || 
               query.contains('all customers') ||
               (query == 'customers')) {
        
        if (customers.isEmpty) {
          return '👤 No customers found.\n\n💡 Add customers from the Parties section.';
        }
        
        String response = '👥 **Customers (${customers.length})**\n\n';
        for (var customer in customers) {
          response += '• **${customer['name']}**\n';
          if (customer['mobile'].toString().isNotEmpty) {
            response += '  📞 ${customer['mobile']}\n';
          }
          if (customer['address'].toString().isNotEmpty) {
            response += '  📍 ${customer['address']}\n';
          }
          response += '\n';
        }
        return response;
      }
      
      // ========== SHOW SUPPLIERS ==========
      else if (query.contains('show suppliers') || 
               query.contains('list suppliers') || 
               query.contains('all suppliers') ||
               (query == 'suppliers')) {
        
        if (suppliers.isEmpty) {
          return '🚚 No suppliers found.\n\n💡 Add suppliers from the Parties section.';
        }
        
        String response = '🚚 **Suppliers (${suppliers.length})**\n\n';
        for (var supplier in suppliers) {
          response += '• **${supplier['name']}**\n';
          if (supplier['phone'].toString().isNotEmpty) {
            response += '  📞 ${supplier['phone']}\n';
          }
          if (supplier['email'].toString().isNotEmpty) {
            response += '  📧 ${supplier['email']}\n';
          }
          response += '\n';
        }
        return response;
      }
      
      // ========== SEARCH CUSTOMER ==========
      else if (query.contains('search customer') || query.contains('find customer')) {
        String searchTerm = query
            .replaceAll('search customer', '')
            .replaceAll('find customer', '')
            .replaceAll('for', '')
            .trim();
        
        if (searchTerm.isEmpty) {
          return '🔍 Please specify a customer name to search. Example: "search customer John"';
        }
        
        final matchingCustomers = customers.where((c) =>
          c['name'].toString().toLowerCase().contains(searchTerm) ||
          c['mobile'].toString().contains(searchTerm)
        ).toList();
        
        if (matchingCustomers.isEmpty) {
          return '❌ No customers found matching "$searchTerm"';
        }
        
        String response = '🔍 **Found ${matchingCustomers.length} customer(s):**\n\n';
        for (var customer in matchingCustomers) {
          response += '• **${customer['name']}**\n';
          response += '  📞 ${customer['mobile']}\n';
          response += '  📍 ${customer['address']}\n\n';
        }
        return response;
      }
      
      // ========== SEARCH SUPPLIER ==========
      else if (query.contains('search supplier') || query.contains('find supplier')) {
        String searchTerm = query
            .replaceAll('search supplier', '')
            .replaceAll('find supplier', '')
            .replaceAll('for', '')
            .trim();
        
        if (searchTerm.isEmpty) {
          return '🔍 Please specify a supplier name to search. Example: "search supplier ABC Corp"';
        }
        
        final matchingSuppliers = suppliers.where((s) =>
          s['name'].toString().toLowerCase().contains(searchTerm) ||
          s['phone'].toString().contains(searchTerm)
        ).toList();
        
        if (matchingSuppliers.isEmpty) {
          return '❌ No suppliers found matching "$searchTerm"';
        }
        
        String response = '🔍 **Found ${matchingSuppliers.length} supplier(s):**\n\n';
        for (var supplier in matchingSuppliers) {
          response += '• **${supplier['name']}**\n';
          response += '  📞 ${supplier['phone']}\n';
          response += '  📧 ${supplier['email']}\n\n';
        }
        return response;
      }
      
      // ========== CUSTOMER COUNT ==========
      else if (query.contains('how many customers') || 
               query.contains('customer count') ||
               query.contains('total customers')) {
        return '👥 **Total Customers:** ${customers.length}\n\n${customers.isEmpty ? 'No customers added yet.' : 'You have ${customers.length} customer${customers.length > 1 ? 's' : ''} in your directory.'}';
      }
      
      // ========== SUPPLIER COUNT ==========
      else if (query.contains('how many suppliers') || 
               query.contains('supplier count') ||
               query.contains('total suppliers')) {
        return '🚚 **Total Suppliers:** ${suppliers.length}\n\n${suppliers.isEmpty ? 'No suppliers added yet.' : 'You have ${suppliers.length} supplier${suppliers.length > 1 ? 's' : ''} in your directory.'}';
      }
      
      // ========== FEEDBACK: SUMMARY (FIXED) ==========
      else if (query.contains('feedback summary') || 
               query.contains('feedback stats') || 
               query.contains('feedback overview') ||
               (query.contains('feedback') && query.contains('summary'))) {  
        
        final totalFeedback = feedbackContext['total'] ?? 0;
        
        if (totalFeedback == 0) {
          return '📭 No feedback submitted yet.\n\n💡 You can submit feedback by:\n1. Going to the Feedback section\n2. Tapping the "+" button\n3. Selecting Client or Supplier\n4. Sharing your experience';
        }
            String response = '⭐ **Feedback Summary**\n\n';
        response += '📊 **Overall Stats:**\n';
        response += '• Total Feedback: **${feedbackContext['total']}**\n';
        response += '• Average Rating: **${feedbackContext['avgRating']}/5** ⭐\n\n';
        
        response += '📋 **By Status:**\n';
        response += '• ⏳ Pending: **${feedbackContext['pending']}**\n';
        response += '• 👀 Reviewed: **${feedbackContext['reviewed']}**\n';
        response += '• ✅ Resolved: **${feedbackContext['resolved']}**\n\n';
        
        response += '👥 **By Type:**\n';
        response += '• 👤 Customers: **${feedbackContext['client']}**\n';
        response += '• 🚚 Suppliers: **${feedbackContext['supplier']}**\n';
        
        final avgRating = feedbackContext['avgRating'] ?? 0;
        response += '\n📈 **Insight:** ';
        if (avgRating >= 4.5) {
          response += 'Excellent satisfaction level! Keep up the great work! 🎉';
        } else if (avgRating >= 3.5) {
          response += 'Good overall, but review feedback for improvement areas. 👍';
        } else if (avgRating >= 2.5) {
          response += 'Average rating - consider addressing common concerns. 📊';
        } else if (avgRating > 0) {
          response += 'Needs attention - please review all feedback urgently. ⚠️';
        } else {
          response += 'Submit more feedback to get rating insights.';
        }
        
        return response;
      }
      
      // ========== FEEDBACK: PENDING ISSUES (FIXED) ==========
      else if (query.contains('pending feedback') || 
               query.contains('unresolved') || 
               query.contains('open issues') ||
               (query.contains('feedback') && query.contains('pending'))) {
        
        final pendingCount = feedbackContext['pending'] ?? 0;
        
        if (pendingCount == 0) {
          return '✅ **Great!** No pending feedback issues.\n\nAll feedback has been reviewed and resolved.';
        }
        
        return '''⏳ **$pendingCount pending feedback item${pendingCount > 1 ? 's' : ''}**

Please go to the **Feedback** section in the app to:
• Review pending feedback
• Respond to customer/supplier concerns
• Mark issues as resolved

💡 **Tip:** Regular review of feedback helps maintain good relationships.

**Quick Actions:**
1. Tap on "Feedback" in bottom navigation
2. Filter by "Pending" status
3. Review and respond to each item''';
      }
      
      // ========== FEEDBACK: RATINGS ANALYSIS (FIXED) ==========
      else if ((query.contains('rating') || query.contains('average rating')) && 
               (query.contains('feedback') || query.contains('review'))) {
        
        final avgRating = feedbackContext['avgRating'] ?? 0;
        final totalFeedback = feedbackContext['total'] ?? 0;
        
        if (totalFeedback == 0) {
          return 'No ratings available yet.\n\n💡 Submit feedback to see ratings! Go to Feedback → Add Feedback.';
        }
        
        String response = '⭐ **Rating Analysis**\n\n';
        response += '• Average Rating: **$avgRating/5**\n';
        response += '• Total Reviews: **$totalFeedback**\n\n';
        
        if (avgRating >= 4.5) {
          response += '🎉 **Excellent!** Your customers/suppliers are very satisfied.\n';
          response += 'Keep up the great work!';
        } else if (avgRating >= 3.5) {
          response += '👍 **Good!** Overall positive feedback.\n';
          response += 'Look at individual feedback for improvement areas.';
        } else if (avgRating >= 2.5) {
          response += '📊 **Average** - There\'s room for improvement.\n';
          response += 'Review the feedback to identify key issues.';
        } else if (avgRating > 0) {
          response += '⚠️ **Needs Attention** - Ratings are below average.\n';
          response += 'Please review all feedback and take action.';
        } else {
          response += 'No ratings available yet.';
        }
        
        return response;
      }
      
      // ========== EXPIRING SOON ==========
      else if (query.contains('expiring soon') || 
               query.contains('near expiry') ||
               query.contains('about to expire')) {
        
        if (expiringSoon.isEmpty) {
          if (itemsWithExpiry == 0) {
            return '📭 No items have expiry dates tracked.\n\n💡 To track expiry dates:\n1. Go to Add/Edit Item\n2. Enable "Track Expiry"\n3. Set the expiry date';
          }
          return '✅ No items are expiring in the next 30 days.';
        }
        
        String response = '⚠️ **${expiringSoon.length} items expiring soon:**\n\n';
        for (var item in expiringSoon) {
          final daysLeft = item['daysLeft'];
          String urgency = daysLeft <= 7 ? '🔴 URGENT' : (daysLeft <= 14 ? '🟡 Soon' : '🟢 OK');
          response += '• **${item['name']}** $urgency\n';
          response += '  Expires: ${_formatDate(item['expiryDate'])}\n';
          response += '  Days left: $daysLeft\n\n';
        }
        return response;
      }
      
      // ========== EXPIRED ITEMS ==========
      else if (query.contains('expired') && !query.contains('expiring')) {
        if (expiredItems.isEmpty) {
          return '✅ No expired items found in your inventory.';
        }
        
        String response = '❌ **${expiredItems.length} expired items:**\n\n';
        for (var item in expiredItems) {
          response += '• **${item['name']}**\n';
          response += '  Expired: ${_formatDate(item['expiryDate'])}\n';
          response += '  Overdue: ${item['daysOverdue']} days\n\n';
        }
        return response;
      }
      
      // ========== LOW STOCK ==========
      else if (query.contains('low stock')) {
        final lowStock = items.where((item) => item['isLowStock'] == true).toList();
        if (lowStock.isEmpty) {
          return '✅ No items are currently low in stock.';
        }
        
        String response = '⚠️ **${lowStock.length} low stock items:**\n\n';
        for (var item in lowStock) {
          response += '• **${item['name']}**\n';
          response += '  Current: ${item['quantity']} units\n';
          response += '  SKU: ${item['sku']}\n\n';
        }
        return response;
      }
      
      // ========== LIST ALL ITEMS ==========
      else if (query.contains('list all items') || query == 'items') {
        if (items.isEmpty) {
          return '📭 Your inventory is empty. Add items using the "+" button.';
        }
        
        String response = '📋 **All Items (${items.length})**\n\n';
        Map<String, List> itemsByCategory = {};
        for (var item in items) {
          final category = item['category'] ?? 'Uncategorized';
          itemsByCategory.putIfAbsent(category, () => []).add(item);
        }
        
        itemsByCategory.forEach((category, categoryItems) {
          response += '**$category** (${categoryItems.length}):\n';
          for (var item in categoryItems) {
            response += '  • ${item['name']} - ${item['quantity']} units, ₹${item['price']}\n';
          }
          response += '\n';
        });
        return response;
      }
      
      // ========== INVENTORY VALUE ==========
      else if (query.contains('inventory value') || query.contains('total value')) {
        if (items.isEmpty) {
          return '📭 Your inventory is empty. Total value: ₹0';
        }
        
        String response = '💰 **Total Inventory Value: ₹${totalValue.toStringAsFixed(2)}**\n\n';
        response += '📊 **Breakdown by Category:**\n';
        
        var sortedCategories = categoryValues.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        for (var entry in sortedCategories) {
          final percentage = ((entry.value / totalValue) * 100).toStringAsFixed(1);
          response += '• **${entry.key}**: ₹${entry.value.toStringAsFixed(2)} ($percentage%)\n';
        }
        return response;
      }
      
      // ========== SEARCH ITEMS ==========
      else if (query.contains('search') || query.contains('find')) {
        String searchTerm = query
            .replaceAll('search', '')
            .replaceAll('find', '')
            .replaceAll('for', '')
            .trim();
        
        if (searchTerm.isEmpty) {
          return '🔍 What would you like to search for? Example: "search rice"';
        }
        
        final matchingItems = items.where((item) {
          return item['name'].toString().toLowerCase().contains(searchTerm) ||
                 item['sku'].toString().toLowerCase().contains(searchTerm);
        }).toList();
        
        if (matchingItems.isEmpty) {
          return '❌ No items found matching "$searchTerm"';
        }
        
        String response = '🔍 **Found ${matchingItems.length} items:**\n\n';
        for (var item in matchingItems) {
          response += '• **${item['name']}**\n';
          response += '  SKU: ${item['sku']}, Qty: ${item['quantity']}\n';
          response += '  Price: ₹${item['price']}\n\n';
        }
        return response;
      }
      
      // ========== DEFAULT RESPONSE ==========
      else {
        return '''I understand you're asking about "$userQuery". 

Here's what I can help you with:

📋 **Inventory:**
• "List all items"
• "Low stock items"
• "Inventory value"

👥 **Parties:**
• "Show customers"
• "Show suppliers"
• "Search customer [name]"
• "How many customers?"

⏰ **Expiry:**
• "Expiring soon"
• "Expired items"

⭐ **Feedback:**
• "Feedback summary"
• "Pending feedback"
• "Average rating"

🔍 **Search:**
• "Search [item name]"

Type "help" to see this menu again.''';
      }
    } catch (e) {
      print('Error in queryInventory: $e');
      return 'Sorry, I encountered an error. Please try again or type "help" for available commands.';
    }
  }

  // Helper: Format date
  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }

  // Search items with AI understanding
  Future<List<InventoryItem>> searchWithAI(String query) async {
    return inventoryRepo.searchLocally(query);
  }
}