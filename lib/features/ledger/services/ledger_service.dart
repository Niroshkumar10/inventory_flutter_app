import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ledger_model.dart';
import '../../reports/services/export_service.dart';
import '../models/ledger_report_model.dart'; // ADD THIS IMPORT


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

  // ✅ ADD LEDGER ENTRY with balance calculation
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
      
      //print('✅ Ledger entry added: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      //print('❌ Error adding ledger entry: $e');
      throw Exception('Failed to add ledger entry: $e');
    }
  }

  // ✅ BULK ADD LEDGER ENTRIES (for sales/purchases sync)
  Future<void> bulkAddLedgerEntries(List<LedgerEntry> entries) async {
    try {
      final batch = _firestore.batch();
      
      for (var entry in entries) {
        final docRef = _userLedgerCollection.doc();
        batch.set(docRef, entry.toMap());
      }
      
      await batch.commit();
      //print('✅ ${entries.length} ledger entries added in bulk');
    } catch (e) {
      //print('❌ Error bulk adding ledger entries: $e');
      throw Exception('Failed to add ledger entries: $e');
    }
  }
// Add this method to your LedgerService class
Future<List<LedgerEntry>> getPartyLedgerEntries(String partyId, {int limit = 5}) async {
  try {
    //print('📊 Fetching ledger entries for party: $partyId');
    
    // Create query with filtering and sorting
    Query query = _userLedgerCollection
        .where('partyId', isEqualTo: partyId)
        .orderBy('date', descending: true);
    
    // Apply limit at database level
    if (limit > 0) {
      query = query.limit(limit);
    }
    
    final snapshot = await query.get();
    
    if (snapshot.docs.isEmpty) {
      //print('📭 No ledger entries found for party: $partyId');
      return [];
    }
    
    // Convert to LedgerEntry objects
    final entries = snapshot.docs.map((doc) {
      return LedgerEntry.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    }).toList();
    
    //print('✅ Found ${entries.length} entries for party: $partyId');
    return entries;
  } catch (e) {
    //print('❌ Error getting party ledger entries: $e');
    return [];
  }
}
  // ✅ GET PARTY BALANCE
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
      //print('⚠️ Using fallback balance calculation: $e');
      return 0.0;
    }
  }

  // ✅ GET LEDGER ENTRIES with filters
  Stream<List<LedgerEntry>> getLedgerEntries({
    String? partyId,
    String? partyType,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
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
    
    if (type != null && type.isNotEmpty) {
      query = query.where('type', isEqualTo: type);
    }
    
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
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
      
      // Sort by date descending manually
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

  // ✅ GET LEDGER REPORT DATA
  Future<LedgerReport> getLedgerReport({
    required DateTime startDate,
    required DateTime endDate,
    String? partyId,
    String? partyType,
    String? type,
  }) async {
    try {
      final entries = await _getLedgerEntriesForReport(
        startDate: startDate,
        endDate: endDate,
        partyId: partyId,
        partyType: partyType,
        type: type,
      );
      
      final summary = _calculateLedgerSummary(entries);
      
      return LedgerReport(
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
        entries: entries,
        summary: summary,
      );
    } catch (e) {
      //print('❌ Error getting ledger report: $e');
      throw Exception('Failed to generate ledger report: $e');
    }
  }

  Future<List<LedgerEntry>> _getLedgerEntriesForReport({
    required DateTime startDate,
    required DateTime endDate,
    String? partyId,
    String? partyType,
    String? type,
  }) async {
    Query query = _userLedgerCollection;
    
    // Apply filters
    if (partyId != null && partyId.isNotEmpty) {
      query = query.where('partyId', isEqualTo: partyId);
    }
    
    if (partyType != null && partyType.isNotEmpty) {
      query = query.where('partyType', isEqualTo: partyType);
    }
    
    if (type != null && type.isNotEmpty) {
      query = query.where('type', isEqualTo: type);
    }
    
    final snapshot = await query.get();
    
    if (snapshot.docs.isEmpty) return [];
    
    // Convert to LedgerEntry objects
    final entries = snapshot.docs.map((doc) {
      return LedgerEntry.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    }).toList();
    
    // Filter by date and sort
    final filteredEntries = entries.where((entry) {
      return (entry.date.isAfter(startDate) || entry.date.isAtSameMomentAs(startDate)) &&
             (entry.date.isBefore(endDate) || entry.date.isAtSameMomentAs(endDate));
    }).toList();
    
    filteredEntries.sort((a, b) => b.date.compareTo(a.date));
    
    return filteredEntries;
  }

  Map<String, double> _calculateLedgerSummary(List<LedgerEntry> entries) {
    double totalDebit = 0;
    double totalCredit = 0;
    double netBalance = 0;
    
    for (var entry in entries) {
      totalDebit += entry.debit;
      totalCredit += entry.credit;
      
      if (entry.type == 'sale' || entry.type == 'payment') {
        netBalance += entry.debit - entry.credit;
      } else {
        netBalance -= entry.debit - entry.credit;
      }
    }
    
    return {
      'totalDebit': totalDebit,
      'totalCredit': totalCredit,
      'netBalance': netBalance,
    };
  }

  // ✅ GET STATISTICS
  Future<Map<String, dynamic>> getStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final snapshot = await _userLedgerCollection.get();
      
      double totalSales = 0;
      double totalPurchases = 0;
      double totalPayments = 0;
      double totalReceipts = 0;
      int paidCount = 0;
      int pendingCount = 0;
      
      for (final doc in snapshot.docs) {
        final entry = LedgerEntry.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        
        // Apply date filter if provided
        if (startDate != null && entry.date.isBefore(startDate)) continue;
        if (endDate != null && entry.date.isAfter(endDate)) continue;
        
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
        
        // Count status
        if (entry.status.toLowerCase() == 'paid' || 
            entry.status.toLowerCase() == 'completed') {
          paidCount++;
        } else if (entry.status.toLowerCase() == 'pending' ||
                   entry.status.toLowerCase() == 'due') {
          pendingCount++;
        }
      }
      
      final netBalance = (totalSales + totalPayments) - (totalPurchases + totalReceipts);
      
      return {
        'totalSales': totalSales,
        'totalPurchases': totalPurchases,
        'totalPayments': totalPayments,
        'totalReceipts': totalReceipts,
        'netBalance': netBalance,
        'totalEntries': snapshot.docs.length,
        'paidCount': paidCount,
        'pendingCount': pendingCount,
      };
    } catch (e) {
      //print('❌ Error getting statistics: $e');
      return {
        'totalSales': 0,
        'totalPurchases': 0,
        'totalPayments': 0,
        'totalReceipts': 0,
        'netBalance': 0,
        'totalEntries': 0,
        'paidCount': 0,
        'pendingCount': 0,
      };
    }
  }

  // ✅ GET PARTY BALANCE SUMMARY
  Future<Map<String, double>> getPartyBalances({
    String? partyType,
  }) async {
    try {
      Query query = _userLedgerCollection;
      
      if (partyType != null && partyType.isNotEmpty) {
        query = query.where('partyType', isEqualTo: partyType);
      }
      
      final snapshot = await query.get();
      
      final Map<String, double> balances = {};
      final Map<String, String> partyNames = {};
      
      for (final doc in snapshot.docs) {
        final entry = LedgerEntry.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
        
        final partyId = entry.partyId;
        
        if (!balances.containsKey(partyId)) {
          balances[partyId] = 0;
          partyNames[partyId] = entry.partyName;
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
      //print('❌ Error getting party balances: $e');
      return {};
    }
  }

  // ✅ DELETE LEDGER ENTRY
  Future<void> deleteLedgerEntry(String id) async {
    try {
      await _userLedgerCollection.doc(id).delete();
      //print('✅ Ledger entry deleted: $id');
    } catch (e) {
      //print('❌ Error deleting ledger entry: $e');
      throw Exception('Failed to delete ledger entry: $e');
    }
  }

  // ✅ UPDATE LEDGER ENTRY
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
        'status': entry.status,
      });
      
      //print('✅ Ledger entry updated: ${entry.id}');
    } catch (e) {
      //print('❌ Error updating ledger entry: $e');
      throw Exception('Failed to update ledger entry: $e');
    }
  }

  // ✅ UPDATE LEDGER STATUS
  Future<void> updateLedgerStatus(String id, String status) async {
    try {
      await _userLedgerCollection.doc(id).update({
        'status': status,
      });
      //print('✅ Ledger status updated: $id -> $status');
    } catch (e) {
      //print('❌ Error updating ledger status: $e');
      throw Exception('Failed to update ledger status: $e');
    }
  }

  // ✅ EXPORT LEDGER REPORT
  Future<String> exportLedgerReport({
    required DateTime startDate,
    required DateTime endDate,
    required String format, // 'pdf' or 'excel'
    String? partyId,
    String? partyType,
    String? type,
  }) async {
    try {
      final report = await getLedgerReport(
        startDate: startDate,
        endDate: endDate,
        partyId: partyId,
        partyType: partyType,
        type: type,
      );
      
      // Prepare data for export
      final exportData = report.entries.map((entry) {
        return {
          'Date': '${entry.date.day}/${entry.date.month}/${entry.date.year}',
          'Type': entry.typeLabel,
          'Party Name': entry.partyName,
          'Description': entry.description,
          'Debit': entry.debit,
          'Credit': entry.credit,
          'Balance': entry.balance,
          'Reference': entry.reference,
          'Status': entry.statusLabel,
        };
      }).toList();
      
      final exportService = ExportService();
      
      if (format == 'pdf') {
        return await exportService.exportToPdf(
          reportType: 'ledger',
          userMobile: userMobile,
          startDate: startDate,
          endDate: endDate,
          data: exportData,
          title: 'Ledger Report',
        );
      } else {
        return await exportService.exportToExcel(
          reportType: 'ledger',
          userMobile: userMobile,
          startDate: startDate,
          endDate: endDate,
          data: exportData,
        );
      }
    } catch (e) {
      //print('❌ Error exporting ledger report: $e');
      throw Exception('Failed to export ledger report: $e');
    }
  }

  // ✅ SEARCH LEDGER ENTRIES
  Stream<List<LedgerEntry>> searchLedgerEntries(String queryText) {
    return _userLedgerCollection.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return [];
      
      final allEntries = snapshot.docs.map((doc) {
        return LedgerEntry.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
      
      if (queryText.isEmpty) return allEntries;
      
      final searchText = queryText.toLowerCase();
      
      return allEntries.where((entry) {
        return entry.partyName.toLowerCase().contains(searchText) ||
               entry.description.toLowerCase().contains(searchText) ||
               entry.reference.toLowerCase().contains(searchText) ||
               entry.type.toLowerCase().contains(searchText) ||
               entry.id.toLowerCase().contains(searchText);
      }).toList();
    });
  }
}