// lib/features/ai/services/sarvam_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../inventory/services/inventory_repo_service.dart';
import '../../inventory/models/inventory_item_model.dart';
import '../../feedback/services/feedback_service.dart';
import '../../inventory/models/batch_model.dart';
import 'package:inventory_app/core/utils/app_logger.dart';

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
      appLogger.d('Error getting customers: $e');
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
      appLogger.d('Error getting suppliers: $e');
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
    
    // ========== NEW: Batch tracking ==========
    List<Map<String, dynamic>> batchTrackedItems = [];
    List<Map<String, dynamic>> nearExpiryBatches = [];
    List<Map<String, dynamic>> expiredBatches = [];
    int totalBatches = 0;
    int totalBatchStock = 0;
    
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
      
      // ========== NEW: Process batch-tracked items ==========
      if (item.trackByBatch) {
        final batchSummary = await _getBatchSummaryForItem(item.id);
        final batchDetails = await _getBatchDetails(item.id);
        
totalBatches += (batchSummary['totalBatches'] as num?)?.toInt() ?? 0;
totalBatchStock += (batchSummary['totalRemaining'] as num?)?.toInt() ?? 0;
        
        // Collect near expiry batches
        for (var batch in batchDetails) {
          if (batch['isNearExpiry'] == true && !batch['isExpired']) {
            nearExpiryBatches.add({
              'itemName': item.name,
              'batchNumber': batch['batchNumber'],
              'remainingQuantity': batch['remainingQuantity'],
              'expiryDate': batch['expiryDate'],
              'daysUntilExpiry': batch['daysUntilExpiry'],
            });
          }
          if (batch['isExpired'] == true) {
            expiredBatches.add({
              'itemName': item.name,
              'batchNumber': batch['batchNumber'],
              'remainingQuantity': batch['remainingQuantity'],
              'expiryDate': batch['expiryDate'],
            });
          }
        }
        
        batchTrackedItems.add({
          'id': item.id,
          'name': item.name,
          'sku': item.sku,
          'unit': item.unit,
          'totalStock': batchSummary['totalRemaining'],
          'batchCount': batchSummary['totalBatches'],
          'expiredBatches': batchSummary['expiredBatches'],
          'nearExpiryBatches': batchSummary['nearExpiryBatches'],
          'earliestExpiry': batchSummary['earliestExpiry']?.toIso8601String(),
          'batches': batchDetails,
        });
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
      'trackByBatch': item.trackByBatch,  // ← ADD THIS
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
    final itemsWithBatch = items.where((i) => i.trackByBatch).length;
    
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
      // ========== NEW: Batch tracking context ==========
      'itemsWithBatch': itemsWithBatch,
      'totalBatches': totalBatches,
      'totalBatchStock': totalBatchStock,
      'batchTrackedItems': batchTrackedItems,
      'nearExpiryBatches': nearExpiryBatches,
      'expiredBatches': expiredBatches,
    };
  } catch (e) {
    appLogger.d('Error getting inventory context: $e');
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
      appLogger.d('Error getting feedback context: $e');
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
      // ========== GREETINGS ==========
if (query == 'hi' || query == 'hello' || query == 'hey' || query == 'help') {
  String response = '''👋 Hello! I'm your AI inventory assistant.

📊 **Inventory Summary:**
• Total Items: **$itemsCount**
• Categories: **${categories.length}**
• Low Stock Items: **${context['lowStockItems'].length}**
• Total Value: **₹${totalValue.toStringAsFixed(2)}**

📦 **Batch Tracking Summary:**
• Batch Items: **${context['itemsWithBatch']}**
• Total Batches: **${context['totalBatches']}**
• Total Batch Stock: **${context['totalBatchStock']} units**

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

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💬 **What can I help you with?**

📦 **BATCH TRACKING COMMANDS:**
• "batch items" - Show all batch-tracked items
• "batches of [item name]" - Show batches for a specific item
• "near expiry batches" - Batches expiring in next 30 days
• "expired batches" - Show expired batches
• "batch summary" - Complete batch overview
• "stock of batch [number]" - Check specific batch stock
• "batch sales of [number]" - Batch sales history
• "which batch to use" - FIFO recommendations
• "restock recommendations" - Items needing restock
• "batch performance" - Sell-through rates
• "expiry alert details" - Detailed expiry alerts

📋 **INVENTORY COMMANDS:**
• "list all items" - Show all inventory items
• "low stock items" - Items below threshold
• "inventory value" - Total value by category
• "search [item name]" - Find specific items

👥 **PARTY COMMANDS:**
• "show customers" - List all customers
• "show suppliers" - List all suppliers
• "search customer [name]" - Find customer
• "how many customers?" - Customer count
• "how many suppliers?" - Supplier count

⏰ **EXPIRY COMMANDS:**
• "expiring soon" - Items expiring in 30 days
• "expired items" - Show expired items

⭐ **FEEDBACK COMMANDS:**
• "feedback summary" - Overall feedback stats
• "pending feedback" - Unresolved feedback
• "average rating" - Rating analysis

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 **Tip:** Just type what you want to know!''';
  return response;
}
// ========== SHOW COMMANDS MENU ==========
else if (query == 'menu' || query == 'commands' || query == 'what can you do' || query == 'help menu') {
  return '''📋 **Available Commands Menu**

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 **BATCH TRACKING**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• "batch items" - Show all batch-tracked items
• "batches of [item]" - Show batches for an item
• "near expiry batches" - Batches expiring soon
• "expired batches" - Show expired batches
• "batch summary" - Complete batch overview
• "stock of batch [number]" - Check batch stock
• "batch sales of [number]" - Batch sales history
• "which batch to use" - FIFO recommendations
• "restock recommendations" - Low stock alerts
• "batch performance" - Sell-through rates
• "expiry alert details" - Detailed expiry alerts

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 **INVENTORY**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• "list all items" - All inventory items
• "low stock items" - Below threshold
• "inventory value" - Total value
• "search [item name]" - Find items

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👥 **PARTIES**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• "show customers" - List customers
• "show suppliers" - List suppliers
• "search customer [name]"
• "how many customers?"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏰ **EXPIRY**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• "expiring soon" - Items expiring in 30 days
• "expired items" - Expired items

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⭐ **FEEDBACK**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• "feedback summary" - Overall stats
• "pending feedback" - Unresolved
• "average rating" - Rating analysis

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 Type "help" to see full summary with your data.''';
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
      // Add these inside the queryInventory method after the existing patterns

// ========== BATCH: SHOW BATCH-TRACKED ITEMS ==========
else if (query.contains('batch items') || 
         query.contains('batch tracked') || 
         query.contains('batches')) {
  
  final batchTrackedItems = context['batchTrackedItems'] as List? ?? [];
  final totalBatches = context['totalBatches'] ?? 0;
  
  if (batchTrackedItems.isEmpty) {
    return '📦 **No batch-tracked items found.**\n\n'
        '💡 To enable batch tracking:\n'
        '1. Go to Add/Edit Item\n'
        '2. Enable "Track Expiry"\n'
        '3. Enable "Batch Tracking"\n\n'
        'Batch tracking helps you manage items with expiry dates like food, medicine, etc.';
  }
  
  String response = '📦 **Batch-Tracked Items (${batchTrackedItems.length})**\n\n';
  for (var item in batchTrackedItems) {
    response += '• **${item['name']}**\n';
    response += '  📊 Total Stock: ${item['totalStock']} ${item['unit']}\n';
    response += '  📦 Batches: ${item['batchCount']}\n';
    response += '  ⚠️ Near Expiry: ${item['nearExpiryBatches']}\n';
    response += '  ❌ Expired: ${item['expiredBatches']}\n\n';
  }
  response += '\n📊 **Summary:**\n';
  response += '• Total Batches: **$totalBatches**\n';
  response += '• Total Batch Stock: **${context['totalBatchStock']} units**\n';
  return response;
}

// ========== BATCH: SHOW BATCHES FOR A SPECIFIC ITEM ==========
else if (query.contains('batches of') || 
         query.contains('batch details for') || 
         query.contains('show batches')) {
  
  // Extract item name from query
  String itemName = query
      .replaceAll('batches of', '')
      .replaceAll('batch details for', '')
      .replaceAll('show batches for', '')
      .replaceAll('show batches of', '')
      .trim();
  
  if (itemName.isEmpty) {
    return '🔍 Please specify an item name.\n\nExample: "batches of rice" or "show batches for oil"';
  }
  
  final batchTrackedItems = context['batchTrackedItems'] as List? ?? [];
  final matchedItem = batchTrackedItems.firstWhere(
    (item) => item['name'].toString().toLowerCase().contains(itemName.toLowerCase()),
    orElse: () => null,
  );
  
  if (matchedItem == null) {
    return '❌ No batch-tracked item found matching "$itemName".\n\n'
        'Type "batch items" to see all batch-tracked items.';
  }
  
  final batches = matchedItem['batches'] as List? ?? [];
  
  if (batches.isEmpty) {
    return '📦 **${matchedItem['name']}** has no batches yet.\n\n'
        '💡 To add a batch:\n'
        '1. Go to the item details\n'
        '2. Tap "Add Batch"\n'
        '3. Enter quantity and expiry date';
  }
  
  String response = '📦 **Batches for ${matchedItem['name']}**\n\n';
  for (int i = 0; i < batches.length; i++) {
    final batch = batches[i];
    final remaining = batch['remainingQuantity'];
    final total = batch['quantity'];
    final expiryDate = batch['expiryDate'] != null 
        ? _formatDate(DateTime.parse(batch['expiryDate'])) 
        : 'Unknown';
    final isNearExpiry = batch['isNearExpiry'] == true;
    final isExpired = batch['isExpired'] == true;
    
    String statusIcon = '🟢';
    if (isExpired) {
      statusIcon = '❌';
    } else if (isNearExpiry) {
      statusIcon = '⚠️';
    }
    
    response += '$statusIcon **Batch ${i + 1}**\n';
    response += '  • Remaining: $remaining units\n';
    response += '  • Sold: ${batch['soldQuantity']} units\n';
    response += '  • Total: $total units\n';
    response += '  • Expires: $expiryDate\n';
    if (batch['supplierName'] != null && batch['supplierName'].isNotEmpty) {
      response += '  • Supplier: ${batch['supplierName']}\n';
    }
    response += '\n';
  }
  
  return response;
}

// ========== BATCH: NEAR EXPIRY BATCHES ==========
else if (query.contains('near expiry batches') || 
         query.contains('batches expiring soon')) {
  
  final nearExpiryBatches = context['nearExpiryBatches'] as List? ?? [];
  
  if (nearExpiryBatches.isEmpty) {
    return '✅ **No batches expiring soon.**\n\n'
        'All batches have more than 30 days until expiry.';
  }
  
  String response = '⚠️ **${nearExpiryBatches.length} batches expiring soon:**\n\n';
  for (var batch in nearExpiryBatches) {
    response += '• **${batch['itemName']}**\n';
    response += '  Batch: ${batch['batchNumber']}\n';
    response += '  Remaining: ${batch['remainingQuantity']} units\n';
    response += '  Expires in: ${batch['daysUntilExpiry']} days\n\n';
  }
  return response;
}

// ========== BATCH: EXPIRED BATCHES ==========
else if (query.contains('expired batches')) {
  
  final expiredBatches = context['expiredBatches'] as List? ?? [];
  
  if (expiredBatches.isEmpty) {
    return '✅ **No expired batches found.**\n\n'
        'All batches are within their expiry period.';
  }
  
  String response = '❌ **${expiredBatches.length} expired batches:**\n\n';
  for (var batch in expiredBatches) {
    response += '• **${batch['itemName']}**\n';
    response += '  Batch: ${batch['batchNumber']}\n';
    response += '  Remaining: ${batch['remainingQuantity']} units (should be written off)\n';
    response += '  Expired on: ${_formatDate(DateTime.parse(batch['expiryDate']))}\n\n';
  }
  response += '\n💡 **Recommendation:** Write off expired batches to maintain accurate inventory.';
  return response;
}

// ========== BATCH: BATCH SUMMARY ==========
else if (query.contains('batch summary') || 
         query.contains('batch overview')) {
  
  final batchTrackedItems = context['batchTrackedItems'] as List? ?? [];
  final totalBatches = context['totalBatches'] ?? 0;
  final totalBatchStock = context['totalBatchStock'] ?? 0;
  final nearExpiryCount = context['nearExpiryBatches'] as List? ?? [];
  final expiredCount = context['expiredBatches'] as List? ?? [];
  
  if (batchTrackedItems.isEmpty) {
    return '📦 **No batch-tracked items found.**\n\n'
        'Enable batch tracking on items with expiry dates.';
  }
  
  String response = '📊 **Batch Tracking Summary**\n\n';
  response += '📦 **Overview:**\n';
  response += '• Batch-Tracked Items: **${batchTrackedItems.length}**\n';
  response += '• Total Batches: **$totalBatches**\n';
  response += '• Total Stock: **$totalBatchStock units**\n\n';
  
  response += '⚠️ **Expiry Status:**\n';
  response += '• Near Expiry Batches: **${nearExpiryCount.length}**\n';
  response += '• Expired Batches: **${expiredCount.length}**\n\n';
  
  response += '📋 **Items with Batches:**\n';
  for (var item in batchTrackedItems) {
    response += '• **${item['name']}** - ${item['batchCount']} batches, ${item['totalStock']} units\n';
  }
  
  return response;
}
// ========== BATCH: TOTAL STOCK OF A SPECIFIC BATCH ==========
else if (query.contains('stock of batch') || 
         query.contains('batch stock') ||
         (query.contains('how many') && query.contains('batch'))) {
  
  // Extract batch number or item name from query
  String searchTerm = query
      .replaceAll('stock of batch', '')
      .replaceAll('batch stock of', '')
      .replaceAll('how many in batch', '')
      .replaceAll('how many', '')
      .trim();
  
  if (searchTerm.isEmpty) {
    return '🔍 Please specify a batch number or item name.\n\nExample: "stock of batch BATCH-20250420-1234" or "batch stock of oil"';
  }
  
  final batchTrackedItems = context['batchTrackedItems'] as List? ?? [];
  bool found = false;
  String response = '📊 **Batch Stock Information**\n\n';
  
  // Search for specific batch number
  for (var item in batchTrackedItems) {
    final batches = item['batches'] as List? ?? [];
    for (var batch in batches) {
      final batchNumber = batch['batchNumber'];
      if (batchNumber.toString().toLowerCase().contains(searchTerm.toLowerCase())) {
        found = true;
        response += '📦 **${item['name']}**\n';
        response += '• Batch: $batchNumber\n';
        response += '• Remaining: ${batch['remainingQuantity']} ${item['unit']}\n';
        response += '• Total Original: ${batch['quantity']} ${item['unit']}\n';
        response += '• Sold: ${batch['soldQuantity']} ${item['unit']}\n';
        response += '• Purchase Price: ₹${batch['purchasePrice']}\n';
        response += '• Expiry: ${_formatDate(DateTime.parse(batch['expiryDate']))}\n';
        response += '• Status: ${batch['isExpired'] ? "❌ EXPIRED" : (batch['isNearExpiry'] ? "⚠️ Near Expiry" : "✅ Active")}\n\n';
      }
    }
  }
  
  if (!found) {
    return '❌ No batch found matching "$searchTerm".\n\nType "batch items" to see all batch-tracked items.';
  }
  
  return response;
}

// ========== BATCH: BATCH HISTORY/SALES ==========
else if (query.contains('batch sales') || 
         query.contains('batch history') ||
         query.contains('sold from batch')) {
  
  String searchTerm = query
      .replaceAll('batch sales of', '')
      .replaceAll('batch history of', '')
      .replaceAll('sold from batch', '')
      .trim();
  
  if (searchTerm.isEmpty) {
    return '🔍 Please specify a batch number.\n\nExample: "batch sales of BATCH-20250420-1234"';
  }
  
  final batchTrackedItems = context['batchTrackedItems'] as List? ?? [];
  bool found = false;
  String response = '📈 **Batch Sales History**\n\n';
  
  for (var item in batchTrackedItems) {
    final batches = item['batches'] as List? ?? [];
    for (var batch in batches) {
      final batchNumber = batch['batchNumber'];
      if (batchNumber.toString().toLowerCase().contains(searchTerm.toLowerCase())) {
        found = true;
        response += '📦 **${item['name']} - $batchNumber**\n';
        response += '• Total Sold: ${batch['soldQuantity']} ${item['unit']}\n';
        response += '• Remaining: ${batch['remainingQuantity']} ${item['unit']}\n';
        response += '• Total: ${batch['quantity']} ${item['unit']}\n';
        response += '• Sales Rate: ${((batch['soldQuantity'] / batch['quantity']) * 100).toStringAsFixed(1)}% sold\n\n';
      }
    }
  }
  
  if (!found) {
    return '❌ No batch found matching "$searchTerm".';
  }
  
  return response;
}

// ========== BATCH: RECOMMENDATIONS (WHICH BATCH TO USE FIRST) ==========
else if (query.contains('which batch to use') || 
         query.contains('recommend batch') ||
         query.contains('use first')) {
  
  final batchTrackedItems = context['batchTrackedItems'] as List? ?? [];
  
  if (batchTrackedItems.isEmpty) {
    return '📦 No batch-tracked items found.\n\nEnable batch tracking on items with expiry dates.';
  }
  
  String response = '📋 **FIFO Recommendations (Use earliest expiry first)**\n\n';
  
  for (var item in batchTrackedItems) {
    final batches = item['batches'] as List? ?? [];
    if (batches.isEmpty) continue;
    
    // Sort batches by expiry date to find earliest
    batches.sort((a, b) {
      final dateA = DateTime.parse(a['expiryDate']);
      final dateB = DateTime.parse(b['expiryDate']);
      return dateA.compareTo(dateB);
    });
    
    final earliestBatch = batches.first;
    final earliestDate = _formatDate(DateTime.parse(earliestBatch['expiryDate']));
    final daysLeft = earliestBatch['daysUntilExpiry'];
    
    response += '• **${item['name']}**\n';
    response += '  ↳ Use batch expiring on **$earliestDate** ($daysLeft days left)\n';
    response += '  ↳ Remaining: ${earliestBatch['remainingQuantity']} ${item['unit']}\n\n';
  }
  
  response += '\n💡 **Tip:** Always use batches with earliest expiry dates first (FIFO) to minimize waste.';
  return response;
}

// ========== BATCH: RESTOCK RECOMMENDATIONS ==========
else if (query.contains('restock recommendations') || 
         query.contains('what to restock') ||
         query.contains('low stock batches')) {
  
  final batchTrackedItems = context['batchTrackedItems'] as List? ?? [];
  
  List<Map<String, dynamic>> lowStockBatches = [];
  
  for (var item in batchTrackedItems) {
    final batches = item['batches'] as List? ?? [];
    final totalStock = item['totalStock'] ?? 0;
    final lowStockThreshold = 10; // Default threshold
    
    if (totalStock < lowStockThreshold) {
      lowStockBatches.add({
        'name': item['name'],
        'unit': item['unit'],
        'totalStock': totalStock,
        'batches': batches,
      });
    }
  }
  
  if (lowStockBatches.isEmpty) {
    return '✅ **All batch-tracked items have adequate stock.**\n\nNo immediate restock needed.';
  }
  
  String response = '⚠️ **Restock Recommendations**\n\n';
  response += 'The following items are running low on stock:\n\n';
  
  for (var item in lowStockBatches) {
    response += '📦 **${item['name']}**\n';
    response += '• Total Stock: ${item['totalStock']} ${item['unit']}\n';
    
    // Find earliest expiry batch
    final batches = item['batches'] as List;
    if (batches.isNotEmpty) {
      batches.sort((a, b) {
        final dateA = DateTime.parse(a['expiryDate']);
        final dateB = DateTime.parse(b['expiryDate']);
        return dateA.compareTo(dateB);
      });
      final earliestBatch = batches.first;
      response += '• Earliest Expiry: ${_formatDate(DateTime.parse(earliestBatch['expiryDate']))}\n';
    }
    response += '\n';
  }
  
  response += '💡 **Action:** Consider restocking these items soon to avoid stockouts.';
  return response;
}

// ========== BATCH: BATCH EFFICIENCY/SELL-THROUGH RATE ==========
else if (query.contains('sell through rate') || 
         query.contains('batch efficiency') ||
         query.contains('batch performance')) {
  
  final batchTrackedItems = context['batchTrackedItems'] as List? ?? [];
  
  if (batchTrackedItems.isEmpty) {
    return '📦 No batch-tracked items found.';
  }
  
  String response = '📊 **Batch Performance / Sell-Through Rate**\n\n';
  
  for (var item in batchTrackedItems) {
    final batches = item['batches'] as List? ?? [];
    if (batches.isEmpty) continue;
    
    response += '📦 **${item['name']}**\n';
    
    for (int i = 0; i < batches.length; i++) {
      final batch = batches[i];
      final total = batch['quantity'];
      final sold = batch['soldQuantity'];
      final sellThroughRate = total > 0 ? (sold / total * 100).toStringAsFixed(1) : '0';
      
      String performanceIcon = '🟢';
      if (double.parse(sellThroughRate) >= 70) {
        performanceIcon = '🏆';
      } else if (double.parse(sellThroughRate) >= 40) {
        performanceIcon = '📈';
      } else if (double.parse(sellThroughRate) >= 20) {
        performanceIcon = '📊';
      } else {
        performanceIcon = '🔴';
      }
      
      response += '  $performanceIcon Batch ${i + 1}: $sellThroughRate% sold (${sold}/${total} ${item['unit']})\n';
    }
    response += '\n';
  }
  
  return response;
}

// ========== BATCH: EXPIRY ALERT DETAILS ==========
else if (query.contains('expiry alert details') || 
         query.contains('detailed expiry') ||
         query.contains('which batches expiring')) {
  
  final nearExpiryBatches = context['nearExpiryBatches'] as List? ?? [];
  final expiredBatches = context['expiredBatches'] as List? ?? [];
  
  if (nearExpiryBatches.isEmpty && expiredBatches.isEmpty) {
    return '✅ **No expiry alerts.**\n\nAll batches are valid and have more than 30 days until expiry.';
  }
  
  String response = '⚠️ **Detailed Expiry Alerts**\n\n';
  
  if (nearExpiryBatches.isNotEmpty) {
    response += '**🟡 NEAR EXPIRY (Within 30 days)**\n';
    for (var batch in nearExpiryBatches) {
      response += '• **${batch['itemName']}**\n';
      response += '  Batch: ${batch['batchNumber']}\n';
      response += '  Remaining: ${batch['remainingQuantity']} units\n';
      response += '  Expires in: ${batch['daysUntilExpiry']} days\n';
      response += '  ⚡ **Action:** Use immediately or run promotion\n\n';
    }
  }
  
  if (expiredBatches.isNotEmpty) {
    response += '**🔴 EXPIRED**\n';
    for (var batch in expiredBatches) {
      response += '• **${batch['itemName']}**\n';
      response += '  Batch: ${batch['batchNumber']}\n';
      response += '  Remaining: ${batch['remainingQuantity']} units\n';
      response += '  ⚡ **Action:** Write off immediately\n\n';
    }
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
      appLogger.d('Error in queryInventory: $e');
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
  // Get batch summary for a specific item
Future<Map<String, dynamic>> _getBatchSummaryForItem(String itemId) async {
  try {
    final batchSummary = await inventoryRepo.getBatchSummary(itemId);
    return batchSummary;
  } catch (e) {
    appLogger.d('Error getting batch summary for $itemId: $e');
    return {
      'totalRemaining': 0,
      'totalBatches': 0,
      'expiredBatches': 0,
      'nearExpiryBatches': 0,
      'earliestExpiry': null,
    };
  }
}

// Get detailed batch information for a specific item
// Get detailed batch information for a specific item
Future<List<Map<String, dynamic>>> _getBatchDetails(String itemId) async {
  try {
    final batchesWithDetails = await inventoryRepo.batchService.getBatchesWithDetails(itemId);
    return batchesWithDetails.map((batchData) {
      // Safely extract batch
      final batchRaw = batchData['batch'];
      if (batchRaw == null) return null;
      
      // Since batchRaw might be a Batch object or a Map
      Batch batch;
      if (batchRaw is Batch) {
        batch = batchRaw;
      } else {
        // If it's a Map, convert it
        return null;
      }
      
      return {
        'batchNumber': batch.batchNumber,
        'quantity': batch.quantity,
        'remainingQuantity': batch.remainingQuantity,
        'soldQuantity': batchData['totalSold'] ?? 0,
        'purchasePrice': batch.purchasePrice,
        'expiryDate': batch.expiryDate.toIso8601String(),
        'isExpired': batch.isExpired,
        'daysUntilExpiry': batch.daysUntilExpiry,
        'isNearExpiry': batch.isNearExpiry,
        'supplierName': batch.supplierName,
        'supplierInvoiceNo': batch.supplierInvoiceNo,
      };
    }).where((item) => item != null).toList().cast<Map<String, dynamic>>();
  } catch (e) {
    appLogger.d('Error getting batch details for $itemId: $e');
    return [];
  }
}
}
