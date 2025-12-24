// lib/features/bill/services/bill_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill_model.dart';

class BillService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userMobile;

  BillService(this.userMobile);

  // Get user's bills subcollection reference
  CollectionReference get _userBillsCollection {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('bills');
  }

  // ✅ ADD BILL
  Future<String> addBill(Bill bill) async {
    try {
      final billData = bill.toMap();
      billData['userMobile'] = userMobile;
      
      final docRef = await _userBillsCollection.add(billData);
      return docRef.id;
    } catch (e) {
      print('❌ Error adding bill: $e');
      throw Exception('Failed to add bill: $e');
    }
  }

  // ✅ UPDATE BILL
  Future<void> updateBill(Bill bill) async {
    try {
      if (bill.id.isEmpty) {
        throw Exception('Bill ID is required for update');
      }
      
      final updateData = bill.toMap();
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      
      await _userBillsCollection.doc(bill.id).update(updateData);
    } catch (e) {
      print('❌ Error updating bill: $e');
      throw Exception('Failed to update bill: $e');
    }
  }

  // ✅ DELETE BILL
  Future<void> deleteBill(String id) async {
    try {
      await _userBillsCollection.doc(id).delete();
    } catch (e) {
      print('❌ Error deleting bill: $e');
      throw Exception('Failed to delete bill: $e');
    }
  }

// Update the getBills method in bill_service.dart
Stream<List<Bill>> getBills({String? filter}) {
  try {
    // Get all bills first
    return _userBillsCollection.snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return <Bill>[];
      
      // Convert to Bill objects
      List<Bill> allBills = snapshot.docs.map((doc) {
        return Bill.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
      
      // Apply filtering locally
      List<Bill> filteredBills = allBills;
      
      if (filter != null && filter != 'all') {
        if (filter == 'due') {
          filteredBills = allBills.where((bill) => bill.amountDue > 0).toList();
        } else {
          filteredBills = allBills.where((bill) => bill.type == filter).toList();
        }
      }
      
      // Sort by date (descending) locally
      filteredBills.sort((a, b) => b.date.compareTo(a.date));
      
      return filteredBills;
    });
  } catch (e) {
    print('❌ Error in getBills: $e');
    // Return empty stream on error
    return Stream.value(<Bill>[]);
  }
}
  // ✅ GET BILL BY ID
  Future<Bill> getBillById(String id) async {
    try {
      final doc = await _userBillsCollection.doc(id).get();
      if (doc.exists) {
        return Bill.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      throw Exception('Bill not found');
    } catch (e) {
      print('❌ Error getting bill: $e');
      rethrow;
    }
  }

  // ✅ SEARCH BILLS (Simple search without complex queries)
  Stream<List<Bill>> searchBills(String queryText) {
    if (queryText.isEmpty) return getBills();
    
    return _userBillsCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final partyName = (data['partyName'] ?? '').toString().toLowerCase();
            final invoiceNumber = (data['invoiceNumber'] ?? '').toString().toLowerCase();
            
            return partyName.contains(queryText.toLowerCase()) || 
                   invoiceNumber.contains(queryText.toLowerCase());
          })
          .map((doc) => Bill.fromMap(
                doc.data() as Map<String, dynamic>, 
                doc.id,
              ))
          .toList();
    }).handleError((error) {
      print('❌ Stream error in searchBills: $error');
      return [];
    });
  }

  // ✅ GET BILL SUMMARY STATISTICS
Stream<BillSummary> getBillSummary() {
  return _userBillsCollection.snapshots().map((snapshot) {
    double totalSales = 0.0;
    double totalPurchases = 0.0;
    double totalDue = 0.0;
    int dueCount = 0;
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final total = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final amountDue = (data['amountDue'] as num?)?.toDouble() ?? 0.0;
      final type = data['type'] as String? ?? '';
      
      if (type == 'sales') {
        totalSales += total;
      } else if (type == 'purchase') {
        totalPurchases += total;
      }
      
      totalDue += amountDue;
      if (amountDue > 0) {
        dueCount++;
      }
    }
    
    return BillSummary(
      totalSales: totalSales,
      totalPurchases: totalPurchases,
      totalDue: totalDue,
      dueCount: dueCount,
    );
  });
}
  // ✅ GET NEXT INVOICE NUMBER (Fixed - no complex queries)
  Future<String> getNextInvoiceNumber(String type) async {
    try {
      final currentYear = DateTime.now().year.toString();
      String prefix = type == 'sales' ? 'SALE' : 'PUR';
      
      // Get all bills and filter locally
      final querySnapshot = await _userBillsCollection.get();
      
      int maxNumber = 0;
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final docType = data['type'] as String? ?? '';
        final invoiceNumber = data['invoiceNumber'] as String? ?? '';
        
        // Only check bills of the same type
        if (docType == type && invoiceNumber.startsWith('$prefix-$currentYear-')) {
          try {
            final parts = invoiceNumber.split('-');
            if (parts.length == 3) {
              final number = int.tryParse(parts[2]);
              if (number != null && number > maxNumber) {
                maxNumber = number;
              }
            }
          } catch (e) {
            // Skip invalid format
          }
        }
      }
      
      return '$prefix-$currentYear-${(maxNumber + 1).toString().padLeft(3, '0')}';
    } catch (e) {
      print('❌ Error getting next invoice number: $e');
      // Fallback if there's an error
      return '${type == 'sales' ? 'SALE' : 'PUR'}-${DateTime.now().year}-001';
    }
  }

  // ✅ ADD PAYMENT TO BILL
  Future<void> addPayment(String billId, double paymentAmount) async {
    try {
      final bill = await getBillById(billId);
      final newAmountPaid = bill.amountPaid + paymentAmount;
      final newAmountDue = bill.totalAmount - newAmountPaid;
      
      await _userBillsCollection.doc(billId).update({
        'amountPaid': newAmountPaid,
        'amountDue': newAmountDue,
        'paymentStatus': newAmountDue <= 0 ? 'paid' : 'partial',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error adding payment: $e');
      throw Exception('Failed to add payment: $e');
    }
  }

  // ✅ GET PARTY NAMES FOR DROPDOWN
  Future<List<String>> getPartyNames() async {
    try {
      // Get all bills and extract unique party names
      final querySnapshot = await _userBillsCollection.get();
      
      final allNames = <String>{};
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['partyName'] as String?;
        if (name != null && name.isNotEmpty) {
          allNames.add(name);
        }
      }
      
      return allNames.toList()..sort();
    } catch (e) {
      print('❌ Error getting party names: $e');
      return [];
    }
  }
}

// Summary statistics model
class BillSummary {
  final double totalSales;
  final double totalPurchases;
  final double totalDue;
  final int dueCount;

  BillSummary({
    required this.totalSales,
    required this.totalPurchases,
    required this.totalDue,
    required this.dueCount,
  });
}