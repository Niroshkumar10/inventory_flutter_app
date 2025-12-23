import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ledger_model.dart';

class LedgerService {
  final String userMobile;
  
  LedgerService(this.userMobile);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user's ledger collection reference
  CollectionReference get _userLedgerCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('ledger');
  }

  // ✅ ADD LEDGER ENTRY with balance calculation (FIXED)
  Future<String> addLedgerEntry(LedgerEntry entry) async {
    try {
      // Get ALL entries for this party and calculate balance manually
      final allEntries = await _userLedgerCollection
          .where('partyId', isEqualTo: entry.partyId)
          .get();
      
      // Calculate current balance from all existing entries
      double currentBalance = 0;
      for (final doc in allEntries.docs) {
        final existingEntry = LedgerEntry.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        
        if (existingEntry.type == 'sale' || existingEntry.type == 'payment') {
          currentBalance = currentBalance + existingEntry.debit - existingEntry.credit;
        } else {
          currentBalance = currentBalance - existingEntry.debit + existingEntry.credit;
        }
      }
      
      // Calculate new balance for this entry
      double newBalance;
      if (entry.type == 'sale' || entry.type == 'payment') {
        newBalance = currentBalance + entry.debit - entry.credit;
      } else {
        newBalance = currentBalance - entry.debit + entry.credit;
      }
      
      // Update entry with calculated balance
      final updatedEntry = entry.copyWith(balance: newBalance);
      
      // Save to Firestore
      final docRef = await _userLedgerCollection.add(updatedEntry.toMap());
      
      print('✅ Ledger entry added: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error adding ledger entry: $e');
      throw Exception('Failed to add ledger entry: $e');
    }
  }

  // ✅ GET PARTY BALANCE (FIXED - NO INDEX REQUIRED)
  Future<double> getPartyBalance(String partyId) async {
    try {
      // Get all entries for this party
      final query = await _userLedgerCollection
          .where('partyId', isEqualTo: partyId)
          .get();
      
      if (query.docs.isEmpty) return 0.0;
      
      // Calculate balance from all entries
      double balance = 0;
      for (final doc in query.docs) {
        final entry = LedgerEntry.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        
        if (entry.type == 'sale' || entry.type == 'payment') {
          balance = balance + entry.debit - entry.credit;
        } else {
          balance = balance - entry.debit + entry.credit;
        }
      }
      
      return balance;
    } catch (e) {
      print('⚠️ Using fallback balance calculation: $e');
      return 0.0;
    }
  }

  // ✅ GET LEDGER ENTRIES (FIXED - NO ORDERING REQUIRED)
  Stream<List<LedgerEntry>> getLedgerEntries({
    String? partyId,
    String? partyType,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) {
    Query query = _userLedgerCollection;
    
    // Apply filters if provided
    if (partyId != null && partyId.isNotEmpty) {
      query = query.where('partyId', isEqualTo: partyId);
    }
    
    if (partyType != null && partyType.isNotEmpty) {
      query = query.where('partyType', isEqualTo: partyType);
    }
    
    return query.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return [];
      
      // Convert to LedgerEntry objects
      final entries = snapshot.docs.map((doc) {
        return LedgerEntry.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
      
      // Sort by date descending manually (no index required)
      entries.sort((a, b) => b.date.compareTo(a.date));
      
      // Apply date filters manually if needed
      List<LedgerEntry> filteredEntries = entries;
      
      if (startDate != null) {
        filteredEntries = filteredEntries.where((entry) => 
          entry.date.isAfter(startDate) || entry.date.isAtSameMomentAs(startDate)
        ).toList();
      }
      
      if (endDate != null) {
        filteredEntries = filteredEntries.where((entry) => 
          entry.date.isBefore(endDate) || entry.date.isAtSameMomentAs(endDate)
        ).toList();
      }
      
      // Apply limit if specified
      if (limit != null && limit > 0 && filteredEntries.length > limit) {
        return filteredEntries.sublist(0, limit);
      }
      
      return filteredEntries;
    });
  }

  // ✅ GET STATISTICS (FIXED)
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final snapshot = await _userLedgerCollection.get();
      
      double totalSales = 0;
      double totalPurchases = 0;
      double totalPayments = 0;
      double totalReceipts = 0;
      
      for (final doc in snapshot.docs) {
        final entry = LedgerEntry.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        
        switch (entry.type) {
          case 'sale':
            totalSales += entry.debit;
            break;
          case 'purchase':
            totalPurchases += entry.credit;
            break;
          case 'payment':
            totalPayments += entry.credit;
            break;
          case 'receipt':
            totalReceipts += entry.debit;
            break;
        }
      }
      
      return {
        'totalSales': totalSales,
        'totalPurchases': totalPurchases,
        'totalPayments': totalPayments,
        'totalReceipts': totalReceipts,
        'netBalance': (totalSales + totalPayments) - (totalPurchases + totalReceipts),
        'totalEntries': snapshot.docs.length,
      };
    } catch (e) {
      print('❌ Error getting statistics: $e');
      return {
        'totalSales': 0,
        'totalPurchases': 0,
        'totalPayments': 0,
        'totalReceipts': 0,
        'netBalance': 0,
        'totalEntries': 0,
      };
    }
  }

  // ✅ GET PARTY BALANCE SUMMARY (Optimized)
  Future<Map<String, double>> getPartyBalances() async {
    try {
      final snapshot = await _userLedgerCollection.get();
      
      final Map<String, double> balances = {};
      
      for (final doc in snapshot.docs) {
        final entry = LedgerEntry.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        
        final partyId = entry.partyId;
        
        if (!balances.containsKey(partyId)) {
          balances[partyId] = 0;
        }
        
        // Update balance calculation
        if (entry.type == 'sale' || entry.type == 'payment') {
          balances[partyId] = balances[partyId]! + entry.debit - entry.credit;
        } else {
          balances[partyId] = balances[partyId]! - entry.debit + entry.credit;
        }
      }
      
      return balances;
    } catch (e) {
      print('❌ Error getting party balances: $e');
      return {};
    }
  }

  // ✅ DELETE LEDGER ENTRY
  Future<void> deleteLedgerEntry(String id) async {
    try {
      await _userLedgerCollection.doc(id).delete();
    } catch (e) {
      print('❌ Error deleting ledger entry: $e');
      throw Exception('Failed to delete ledger entry: $e');
    }
  }

  // ✅ UPDATE LEDGER ENTRY (Simple update without balance recalculation)
  Future<void> updateLedgerEntry(LedgerEntry entry) async {
    try {
      if (entry.id.isEmpty) {
        throw Exception('Entry ID is required for update');
      }
      
      await _userLedgerCollection.doc(entry.id).update({
        'description': entry.description,
        'debit': entry.debit,
        'credit': entry.credit,
        'reference': entry.reference,
        'notes': entry.notes,
      });
    } catch (e) {
      print('❌ Error updating ledger entry: $e');
      throw Exception('Failed to update ledger entry: $e');
    }
  }
}