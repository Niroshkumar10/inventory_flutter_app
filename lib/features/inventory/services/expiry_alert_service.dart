// lib/features/inventory/services/expiry_alert_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/batch_model.dart';
import '../models/inventory_item_model.dart';

class ExpiryAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userMobile;
  
  ExpiryAlertService(this.userMobile);
  
  CollectionReference get _userInventoryCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('inventory');
  }
  
  // Get all items with batches near expiry
  Future<List<Map<String, dynamic>>> getNearExpiryAlerts({int daysThreshold = 30}) async {
    try {
      final alerts = <Map<String, dynamic>>[];
      final inventoryItems = await _getAllInventoryItems();
      
      for (var item in inventoryItems) {
        if (!item.trackByBatch) continue;
        
        final batches = await _getNearExpiryBatchesForItem(item.id, daysThreshold);
        
        if (batches.isNotEmpty) {
          alerts.add({
            'item': item,
            'batches': batches,
            'totalNearExpiryQuantity': batches.fold<int>(
              0, (sum, batch) => sum + batch.remainingQuantity
            ),
            'alertLevel': _getAlertLevel(batches, daysThreshold),
          });
        }
      }
      
      // Sort by earliest expiry first
      alerts.sort((a, b) {
        final aEarliest = (a['batches'] as List<Batch>).map((b) => b.expiryDate).reduce((a, b) => a.isBefore(b) ? a : b);
        final bEarliest = (b['batches'] as List<Batch>).map((b) => b.expiryDate).reduce((a, b) => a.isBefore(b) ? a : b);
        return aEarliest.compareTo(bEarliest);
      });
      
      return alerts;
      
    } catch (e) {
      //print('❌ Error getting near expiry alerts: $e');
      return [];
    }
  }
  
  // Get all expired batches across inventory
  Future<List<Map<String, dynamic>>> getExpiredAlerts() async {
    try {
      final alerts = <Map<String, dynamic>>[];
      final inventoryItems = await _getAllInventoryItems();
      
      for (var item in inventoryItems) {
        if (!item.trackByBatch) continue;
        
        final batches = await _getExpiredBatchesForItem(item.id);
        
        if (batches.isNotEmpty) {
          alerts.add({
            'item': item,
            'batches': batches,
            'totalExpiredQuantity': batches.fold<int>(
              0, (sum, batch) => sum + batch.remainingQuantity
            ),
          });
        }
      }
      
      return alerts;
      
    } catch (e) {
      //print('❌ Error getting expired alerts: $e');
      return [];
    }
  }
  
  // Get dashboard alert summary
  Future<Map<String, dynamic>> getAlertSummary() async {
    try {
      final nearExpiry = await getNearExpiryAlerts();
      final expired = await getExpiredAlerts();
      
      int totalNearExpiryItems = nearExpiry.length;
      int totalExpiredItems = expired.length;
      int totalNearExpiryQuantity = nearExpiry.fold<int>(
        0, (sum, alert) => sum + (alert['totalNearExpiryQuantity'] as int)
      );
      int totalExpiredQuantity = expired.fold<int>(
        0, (sum, alert) => sum + (alert['totalExpiredQuantity'] as int)
      );
      
      // Group by urgency
      int urgentAlerts = nearExpiry.where((alert) => alert['alertLevel'] == 'urgent').length;
      int warningAlerts = nearExpiry.where((alert) => alert['alertLevel'] == 'warning').length;
      int infoAlerts = nearExpiry.where((alert) => alert['alertLevel'] == 'info').length;
      
      return {
        'nearExpiryCount': totalNearExpiryItems,
        'nearExpiryQuantity': totalNearExpiryQuantity,
        'expiredCount': totalExpiredItems,
        'expiredQuantity': totalExpiredQuantity,
        'urgentAlerts': urgentAlerts,
        'warningAlerts': warningAlerts,
        'infoAlerts': infoAlerts,
      };
      
    } catch (e) {
      //print('❌ Error getting alert summary: $e');
      return {
        'nearExpiryCount': 0,
        'nearExpiryQuantity': 0,
        'expiredCount': 0,
        'expiredQuantity': 0,
        'urgentAlerts': 0,
        'warningAlerts': 0,
        'infoAlerts': 0,
      };
    }
  }
  
  // Helper: Get all inventory items
  Future<List<InventoryItem>> _getAllInventoryItems() async {
    try {
      final snapshot = await _userInventoryCollection
          .where('isActive', isEqualTo: true)
          .get();
      
      return snapshot.docs.map((doc) {
        return InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
    } catch (e) {
      //print('❌ Error getting inventory items: $e');
      return [];
    }
  }
  
  // Helper: Get near expiry batches for an item
  Future<List<Batch>> _getNearExpiryBatchesForItem(String inventoryId, int daysThreshold) async {
    try {
      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));
      
      final snapshot = await _userInventoryCollection
          .doc(inventoryId)
          .collection('batches')
          .where('isActive', isEqualTo: true)
          .where('remainingQuantity', isGreaterThan: 0)
          .where('expiryDate', isLessThanOrEqualTo: Timestamp.fromDate(thresholdDate))
          .where('expiryDate', isGreaterThan: Timestamp.fromDate(now))
          .get();
      
      return snapshot.docs.map((doc) {
        return Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
    } catch (e) {
      return [];
    }
  }
  
  // Helper: Get expired batches for an item
  Future<List<Batch>> _getExpiredBatchesForItem(String inventoryId) async {
    try {
      final snapshot = await _userInventoryCollection
          .doc(inventoryId)
          .collection('batches')
          .where('isActive', isEqualTo: true)
          .where('remainingQuantity', isGreaterThan: 0)
          .where('expiryDate', isLessThan: Timestamp.fromDate(DateTime.now()))
          .get();
      
      return snapshot.docs.map((doc) {
        return Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
    } catch (e) {
      return [];
    }
  }
  
  // Get alert level based on days until expiry
  String _getAlertLevel(List<Batch> batches, int thresholdDays) {
    final earliestExpiry = batches.map((b) => b.expiryDate).reduce((a, b) => a.isBefore(b) ? a : b);
    final daysUntilExpiry = earliestExpiry.difference(DateTime.now()).inDays;
    
    if (daysUntilExpiry <= 7) return 'urgent';
    if (daysUntilExpiry <= 14) return 'warning';
    return 'info';
  }
  
  // Get batches expiring today
  Future<List<Map<String, dynamic>>> getTodayExpiringAlerts() async {
    try {
      final alerts = <Map<String, dynamic>>[];
      final inventoryItems = await _getAllInventoryItems();
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      for (var item in inventoryItems) {
        if (!item.trackByBatch) continue;
        
        final snapshot = await _userInventoryCollection
            .doc(item.id)
            .collection('batches')
            .where('isActive', isEqualTo: true)
            .where('remainingQuantity', isGreaterThan: 0)
            .where('expiryDate', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('expiryDate', isLessThan: Timestamp.fromDate(todayEnd))
            .get();
        
        if (snapshot.docs.isNotEmpty) {
          final batches = snapshot.docs.map((doc) {
            return Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();
          
          alerts.add({
            'item': item,
            'batches': batches,
          });
        }
      }
      
      return alerts;
      
    } catch (e) {
      //print('❌ Error getting today expiring alerts: $e');
      return [];
    }
  }
}