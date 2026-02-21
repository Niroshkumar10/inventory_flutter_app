// lib/features/reports/services/report_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/report_model.dart';
import '../../bill/models/bill_model.dart';
import '../../inventory/models/inventory_item_model.dart';
import '../../party/models/supplier_model.dart';

// Add this helper class inside the ReportService class (at the top, after FirebaseFirestore declaration):
class SupplierStats {
  int totalOrders;
  double totalPurchases;
  double pendingPayment;
  DateTime lastOrderDate;

  SupplierStats({
    required this.totalOrders,
    required this.totalPurchases,
    required this.pendingPayment,
    required this.lastOrderDate,
  });
}
class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user's bills subcollection reference
  CollectionReference _getUserBillsCollection(String userMobile) {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('bills');
  }

  // Get user's inventory subcollection reference
  CollectionReference _getUserInventoryCollection(String userMobile) {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('inventory');
  }

  // Get user's customers subcollection reference
  CollectionReference _getUserCustomersCollection(String userMobile) {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('customers');
  }

  // Get user's suppliers subcollection reference
  CollectionReference _getUserSuppliersCollection(String userMobile) {
    return _firestore
        .collection('users')
        .doc(userMobile)
        .collection('suppliers');
  }

  // Get sales reports within date range
  Future<List<SalesReport>> getSalesReports({
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    String? customerId,
    String? paymentStatus,
  }) async {
    try {
      print('📊 Fetching sales reports for user: $userMobile');
      print('📅 Date range: $startDate to $endDate');
      
      Query query = _getUserBillsCollection(userMobile)
          .where('type', isEqualTo: 'sales')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate);

      if (customerId != null && customerId.isNotEmpty) {
        query = query.where('partyName', isEqualTo: customerId);
      }

      if (paymentStatus != null && paymentStatus.isNotEmpty) {
        query = query.where('paymentStatus', isEqualTo: paymentStatus);
      }

      final querySnapshot = await query.get();
      print('✅ Found ${querySnapshot.docs.length} sales bills');

      return querySnapshot.docs.map((doc) {
        final bill = Bill.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        return SalesReport.fromBill(bill);
      }).toList();
    } catch (e, stackTrace) {
      print('❌ Error getting sales reports: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }


  // Get purchase reports within date range
  Future<List<PurchaseReport>> getPurchaseReports({
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    String? supplierId,
    String? paymentStatus,
  }) async {
    try {
      print('📊 Fetching purchase reports for user: $userMobile');
      
      Query query = _getUserBillsCollection(userMobile)
          .where('type', isEqualTo: 'purchase')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate);

      if (supplierId != null && supplierId.isNotEmpty) {
        query = query.where('partyName', isEqualTo: supplierId);
      }

      if (paymentStatus != null && paymentStatus.isNotEmpty) {
        query = query.where('paymentStatus', isEqualTo: paymentStatus);
      }

      final querySnapshot = await query.get();
      print('✅ Found ${querySnapshot.docs.length} purchase bills');

      return querySnapshot.docs.map((doc) {
        final bill = Bill.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        return PurchaseReport.fromBill(bill);
      }).toList();
    } catch (e, stackTrace) {
      print('❌ Error getting purchase reports: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }


  // Get inventory reports
  Future<List<InventoryReport>> getInventoryReports({
    required String userMobile,
    String? category,
    String? status,
  }) async {
    try {
      print('📊 Fetching inventory reports for user: $userMobile');
      
      Query query = _getUserInventoryCollection(userMobile)
          .where('isActive', isEqualTo: true);

      if (category != null && category.isNotEmpty && category != 'All') {
        query = query.where('category', isEqualTo: category);
      }

      final querySnapshot = await query.get();
      print('✅ Found ${querySnapshot.docs.length} inventory items');

      List<InventoryReport> reports = querySnapshot.docs.map((doc) {
        final item = InventoryItem.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        return InventoryReport.fromInventoryItem(item);
      }).toList();

      // Filter by status if provided
      if (status != null && status.isNotEmpty && status != 'All') {
        reports = reports.where((report) => report.status == status).toList();
        print('✅ Filtered to ${reports.length} items with status: $status');
      }

      return reports;
    } catch (e, stackTrace) {
      print('❌ Error getting inventory reports: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get customer reports - FIXED VERSION
  Future<List<CustomerReport>> getCustomerReports({
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('📊 Fetching customer reports for user: $userMobile');
      
      // Get sales data for period
      final salesQuery = await _getUserBillsCollection(userMobile)
          .where('type', isEqualTo: 'sales')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      print('📊 Found ${salesQuery.docs.length} sales in period');

      // Group sales by customer name
      final Map<String, Map<String, dynamic>> customerData = {};

      for (final doc in salesQuery.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final bill = Bill.fromMap(data, doc.id);
          final customerName = bill.partyName.trim();
          
          if (customerName.isEmpty) {
            print('⚠️ Bill ${bill.invoiceNumber} has empty customer name');
            continue;
          }

          if (!customerData.containsKey(customerName)) {
            customerData[customerName] = {
              'name': customerName,
              'mobile': bill.partyPhone,
              'address': bill.partyAddress,
              'totalPurchases': 0,
              'totalSpent': 0.0,
              'outstandingBalance': 0.0,
              'lastPurchaseDate': bill.date,
            };
          }

          final stats = customerData[customerName]!;
          stats['totalPurchases'] = (stats['totalPurchases'] as int) + 1;
          stats['totalSpent'] = (stats['totalSpent'] as double) + bill.totalAmount;
          stats['outstandingBalance'] = (stats['outstandingBalance'] as double) + bill.amountDue;

          if (bill.date.isAfter(stats['lastPurchaseDate'] as DateTime)) {
            stats['lastPurchaseDate'] = bill.date;
          }
        } catch (e) {
          print('⚠️ Error processing bill ${doc.id}: $e');
        }
      }

      // Convert to CustomerReport objects
      final reports = customerData.values.map((stats) {
        return CustomerReport(
          customerId: 'customer_${stats['name']}_${DateTime.now().millisecondsSinceEpoch}',
          name: stats['name'] as String,
          mobile: stats['mobile'] as String,
          address: stats['address'] as String,
          totalPurchases: stats['totalPurchases'] as int,
          totalSpent: stats['totalSpent'] as double,
          outstandingBalance: stats['outstandingBalance'] as double,
          lastPurchaseDate: stats['lastPurchaseDate'] as DateTime,
          userMobile: userMobile,
        );
      }).toList();

      // Sort by total spent (descending)
      reports.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

      print('✅ Generated ${reports.length} customer reports');
      
      // Debug output
      for (final report in reports) {
        print('   👤 ${report.name}: ${report.totalPurchases} purchases, ₹${report.totalSpent}');
      }
      
      return reports;
    } catch (e, stackTrace) {
      print('❌ Error getting customer reports: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get supplier reports with purchase statistics
// Get supplier reports with purchase statistics - FIXED VERSION
Future<List<SupplierReport>> getSupplierReports({
  required String userMobile,
  required DateTime startDate,
  required DateTime endDate,
}) async {
  try {
    print('📊 Fetching supplier reports for user: $userMobile');
    print('📅 Date range: $startDate to $endDate');
    
    // 1. Get all suppliers from user's subcollection - REMOVE THE isActive FILTER
    final suppliersQuery = await _getUserSuppliersCollection(userMobile)
        .get(); // REMOVED: .where('isActive', isEqualTo: true)

    final suppliers = suppliersQuery.docs.map((doc) {
      return Supplier.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();

    print('✅ Found ${suppliers.length} suppliers for user: $userMobile');

    if (suppliers.isEmpty) {
      print('⚠️ No suppliers found for this user at all');
      return [];
    }

    // Print ALL suppliers for debugging (not just active)
    for (final supplier in suppliers) {
      print('   👥 Supplier: "${supplier.name}", ID: ${supplier.id}, Active: ${supplier.isActive}');
    }

    // 2. Get purchase data for period
    final purchasesQuery = await _getUserBillsCollection(userMobile)
        .where('type', isEqualTo: 'purchase')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .get();

    print('📊 Found ${purchasesQuery.docs.length} purchases in period');

    // Process purchase data
    final Map<String, SupplierStats> supplierStats = {};

    for (final doc in purchasesQuery.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final bill = Bill.fromMap(data, doc.id);
        final supplierName = bill.partyName;

        if (supplierName.isEmpty) {
          print('⚠️ Purchase bill ${doc.id} has empty supplier name');
          continue;
        }

        print('   🔍 Processing purchase for supplier: "$supplierName"');

        if (!supplierStats.containsKey(supplierName)) {
          supplierStats[supplierName] = SupplierStats(
            totalOrders: 0,
            totalPurchases: 0.0,
            pendingPayment: 0.0,
            lastOrderDate: bill.date,
          );
        }

        final stats = supplierStats[supplierName]!;
        stats.totalOrders++;
        stats.totalPurchases += bill.totalAmount;
        stats.pendingPayment += bill.amountDue;

        if (bill.date.isAfter(stats.lastOrderDate)) {
          stats.lastOrderDate = bill.date;
        }

        print('   📝 Purchase details: ₹${bill.totalAmount}, Due: ₹${bill.amountDue}');
      } catch (e) {
        print('❌ Error processing purchase bill ${doc.id}: $e');
      }
    }

    // 3. Show all supplier stats found in purchases
    print('📋 Supplier stats from purchases:');
    for (final entry in supplierStats.entries) {
      print('   📍 "${entry.key}": ${entry.value.totalOrders} orders, ₹${entry.value.totalPurchases}');
    }

    // 4. Create supplier reports - Show ALL suppliers
    final List<SupplierReport> reports = [];

    for (final supplier in suppliers) {
      // Try to find matching stats - check for exact name match
      SupplierStats? matchingStats;
      
      for (final entry in supplierStats.entries) {
        // Normalize names for comparison (trim and lowercase)
        final billSupplierName = entry.key.trim().toLowerCase();
        final supplierName = supplier.name.trim().toLowerCase();
        
        print('   🔄 Comparing bill: "$billSupplierName" with supplier: "$supplierName"');
        
        if (billSupplierName == supplierName) {
          matchingStats = entry.value;
          print('   ✅ Exact match found for supplier: ${supplier.name}');
          break;
        }
      }

      // If no exact match, try partial match
      if (matchingStats == null) {
        for (final entry in supplierStats.entries) {
          final billSupplierName = entry.key.trim().toLowerCase();
          final supplierName = supplier.name.trim().toLowerCase();
          
          if (billSupplierName.contains(supplierName) || supplierName.contains(billSupplierName)) {
            matchingStats = entry.value;
            print('   🔄 Partial match for supplier: ${supplier.name} -> ${entry.key}');
            break;
          }
        }
      }

      // Use matching stats or create zero stats
      final stats = matchingStats ?? SupplierStats(
        totalOrders: 0,
        totalPurchases: 0.0,
        pendingPayment: 0.0,
        lastOrderDate: DateTime(1970),
      );

      reports.add(SupplierReport.fromSupplier(
        supplier,
        totalOrders: stats.totalOrders,
        totalPurchases: stats.totalPurchases,
        pendingPayment: stats.pendingPayment,
        lastOrderDate: stats.lastOrderDate,
      ));
    }

    // 5. DO NOT FILTER - Show ALL suppliers (even with zero purchases)
    // Sort by total purchases (descending)
    reports.sort((a, b) => b.totalPurchases.compareTo(a.totalPurchases));

    print('✅ Generated ${reports.length} supplier reports');
    print('📋 Suppliers with purchases: ${reports.where((r) => r.totalPurchases > 0).length}');
    print('📋 Suppliers with zero purchases: ${reports.where((r) => r.totalPurchases == 0).length}');
    
    return reports; // Return ALL suppliers
  } catch (e, stackTrace) {
    print('❌ Error getting supplier reports: $e');
    print('Stack trace: $stackTrace');
    return []; // Return empty list instead of rethrowing
  }
} 
  // Get profit & loss report
  Future<ProfitLossReport> getProfitLossReport({
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('📊 Calculating P&L for user: $userMobile');
      print('📅 Period: $startDate to $endDate');

      // Get sales revenue
      final salesQuery = await _getUserBillsCollection(userMobile)
          .where('type', isEqualTo: 'sales')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      double totalRevenue = 0;
      for (final doc in salesQuery.docs) {
        final bill = Bill.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        totalRevenue += bill.totalAmount;
      }

      // Get purchase costs
      final purchaseQuery = await _getUserBillsCollection(userMobile)
          .where('type', isEqualTo: 'purchase')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      double totalCost = 0;
      for (final doc in purchaseQuery.docs) {
        final bill = Bill.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        totalCost += bill.totalAmount;
      }

      // Calculate profit
      final grossProfit = totalRevenue - totalCost;
      final expenses = await _calculateExpenses(userMobile, startDate, endDate);
      final netProfit = grossProfit - expenses;
      final profitMargin = totalRevenue > 0 ? (netProfit / totalRevenue) * 100 : 0;

      print('💰 P&L Results:');
      print('   Revenue: ₹$totalRevenue');
      print('   Cost: ₹$totalCost');
      print('   Gross Profit: ₹$grossProfit');
      print('   Expenses: ₹$expenses');
      print('   Net Profit: ₹$netProfit');
      print('   Margin: ${profitMargin.toStringAsFixed(2)}%');

      return ProfitLossReport(
        id: '${startDate.millisecondsSinceEpoch}_${endDate.millisecondsSinceEpoch}',
        periodStart: startDate,
        periodEnd: endDate,
        totalRevenue: totalRevenue,
        totalCost: totalCost,
        grossProfit: grossProfit,
        expenses: expenses,
        netProfit: netProfit,
        profitMargin: profitMargin.toDouble(),
        userMobile: userMobile,
        generatedAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      print('❌ Error getting profit loss report: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<double> _calculateExpenses(String userMobile, DateTime startDate, DateTime endDate) async {
    // For now, return 0. You can add expenses collection later
    return 0.0;
  }

  // Get dashboard summary
  Future<List<ReportSummary>> getDashboardSummary({
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('📊 Fetching dashboard summary for user: $userMobile');

      // Get sales summary
      final salesReports = await getSalesReports(
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
      );

      final totalSales = salesReports.fold(0.0, (sum, report) => sum + report.totalAmount);
      final totalCollected = salesReports.fold(0.0, (sum, report) => sum + report.amountPaid);
      final totalDue = salesReports.fold(0.0, (sum, report) => sum + report.amountDue);

      // Get inventory summary
      final inventoryReports = await getInventoryReports(userMobile: userMobile);
      final totalInventoryValue = inventoryReports.fold(0.0, (sum, report) => sum + report.totalValue);
      final totalItems = inventoryReports.length;
      final lowStockItems = inventoryReports.where((report) => report.status == 'low-stock').length;

      // Get purchase summary
      final purchaseReports = await getPurchaseReports(
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
      );
      final totalPurchases = purchaseReports.fold(0.0, (sum, report) => sum + report.totalAmount);

      print('📊 Summary Calculated:');
      print('   Total Sales: ₹$totalSales');
      print('   Total Purchases: ₹$totalPurchases');
      print('   Inventory Value: ₹$totalInventoryValue');
      print('   Outstanding: ₹$totalDue');

      return [
        ReportSummary(
          id: 'sales_summary',
          title: 'Total Sales',
          value: totalSales,
          change: '₹${NumberFormat('#,##0').format(totalSales)}',
          isPositive: totalSales > 0,
          icon: '💰',
          subTitle: '${salesReports.length} transactions',
          reportType: 'sales',
          periodStart: startDate,
          periodEnd: endDate,
          userMobile: userMobile,
        ),
        ReportSummary(
          id: 'profit_summary',
          title: 'Net Profit',
          value: totalSales - totalPurchases,
          change: '₹${NumberFormat('#,##0').format(totalSales - totalPurchases)}',
          isPositive: (totalSales - totalPurchases) > 0,
          icon: '📈',
          subTitle: totalSales > 0 
            ? '${((totalSales - totalPurchases) / totalSales * 100).toStringAsFixed(1)}% margin'
            : '0.0% margin',
          reportType: 'profit',
          periodStart: startDate,
          periodEnd: endDate,
          userMobile: userMobile,
        ),
        ReportSummary(
          id: 'outstanding_summary',
          title: 'Outstanding',
          value: totalDue,
          change: '₹${NumberFormat('#,##0').format(totalDue)}',
          isPositive: false,
          icon: '⏰',
          subTitle: 'From ${salesReports.where((r) => r.amountDue > 0).length} invoices',
          reportType: 'outstanding',
          periodStart: startDate,
          periodEnd: endDate,
          userMobile: userMobile,
        ),
        ReportSummary(
          id: 'inventory_summary',
          title: 'Inventory Value',
          value: totalInventoryValue,
          change: '₹${NumberFormat('#,##0').format(totalInventoryValue)}',
          isPositive: true,
          icon: '📦',
          subTitle: '$totalItems items, $lowStockItems low stock',
          reportType: 'inventory',
          periodStart: startDate,
          periodEnd: endDate,
          userMobile: userMobile,
        ),
      ];
    } catch (e, stackTrace) {
      print('❌ Error getting dashboard summary: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Export report data
  Future<Map<String, dynamic>> exportReportData({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    Map<String, dynamic>? filters,
  }) async {
    try {
      Map<String, dynamic> reportData = {
        'reportType': reportType,
        'periodStart': startDate.toIso8601String(),
        'periodEnd': endDate.toIso8601String(),
        'generatedAt': DateTime.now().toIso8601String(),
        'userMobile': userMobile,
      };

      switch (reportType) {
        case 'sales':
          final salesReports = await getSalesReports(
            userMobile: userMobile,
            startDate: startDate,
            endDate: endDate,
            customerId: filters?['customerId'],
            paymentStatus: filters?['paymentStatus'],
          );
          reportData['data'] = salesReports.map((r) => r.toMap()).toList();
          reportData['summary'] = {
            'totalSales': salesReports.fold(0.0, (sum, r) => sum + r.totalAmount),
            'totalCollected': salesReports.fold(0.0, (sum, r) => sum + r.amountPaid),
            'totalDue': salesReports.fold(0.0, (sum, r) => sum + r.amountDue),
            'totalInvoices': salesReports.length,
          };
          break;

        case 'purchase':
          final purchaseReports = await getPurchaseReports(
            userMobile: userMobile,
            startDate: startDate,
            endDate: endDate,
            supplierId: filters?['supplierId'],
            paymentStatus: filters?['paymentStatus'],
          );
          reportData['data'] = purchaseReports.map((r) => r.toMap()).toList();
          reportData['summary'] = {
            'totalPurchases': purchaseReports.fold(0.0, (sum, r) => sum + r.totalAmount),
            'totalPaid': purchaseReports.fold(0.0, (sum, r) => sum + r.amountPaid),
            'totalDue': purchaseReports.fold(0.0, (sum, r) => sum + r.amountDue),
            'totalInvoices': purchaseReports.length,
          };
          break;

        case 'inventory':
          final inventoryReports = await getInventoryReports(
            userMobile: userMobile,
            category: filters?['category'],
            status: filters?['status'],
          );
          reportData['data'] = inventoryReports.map((r) => r.toMap()).toList();
          reportData['summary'] = {
            'totalValue': inventoryReports.fold(0.0, (sum, r) => sum + r.totalValue),
            'totalItems': inventoryReports.length,
            'lowStockCount': inventoryReports.where((r) => r.status == 'low-stock').length,
            'outOfStockCount': inventoryReports.where((r) => r.status == 'out-of-stock').length,
          };
          break;

        case 'customer':
          final customerReports = await getCustomerReports(
            userMobile: userMobile,
            startDate: startDate,
            endDate: endDate,
          );
          reportData['data'] = customerReports.map((r) => r.toMap()).toList();
          reportData['summary'] = {
            'totalCustomers': customerReports.length,
            'totalRevenue': customerReports.fold(0.0, (sum, r) => sum + r.totalSpent),
            'totalOutstanding': customerReports.fold(0.0, (sum, r) => sum + r.outstandingBalance),
          };
          break;

        case 'supplier':
          final supplierReports = await getSupplierReports(
            userMobile: userMobile,
            startDate: startDate,
            endDate: endDate,
          );
          reportData['data'] = supplierReports.map((r) => r.toMap()).toList();
          reportData['summary'] = {
            'totalSuppliers': supplierReports.length,
            'totalPurchases': supplierReports.fold(0.0, (sum, r) => sum + r.totalPurchases),
            'totalPending': supplierReports.fold(0.0, (sum, r) => sum + r.pendingPayment),
          };
          break;

        case 'profit-loss':
          final profitLossReport = await getProfitLossReport(
            userMobile: userMobile,
            startDate: startDate,
            endDate: endDate,
          );
          reportData['data'] = profitLossReport.toMap();
          break;
      }

      return reportData;
    } catch (e, stackTrace) {
      print('❌ Error exporting report data: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}