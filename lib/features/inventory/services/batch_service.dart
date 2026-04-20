// lib/features/inventory/services/batch_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/batch_model.dart';
import '../models/inventory_item_model.dart';

class BatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userMobile;
  
  BatchService(this.userMobile);
  
  // Get user's inventory subcollection reference
  CollectionReference get _userInventoryCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('inventory');
  }
  
  // Get batches subcollection for an inventory item
  CollectionReference _getBatchesCollection(String inventoryId) {
    return _userInventoryCollection
        .doc(inventoryId)
        .collection('batches');
  }
  
  // Get consumptions subcollection for a batch
  CollectionReference _getConsumptionsCollection(String inventoryId, String batchId) {
    return _userInventoryCollection
        .doc(inventoryId)
        .collection('batches')
        .doc(batchId)
        .collection('consumptions');
  }
  
  // Add a new batch to an inventory item
  Future<Batch> addBatch(String inventoryId, Batch batch) async {
    try {
      // Generate batch number if not provided
      final batchNumber = batch.batchNumber.isEmpty 
          ? _generateBatchNumber(inventoryId) 
          : batch.batchNumber;
      
      final updatedBatch = batch.copyWith(
        batchNumber: batchNumber,
        inventoryId: inventoryId,
      );
      
      // Add batch document
      final docRef = await _getBatchesCollection(inventoryId).add(updatedBatch.toMap());
      final newBatch = updatedBatch.copyWith(id: docRef.id);
      
      // Update inventory item totals
      await _updateInventoryTotals(inventoryId);
      
      return newBatch;
    } catch (e) {
      //print('❌ Error adding batch: $e');
      throw Exception('Failed to add batch: $e');
    }
  }
  
  // Get all batches for an inventory item (sorted by expiry date - FIFO)
  Stream<List<Batch>> getBatches(String inventoryId) {
    return _getBatchesCollection(inventoryId)
        .where('isActive', isEqualTo: true)
        .where('remainingQuantity', isGreaterThan: 0)
        .orderBy('expiryDate', descending: false) // Earliest expiry first (FIFO)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();
        });
  }
  
  // Get all batches (including consumed) for history
  Stream<List<Batch>> getAllBatches(String inventoryId) {
    return _getBatchesCollection(inventoryId)
        .where('isActive', isEqualTo: true)
        .orderBy('expiryDate', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();
        });
  }
  
  // Get a single batch
  Future<Batch?> getBatch(String inventoryId, String batchId) async {
    try {
      final doc = await _getBatchesCollection(inventoryId).doc(batchId).get();
      if (doc.exists) {
        return Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      //print('❌ Error getting batch: $e');
      return null;
    }
  }
  
  // CONSUME STOCK USING FIFO (First Expiry First Out)
  Future<List<StockConsumption>> consumeStockFIFO({
    required String inventoryId,
    required int quantityToConsume,
    required String transactionType,
    required String reason,
    String? referenceId,
    required String consumedBy,
  }) async {
    try {
      //print('📦 BatchService.consumeStockFIFO called');
    //print('  Inventory ID: $inventoryId');
    //print('  Quantity: $quantityToConsume');
      if (quantityToConsume <= 0) {
        throw Exception('Quantity to consume must be positive');
      }
      
      // Get all active batches with remaining stock, sorted by expiry date
      final batchesSnapshot = await _getBatchesCollection(inventoryId)
          .where('isActive', isEqualTo: true)
          .where('remainingQuantity', isGreaterThan: 0)
          .orderBy('expiryDate', descending: false) // FIFO: earliest expiry first
          .get();
      
      if (batchesSnapshot.docs.isEmpty) {
        throw Exception('No stock available');
      }
      
      int remainingToConsume = quantityToConsume;
      final List<StockConsumption> consumptions = [];
      final List<Map<String, dynamic>> batchUpdates = [];
      
      // FIFO Consumption Logic
      for (var doc in batchesSnapshot.docs) {
        if (remainingToConsume <= 0) break;
        
        final batch = Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        final availableInBatch = batch.remainingQuantity;
        final consumeFromThisBatch = remainingToConsume < availableInBatch 
            ? remainingToConsume 
            : availableInBatch;
        
        // Calculate new remaining quantity
        final newRemainingQuantity = batch.remainingQuantity - consumeFromThisBatch;
        
        // Record consumption
        final consumption = StockConsumption(
          id: '',
          inventoryId: inventoryId,
          batchId: batch.id,
          quantityConsumed: consumeFromThisBatch,
          transactionType: transactionType,
          referenceId: referenceId,
          reason: reason,
          consumedAt: DateTime.now(),
          consumedBy: consumedBy,
        );
        
        consumptions.add(consumption);
        batchUpdates.add({
          'batchId': batch.id,
          'newRemainingQuantity': newRemainingQuantity,
          'isActive': newRemainingQuantity > 0,
        });
        
        remainingToConsume -= consumeFromThisBatch;
      }
      
      if (remainingToConsume > 0) {
        throw Exception('Insufficient stock. Short by $remainingToConsume units');
      }
      
      // Perform batch update in Firestore
      final batch = _firestore.batch();
      
      // Update batches
      for (var update in batchUpdates) {
        final batchRef = _getBatchesCollection(inventoryId).doc(update['batchId']);
        batch.update(batchRef, {
          'remainingQuantity': update['newRemainingQuantity'],
          'isActive': update['isActive'],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Add consumption record
        final consumptionData = {
          'inventoryId': inventoryId,
          'batchId': update['batchId'],
          'quantityConsumed': consumptions.firstWhere(
            (c) => c.batchId == update['batchId']
          ).quantityConsumed,
          'transactionType': transactionType,
          'referenceId': referenceId,
          'reason': reason,
          'consumedAt': Timestamp.fromDate(DateTime.now()),
          'consumedBy': consumedBy,
        };
        
        final consumptionRef = _getConsumptionsCollection(inventoryId, update['batchId']).doc();
        batch.set(consumptionRef, consumptionData);
      }
      
      await batch.commit();
      
      // Update inventory totals
      await _updateInventoryTotals(inventoryId);
      
      return consumptions;
      
    } catch (e) {
      //print('❌ Error consuming stock with FIFO: $e');
      throw Exception('Failed to consume stock: $e');
    }
  }
  
  
  // Add stock to existing batch (restocking)
  Future<void> restockBatch(String inventoryId, String batchId, int additionalQuantity) async {
    try {
      final batchRef = _getBatchesCollection(inventoryId).doc(batchId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(batchRef);
        if (!doc.exists) {
          throw Exception('Batch not found');
        }
        
        final currentBatch = Batch.fromMap(doc.data() as Map<String, dynamic>, batchId);
        final newRemainingQuantity = currentBatch.remainingQuantity + additionalQuantity;
        final newTotalQuantity = currentBatch.quantity + additionalQuantity;
        
        transaction.update(batchRef, {
          'quantity': newTotalQuantity,
          'remainingQuantity': newRemainingQuantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      
      await _updateInventoryTotals(inventoryId);
      
    } catch (e) {
      //print('❌ Error restocking batch: $e');
      throw Exception('Failed to restock batch: $e');
    }
  }
  
  // Get available stock summary for an item
  Future<Map<String, dynamic>> getStockSummary(String inventoryId) async {
    try {
      final batches = await _getBatchesCollection(inventoryId)
          .where('isActive', isEqualTo: true)
          .where('remainingQuantity', isGreaterThan: 0)
          .get();
      
      int totalRemaining = 0;
      int totalBatches = batches.docs.length;
      int expiredBatches = 0;
      int nearExpiryBatches = 0;
      DateTime? earliestExpiry;
      
      for (var doc in batches.docs) {
        final batch = Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        totalRemaining += batch.remainingQuantity;
        
        if (batch.isExpired) {
          expiredBatches++;
        } else if (batch.isNearExpiry) {
          nearExpiryBatches++;
        }
        
        if (earliestExpiry == null || batch.expiryDate.isBefore(earliestExpiry)) {
          earliestExpiry = batch.expiryDate;
        }
      }
      
      return {
        'totalRemaining': totalRemaining,
        'totalBatches': totalBatches,
        'expiredBatches': expiredBatches,
        'nearExpiryBatches': nearExpiryBatches,
        'earliestExpiry': earliestExpiry,
      };
      
    } catch (e) {
      //print('❌ Error getting stock summary: $e');
      return {
        'totalRemaining': 0,
        'totalBatches': 0,
        'expiredBatches': 0,
        'nearExpiryBatches': 0,
        'earliestExpiry': null,
      };
    }
  }

/// Get all batches with their consumption/sales details (NO COMPLEX INDEX NEEDED)
Future<List<Map<String, dynamic>>> getBatchesWithDetails(String inventoryId) async {
  try {
    // Simple query - only filter by inventoryId (no complex indexes needed)
    final batchesSnapshot = await _getBatchesCollection(inventoryId)
        .get();  // Remove the where and orderBy clauses
    
    List<Map<String, dynamic>> batchDetails = [];
    
    for (var doc in batchesSnapshot.docs) {
      final batch = Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      
      // Only include active batches (filter in memory)
      if (!batch.isActive) continue;
      
      // Get consumption/sales history for this batch
      final consumptionsSnapshot = await _getConsumptionsCollection(inventoryId, batch.id)
          .get();
      
      int totalSold = 0;
      List<Map<String, dynamic>> salesHistory = [];
      
      for (var consumptionDoc in consumptionsSnapshot.docs) {
        final consumption = StockConsumption.fromMap(
          consumptionDoc.data() as Map<String, dynamic>, 
          consumptionDoc.id
        );
        totalSold += consumption.quantityConsumed;
        salesHistory.add({
          'quantity': consumption.quantityConsumed,
          'date': consumption.consumedAt,
          'type': consumption.transactionType,
          'reference': consumption.referenceId,
        });
      }
      
      batchDetails.add({
        'batch': batch,
        'totalSold': totalSold,
        'remainingQuantity': batch.remainingQuantity,
        'totalQuantity': batch.quantity,
        'salesHistory': salesHistory,
      });
    }
    
    // Sort by expiry date in memory (FIFO order)
    batchDetails.sort((a, b) {
      final batchA = a['batch'] as Batch;
      final batchB = b['batch'] as Batch;
      return batchA.expiryDate.compareTo(batchB.expiryDate);
    });
    
    return batchDetails;
    
  } catch (e) {
    print('❌ Error getting batches with details: $e');
    return [];
  }
}
/// Get consumption history for an inventory item
Future<List<StockConsumption>> getConsumptionHistory(
  String inventoryId, {
  int limit = 50,
  DateTime? startDate,
  DateTime? endDate,
}) async {
  try {
    // Get all batches first
    final batchesSnapshot = await _getBatchesCollection(inventoryId)
        .where('isActive', isEqualTo: true)
        .get();
    
    List<StockConsumption> allConsumptions = [];
    
    // Collect consumptions from each batch
    for (var batchDoc in batchesSnapshot.docs) {
      final batchId = batchDoc.id;
      final consumptionsSnapshot = await _getConsumptionsCollection(inventoryId, batchId)
          .orderBy('consumedAt', descending: true)
          .limit(limit)
          .get();
      
      for (var consumptionDoc in consumptionsSnapshot.docs) {
        final consumption = StockConsumption.fromMap(
          consumptionDoc.data() as Map<String, dynamic>, 
          consumptionDoc.id
        );
        
        // Apply date filters if provided
        if (startDate != null && consumption.consumedAt.isBefore(startDate)) continue;
        if (endDate != null && consumption.consumedAt.isAfter(endDate)) continue;
        
        allConsumptions.add(consumption);
      }
    }
    
    // Sort by date (newest first)
    allConsumptions.sort((a, b) => b.consumedAt.compareTo(a.consumedAt));
    
    // Apply limit
    if (allConsumptions.length > limit) {
      allConsumptions = allConsumptions.take(limit).toList();
    }
    
    return allConsumptions;
    
  } catch (e) {
    print('❌ Error getting consumption history: $e');
    return [];
  }
}

/// Get sales summary for an inventory item
Future<Map<String, dynamic>> getSalesSummary(String inventoryId) async {
  try {
    final consumptions = await getConsumptionHistory(inventoryId);
    
    int totalSold = 0;
    int totalSalesCount = 0;
    Map<String, int> salesByMonth = {};
    
    for (var consumption in consumptions) {
      if (consumption.transactionType == 'SALE') {
        totalSold += consumption.quantityConsumed;
        totalSalesCount++;
        
        // Group by month for chart data
        final monthKey = '${consumption.consumedAt.year}-${consumption.consumedAt.month}';
        salesByMonth[monthKey] = (salesByMonth[monthKey] ?? 0) + consumption.quantityConsumed;
      }
    }
    
    return {
      'totalSold': totalSold,
      'totalSalesCount': totalSalesCount,
      'salesByMonth': salesByMonth,
      'recentSales': consumptions.where((c) => c.transactionType == 'SALE').take(10).toList(),
    };
    
  } catch (e) {
    print('❌ Error getting sales summary: $e');
    return {
      'totalSold': 0,
      'totalSalesCount': 0,
      'salesByMonth': {},
      'recentSales': [],
    };
  }
}
  
  // Get batches that are near expiry (for alerts)
  Future<List<Batch>> getNearExpiryBatches(String inventoryId, {int daysThreshold = 30}) async {
    try {
      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));
      
      final snapshot = await _getBatchesCollection(inventoryId)
          .where('isActive', isEqualTo: true)
          .where('remainingQuantity', isGreaterThan: 0)
          .where('expiryDate', isLessThanOrEqualTo: Timestamp.fromDate(thresholdDate))
          .where('expiryDate', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiryDate', descending: false)
          .get();
      
      return snapshot.docs.map((doc) {
        return Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
    } catch (e) {
      //print('❌ Error getting near expiry batches: $e');
      return [];
    }
  }
  
  // Get expired batches
  Future<List<Batch>> getExpiredBatches(String inventoryId) async {
    try {
      final snapshot = await _getBatchesCollection(inventoryId)
          .where('isActive', isEqualTo: true)
          .where('remainingQuantity', isGreaterThan: 0)
          .where('expiryDate', isLessThan: Timestamp.fromDate(DateTime.now()))
          .orderBy('expiryDate', descending: false)
          .get();
      
      return snapshot.docs.map((doc) {
        return Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
    } catch (e) {
      //print('❌ Error getting expired batches: $e');
      return [];
    }
  }
  
  // Update inventory totals (sum of all batch remaining quantities)
 Future<void> _updateInventoryTotals(String inventoryId) async {
  final batches = await _getBatchesCollection(inventoryId)
      .where('isActive', isEqualTo: true)
      .where('remainingQuantity', isGreaterThan: 0)
      .get();
  
  int totalRemaining = 0;
  for (final doc in batches.docs) {
    final data = doc.data() as Map<String, dynamic>;
    totalRemaining += (data['remainingQuantity'] as int? ?? 0);
  }
  
  // Sync back to the parent inventory document
  await _firestore
      .collection('users')
      .doc(userMobile)
      .collection('inventory')
      .doc(inventoryId)
      .update({
    'quantity': totalRemaining,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
  // Generate unique batch number
  String _generateBatchNumber(String inventoryId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final shortId = inventoryId.length > 6 ? inventoryId.substring(0, 6) : inventoryId;
    return 'BATCH-${shortId.toUpperCase()}-$timestamp';
  }
  
  // Write off expired batches
  Future<int> writeOffExpiredBatches(String inventoryId, String consumedBy) async {
    try {
      final expiredBatches = await getExpiredBatches(inventoryId);
      
      if (expiredBatches.isEmpty) {
        return 0;
      }
      
      int totalWrittenOff = 0;
      
      for (var batch in expiredBatches) {
        if (batch.remainingQuantity > 0) {
          await consumeStockFIFO(
            inventoryId: inventoryId,
            quantityToConsume: batch.remainingQuantity,
            transactionType: 'EXPIRY_WRITEOFF',
            reason: 'Stock expired on ${batch.expiryDate.toLocal()}',
            consumedBy: consumedBy,
          );
          totalWrittenOff += batch.remainingQuantity;
        }
      }
      
      return totalWrittenOff;
      
    } catch (e) {
      //print('❌ Error writing off expired batches: $e');
      return 0;
    }
  }
}