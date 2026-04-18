// lib/features/reports/services/export_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// Import universal_html for web
import 'package:universal_html/html.dart' as html;

// Import for mobile file operations
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// Import PDF packages
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ExportService {
  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  static final _pdfCurrencyFormat = NumberFormat('#,##0.00', 'en_IN');

  // User/Business details from profile
  String? _userName;
  String? _businessName;
  String? _location;
  String? _gstNumber;
  String? _address;

  // Method to set user details from profile data
  void setUserDetailsFromProfile(Map<String, dynamic> userData) {
    //print('📋 Setting user details from profile: $userData');
    
    _userName = userData['name']?.toString();
    _businessName = userData['businessName']?.toString() ?? 'My Business';
    _location = userData['location']?.toString();
    
    //print('✅ Set values:');
    //print('  - userName: $_userName');
    //print('  - businessName: $_businessName');
    //print('  - location: $_location');
  }
  
  // Individual setter if needed
  void setUserDetails({
    String? userName,
    String? businessName,
    String? location,
    String? gstNumber,
    String? address,
  }) {
    _userName = userName;
    _businessName = businessName;
    _location = location;
    _gstNumber = gstNumber;
    _address = address;
  }

  // ============ NEW: Get dynamic table title based on report type ============
  String _getTableTitle(String reportType) {
    switch (reportType) {
      case 'sales': return 'Sales Details';
      case 'purchase': return 'Purchase Details';
      case 'profit-loss': return 'Profit & Loss';
      case 'inventory': return 'Inventory Details';
      case 'customer': return 'Customer Reports';
      case 'supplier': return 'Supplier Reports';
      default: return 'Report Details';
    }
  }

  // ============ UPDATED: exportToPdf with user data ============
Future<String> exportToPdf({
  required String reportType,
  required String userMobile,
  required DateTime startDate,
  required DateTime endDate,
  required dynamic data,
  required String title,
  Map<String, dynamic>? userData,
}) async {
  try {
    //print('📄 Starting PDF export for $reportType...');
    
    // Set user details if provided
    if (userData != null) {
      //print('📋 User data received in exportToPdf');
      setUserDetailsFromProfile(userData);
    } else {
      //print('⚠️ No user data provided to exportToPdf');
    }

    List<Map<String, dynamic>> dataRows;
    Map<String, dynamic> summary = {};
    
    // Handle specific report types with proper parsing
    if (reportType == 'sales' && data is List) {
      dataRows = _parseSalesReports(data);
      summary = _calculateSalesSummary(data);
    } else if (reportType == 'purchase' && data is List) {
      dataRows = _parsePurchaseReports(data);
      summary = _calculatePurchaseSummary(data);
    } else if (reportType == 'inventory' && data is List) {
      dataRows = _parseInventoryReports(data);
      // No summary for inventory in PDF
    } else if (reportType == 'customer' && data is List) {
      dataRows = _parseCustomerReports(data);
      // No summary for customer in PDF
    } else if (reportType == 'supplier' && data is List) {
      dataRows = _parseSupplierReports(data);
      // No summary for supplier in PDF
    } else if (reportType == 'profit-loss' && data is List) {
      dataRows = _parseDataToRows(data, reportType);
      // No summary for P&L in PDF
    } else {
      // Fallback to generic parsing
      dataRows = _parseDataToRows(data, reportType);
      summary = _calculateSummary(dataRows, reportType);
    }
    
    if (kIsWeb) {
      // ============ WEB VERSION ============
      final pdf = _generatePdfDocument(dataRows, summary, title, userMobile, startDate, endDate, reportType);
      final bytes = await pdf.save();
      final fileName = '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final success = await _downloadPdfWeb(bytes, fileName);
      
      if (success) {
        return '✅ PDF file downloaded! Check your downloads folder.';
      } else {
        return '❌ PDF download failed. Check browser console for details.';
      }
    } else {
      // ============ MOBILE VERSION ============
      return await _generateMobilePdf(
        dataRows: dataRows,
        summary: summary,
        title: title,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
        reportType: reportType,
      );
    }
  } catch (e) {
    //print('❌ PDF Export Error: $e');
    return 'Error exporting PDF: $e';
  }
}  // ============ NEW: Inventory Report Parsing ============
  List<Map<String, dynamic>> _parseInventoryReports(List<dynamic> reports) {
    final List<Map<String, dynamic>> rows = [];
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        
        final name = _extractValue(reportMap, ['name', 'itemName']);
        final sku = _extractValue(reportMap, ['sku', 'code']);
        final category = _extractValue(reportMap, ['category']);
        final quantity = _extractValue(reportMap, ['quantity', 'qty']);
        final price = _extractAmountFromMap(reportMap, ['price']);
        final totalValue = _extractAmountFromMap(reportMap, ['totalValue', 'total']);
        final status = _extractValue(reportMap, ['status']);
        
        rows.add({
          'Name': name,
          'SKU': sku,
          'Category': category,
          'Quantity': quantity,
          'Price': price,
          'Total Value': totalValue,
          'Status': status,
        });
      } catch (e) {
        //print('⚠️ Error parsing inventory report: $e');
      }
    }
    return rows;
  }

  // ============ NEW: Customer Report Parsing ============
  List<Map<String, dynamic>> _parseCustomerReports(List<dynamic> reports) {
    final List<Map<String, dynamic>> rows = [];
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        
        final name = _extractValue(reportMap, ['name']);
        final mobile = _extractValue(reportMap, ['mobile', 'phone']);
        final totalPurchases = _extractValue(reportMap, ['totalPurchases', 'purchaseCount']);
        final totalSpent = _extractAmountFromMap(reportMap, ['totalSpent', 'revenue']);
        final outstanding = _extractAmountFromMap(reportMap, ['outstandingBalance', 'due']);
        
        // Format totalSpent without ₹ symbol (just number)
        final totalSpentNumber = NumberFormat('#,##0.00').format(totalSpent);
        
        rows.add({
          'Name': name,
          'Mobile': mobile,
          'Total Purchases': totalPurchases,
          'Total Spent': totalSpentNumber,   // no ₹
          'Outstanding': outstanding,
        });
      } catch (e) {
        //print('⚠️ Error parsing customer report: $e');
      }
    }
    return rows;
  }

// ============ NEW: Supplier Report Parsing ============
List<Map<String, dynamic>> _parseSupplierReports(List<dynamic> reports) {
  final List<Map<String, dynamic>> rows = [];
  
  for (var report in reports) {
    try {
      final reportMap = _convertToMap(report);
      
      final name = _extractValue(reportMap, ['name']);
      final phone = _extractValue(reportMap, ['phone']);
      final email = _extractValue(reportMap, ['email']);
      final address = _extractValue(reportMap, ['address']);
      final totalOrders = _extractValue(reportMap, ['totalOrders', 'orderCount']);
      final totalPurchases = _extractAmountFromMap(reportMap, ['totalPurchases']);
      final pendingPayment = _extractAmountFromMap(reportMap, ['pendingPayment']);
      final lastOrderDate = _extractValue(reportMap, ['formattedLastOrder', 'lastOrderDate']);
      
      // Format totalOrders without ₹ symbol (just number)
      final totalOrdersNumber = totalOrders;
      
      rows.add({
        'Name': name,
        'Phone': phone,
        'Email': email,
        'Address': address,
        'Total Orders': totalOrdersNumber,   // no ₹
        'Total Purchases': totalPurchases,
        'Pending Payment': pendingPayment,
        'Last Order': lastOrderDate,
      });
    } catch (e) {
      //print('⚠️ Error parsing supplier report: $e');
    }
  }
  return rows;
}
  // ============ UPDATED: exportToExcel ============
Future<String> exportToExcel({
  required String reportType,
  required String userMobile,
  required DateTime startDate,
  required DateTime endDate,
  required dynamic data,
}) async {
  try {
    //print('📊 Starting Excel export for $reportType...');
    
    String csvContent;
    
    // Handle specific report types
    if (reportType == 'sales' && data is List) {
      csvContent = _createSalesCsvContent(
        reports: data,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
      );
    } else if (reportType == 'purchase' && data is List) {
      csvContent = _createPurchaseCsvContent(
        reports: data,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
      );
    } else if (reportType == 'inventory' && data is List) {
      csvContent = _createInventoryCsvContent(
        reports: data,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
      );
    } else if (reportType == 'customer' && data is List) {
      csvContent = _createCustomerCsvContent(
        reports: data,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
      );
    } else if (reportType == 'supplier' && data is List) {
      csvContent = _createSupplierCsvContent(
        reports: data,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
      );
    } else {
      // Fallback to generic CSV creation
      csvContent = _createCsvContent(
        reportType: reportType,
        userMobile: userMobile,
        startDate: startDate,
        endDate: endDate,
        data: data,
      );
    }
    
    if (kIsWeb) {
      // ============ WEB VERSION ============
      final fileName = '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final success = await _realWebDownload(csvContent, fileName, 'text/csv');
      
      if (success) {
        return '✅ Excel (CSV) file downloaded! Check your downloads folder.';
      } else {
        return '❌ Download failed. Check browser console for details.';
      }
    } else {
      // ============ MOBILE VERSION ============
      return await _saveCsvToMobile(csvContent, reportType);
    }
  } catch (e) {
    //print('❌ Excel Export Error: $e');
    return 'Error exporting Excel: $e';
  }
}
  // ============ NEW: Inventory CSV Content ============
  String _createInventoryCsvContent({
    required List<dynamic> reports,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    double totalValue = 0;
    int lowStock = 0;
    int outOfStock = 0;
    
    String csv = '"INVENTORY REPORT"\n\n';
    
    csv += '"METADATA"\n';
    csv += '"User","$userMobile"\n';
    csv += '"Period","${formatDate(startDate)} to ${formatDate(endDate)}"\n';
    csv += '"Generated","${formatDate(DateTime.now())}"\n\n';
    
    csv += '"ITEM DETAILS"\n';
    csv += '"Name","SKU","Category","Quantity","Price","Total Value","Status"\n';
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        final name = _extractValue(reportMap, ['name', 'itemName']);
        final sku = _extractValue(reportMap, ['sku', 'code']);
        final category = _extractValue(reportMap, ['category']);
        final quantity = _extractValue(reportMap, ['quantity', 'qty']);
        final price = _extractAmountFromMap(reportMap, ['price']);
        final total = _extractAmountFromMap(reportMap, ['totalValue', 'total']);
        final status = _extractValue(reportMap, ['status']);
        
        totalValue += total;
        if (status.toLowerCase().contains('low')) lowStock++;
        if (status.toLowerCase().contains('out')) outOfStock++;
        
        csv += '"$name","$sku","$category","$quantity","${_currencyFormat.format(price)}","${_currencyFormat.format(total)}","$status"\n';
      } catch (e) {
        //print('⚠️ Error processing inventory for CSV: $e');
      }
    }
    
    // Insert summary
    final lines = csv.split('\n');
    lines.insert(5, '"Total Value","${_currencyFormat.format(totalValue)}"');
    lines.insert(6, '"Low Stock","$lowStock"');
    lines.insert(7, '"Out of Stock","$outOfStock"');
    csv = lines.join('\n');
    
    csv += '\n"Generated by Inventory Management System"';
    
    return csv;
  }

  // ============ NEW: Customer CSV Content ============
  String _createCustomerCsvContent({
    required List<dynamic> reports,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    double totalRevenue = 0;
    double totalOutstanding = 0;
    
    String csv = '"CUSTOMER REPORT"\n\n';
    
    csv += '"METADATA"\n';
    csv += '"User","$userMobile"\n';
    csv += '"Period","${formatDate(startDate)} to ${formatDate(endDate)}"\n';
    csv += '"Generated","${formatDate(DateTime.now())}"\n\n';
    
    csv += '"CUSTOMER DETAILS"\n';
    csv += '"Name","Mobile","Total Purchases","Total Spent","Outstanding"\n';
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        final name = _extractValue(reportMap, ['name']);
        final mobile = _extractValue(reportMap, ['mobile', 'phone']);
        final totalPurchases = _extractValue(reportMap, ['totalPurchases', 'purchaseCount']);
        final totalSpent = _extractAmountFromMap(reportMap, ['totalSpent', 'revenue']);
        final outstanding = _extractAmountFromMap(reportMap, ['outstandingBalance', 'due']);
        
        totalRevenue += totalSpent;
        totalOutstanding += outstanding;
        
        csv += '"$name","$mobile","$totalPurchases","${NumberFormat('#,##0.00').format(totalSpent)}","${_currencyFormat.format(outstanding)}"\n';
      } catch (e) {
        //print('⚠️ Error processing customer for CSV: $e');
      }
    }
    
    // Insert summary
    final lines = csv.split('\n');
    lines.insert(5, '"Total Customers","${reports.length}"');
    lines.insert(6, '"Total Revenue","${_currencyFormat.format(totalRevenue)}"');
    lines.insert(7, '"Total Outstanding","${_currencyFormat.format(totalOutstanding)}"');
    csv = lines.join('\n');
    
    csv += '\n"Generated by Inventory Management System"';
    
    return csv;
  }

// ============ NEW: Supplier CSV Content ============
// ============ NEW: Supplier CSV Content ============
String _createSupplierCsvContent({
  required List<dynamic> reports,
  required String userMobile,
  required DateTime startDate,
  required DateTime endDate,
}) {
  double totalPurchases = 0;
  double totalPending = 0;
  
  String csv = '"SUPPLIER REPORT"\n\n';
  
  csv += '"METADATA"\n';
  csv += '"User","$userMobile"\n';
  csv += '"Period","${formatDate(startDate)} to ${formatDate(endDate)}"\n';
  csv += '"Generated","${formatDate(DateTime.now())}"\n\n';
  
  csv += '"SUPPLIER DETAILS"\n';
  csv += '"Name","Phone","Email","Address","Total Orders","Total Purchases","Pending Payment","Last Order"\n';
  
  for (var report in reports) {
    try {
      final reportMap = _convertToMap(report);
      final name = _extractValue(reportMap, ['name']);
      final phone = _extractValue(reportMap, ['phone']);
      final email = _extractValue(reportMap, ['email']);
      final address = _extractValue(reportMap, ['address']);
      final totalOrders = _extractValue(reportMap, ['totalOrders', 'orderCount']);
      final totalPurchasesValue = _extractAmountFromMap(reportMap, ['totalPurchases']);
      final pendingPayment = _extractAmountFromMap(reportMap, ['pendingPayment']);
      final lastOrderDate = _extractValue(reportMap, ['formattedLastOrder', 'lastOrderDate']);
      
      totalPurchases += totalPurchasesValue;
      totalPending += pendingPayment;
      
      csv += '"$name",'
             '"$phone",'
             '"$email",'
             '"$address",'
             '"$totalOrders",'
             '"${_currencyFormat.format(totalPurchasesValue)}",'
             '"${_currencyFormat.format(pendingPayment)}",'
             '"$lastOrderDate"\n';
    } catch (e) {
      //print('⚠️ Error processing supplier for CSV: $e');
    }
  }
  
  // Insert summary
  final lines = csv.split('\n');
  lines.insert(5, '"Total Suppliers","${reports.length}"');
  lines.insert(6, '"Total Purchases","${_currencyFormat.format(totalPurchases)}"');
  lines.insert(7, '"Total Pending","${_currencyFormat.format(totalPending)}"');
  csv = lines.join('\n');
  
  csv += '\n"Generated by Inventory Management System"';
  
  return csv;
} 
  // ============ EXISTING METHODS (unchanged) ============
  
  // Sales Report Parsing
  List<Map<String, dynamic>> _parseSalesReports(List<dynamic> reports) {
    final List<Map<String, dynamic>> rows = [];
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        
        final invoiceNumber = _extractValue(reportMap, ['invoiceNumber', 'invoiceNo', 'invoice_id']);
        final customerName = _extractValue(reportMap, ['customerName', 'customer', 'clientName']);
        final customerMobile = _extractValue(reportMap, ['customerMobile', 'mobile', 'phone', 'contact']);
        final date = _extractValue(reportMap, ['formattedDate', 'date', 'createdAt', 'invoiceDate']);
        final totalItems = _extractValue(reportMap, ['totalItems', 'itemsCount', 'quantity']);
        final items = _extractItems(reportMap);
        final totalAmount = _extractAmountFromMap(reportMap, ['totalAmount', 'grandTotal', 'netAmount']);
        final amountPaid = _extractAmountFromMap(reportMap, ['amountPaid', 'paidAmount', 'paid']);
        final amountDue = _extractAmountFromMap(reportMap, ['amountDue', 'dueAmount', 'balance']);
        final paymentStatus = _extractValue(reportMap, ['paymentStatus', 'status', 'payment_state']);
        
        rows.add({
          'Invoice No.': invoiceNumber,
          'Customer': customerName,
          'Mobile': customerMobile,
          'Date': date,
          'Categories': _getUniqueCategories(items),
          'Items': _getItemsSummary(items),
          'Total Items': totalItems,
          'Total Amount': totalAmount,
          'Amount Paid': amountPaid,
          'Amount Due': amountDue,
          'Status': paymentStatus,
        });
      } catch (e) {
        //print('⚠️ Error parsing sales report: $e');
      }
    }
    
    return rows;
  }

  // Purchase Report Parsing
  List<Map<String, dynamic>> _parsePurchaseReports(List<dynamic> reports) {
    final List<Map<String, dynamic>> rows = [];
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        
        final invoiceNumber = _extractValue(reportMap, ['invoiceNumber', 'invoiceNo', 'invoice_id']);
        final supplierName = _extractValue(reportMap, ['supplierName', 'supplier', 'vendorName']);
        final supplierMobile = _extractValue(reportMap, ['supplierMobile', 'mobile', 'phone', 'contact']);
        final date = _extractValue(reportMap, ['formattedDate', 'date', 'createdAt', 'invoiceDate']);
        final items = _extractItems(reportMap);
        final totalAmount = _extractAmountFromMap(reportMap, ['totalAmount', 'grandTotal', 'netAmount']);
        final amountPaid = _extractAmountFromMap(reportMap, ['amountPaid', 'paidAmount', 'paid']);
        final amountDue = _extractAmountFromMap(reportMap, ['amountDue', 'dueAmount', 'balance']);
        final paymentStatus = _extractValue(reportMap, ['paymentStatus', 'status', 'payment_state']);
        
        rows.add({
          'Invoice No.': invoiceNumber,
          'Supplier': supplierName,
          'Mobile': supplierMobile,
          'Date': date,
          'Categories': _getUniqueCategories(items),
          'Items': _getItemsSummary(items),
          'Total Amount': totalAmount,
          'Amount Paid': amountPaid,
          'Amount Due': amountDue,
          'Status': paymentStatus,
        });
      } catch (e) {
        //print('⚠️ Error parsing purchase report: $e');
      }
    }
    
    return rows;
  }

  // Helper method to safely convert to Map<String, dynamic>
  Map<String, dynamic> _convertToMap(dynamic data) {
    if (data == null) return {};
    
    if (data is Map<String, dynamic>) {
      return data;
    }
    
    if (data is Map<dynamic, dynamic>) {
      final Map<String, dynamic> result = {};
      data.forEach((key, value) {
        if (key != null) {
          result[key.toString()] = value;
        }
      });
      return result;
    }
    
    try {
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      // Ignore
    }
    
    return {};
  }

  // Helper methods for data extraction
  String _extractValue(Map<String, dynamic> data, List<String> possibleKeys) {
    for (var key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null) {
        return data[key].toString();
      }
    }
    return '';
  }

  double _extractAmountFromMap(Map<String, dynamic> data, List<String> possibleKeys) {
    for (var key in possibleKeys) {
      if (data.containsKey(key) && data[key] != null) {
        try {
          if (data[key] is num) return (data[key] as num).toDouble();
          if (data[key] is String) {
            final cleanValue = data[key].toString().replaceAll(RegExp(r'[^\d.-]'), '');
            return double.tryParse(cleanValue) ?? 0.0;
          }
        } catch (e) {
          continue;
        }
      }
    }
    return 0.0;
  }

  List<dynamic> _extractItems(Map<String, dynamic> data) {
    final itemKeys = ['items', 'products', 'itemList', 'lineItems'];
    
    for (var key in itemKeys) {
      if (data.containsKey(key) && data[key] is List) {
        return data[key] as List;
      }
    }
    
    if (data.containsKey('invoice') && data['invoice'] is Map) {
      final invoice = data['invoice'] as Map<String, dynamic>;
      for (var key in itemKeys) {
        if (invoice.containsKey(key) && invoice[key] is List) {
          return invoice[key] as List;
        }
      }
    }
    
    return [];
  }

  String _getUniqueCategories(List<dynamic> items) {
    final categories = <String>{};
    
    for (var item in items) {
      final itemMap = _convertToMap(item);
      final category = _extractValue(itemMap, ['category', 'type', 'group']);
      if (category.isNotEmpty) {
        categories.add(category);
      } else {
        categories.add('Uncategorized');
      }
    }
    
    if (categories.isEmpty) return 'No categories';
    return categories.join(', ');
  }

  String _getItemsSummary(List<dynamic> items) {
    if (items.isEmpty) return 'No items';
    
    final summaries = <String>[];
    for (var item in items) {
      final itemMap = _convertToMap(item);
      final name = _extractValue(itemMap, ['name', 'productName', 'itemName']);
      final quantity = _extractValue(itemMap, ['quantity', 'qty', 'amount']);
      if (name.isNotEmpty && quantity.isNotEmpty) {
        summaries.add('$name ×$quantity');
      }
    }
    
    if (summaries.isEmpty) return '${items.length} item(s)';
    
    final summary = summaries.join(', ');
    if (summary.length > 50) {
      return '${summary.substring(0, 47)}...';
    }
    
    return summary;
  }

  // Sales CSV Content
  String _createSalesCsvContent({
    required List<dynamic> reports,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    double totalSales = 0;
    double totalPaid = 0;
    double totalDue = 0;
    int invoiceCount = 0;
    
    String csv = '"SALES REPORT"\n\n';
    
    csv += '"METADATA"\n';
    csv += '"User","$userMobile"\n';
    csv += '"Period","${formatDate(startDate)} to ${formatDate(endDate)}"\n';
    csv += '"Generated","${formatDate(DateTime.now())}"\n';
    
    csv += '\n"INVOICE SUMMARY"\n';
    csv += '"Invoice No.","Customer","Mobile","Date","Categories","Items","Total Amount","Amount Paid","Amount Due","Status"\n';
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        
        final invoiceNumber = _extractValue(reportMap, ['invoiceNumber', 'invoiceNo', 'invoice_id']);
        final customerName = _extractValue(reportMap, ['customerName', 'customer', 'clientName']);
        final customerMobile = _extractValue(reportMap, ['customerMobile', 'mobile', 'phone', 'contact']);
        final date = _extractValue(reportMap, ['formattedDate', 'date', 'createdAt', 'invoiceDate']);
        final items = _extractItems(reportMap);
        final totalAmount = _extractAmountFromMap(reportMap, ['totalAmount', 'grandTotal', 'netAmount']);
        final amountPaid = _extractAmountFromMap(reportMap, ['amountPaid', 'paidAmount', 'paid']);
        final amountDue = _extractAmountFromMap(reportMap, ['amountDue', 'dueAmount', 'balance']);
        final paymentStatus = _extractValue(reportMap, ['paymentStatus', 'status', 'payment_state']);
        
        totalSales += totalAmount;
        totalPaid += amountPaid;
        totalDue += amountDue;
        invoiceCount++;
        
        csv += '"$invoiceNumber",'
               '"$customerName",'
               '"$customerMobile",'
               '"$date",'
               '"${_getUniqueCategories(items)}",'
               '"${_getItemsSummary(items)}",'
               '"${_currencyFormat.format(totalAmount)}",'
               '"${_currencyFormat.format(amountPaid)}",'
               '"${_currencyFormat.format(amountDue)}",'
               '"${paymentStatus.toUpperCase()}"\n';
      } catch (e) {
        //print('⚠️ Error processing sales report for CSV: $e');
      }
    }
    
    final csvLines = csv.split('\n');
    csvLines.insert(5, '"Total Invoices","$invoiceCount"');
    csvLines.insert(6, '"Total Sales","${_currencyFormat.format(totalSales)}"');
    csvLines.insert(7, '"Total Collected","${_currencyFormat.format(totalPaid)}"');
    csvLines.insert(8, '"Total Due","${_currencyFormat.format(totalDue)}"');
    csv = csvLines.join('\n');
    
    csv += '\n"ITEM DETAILS"\n';
    csv += '"Invoice No.","Item Name","Category","Quantity","Unit","Price","Total"\n';
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        final invoiceNumber = _extractValue(reportMap, ['invoiceNumber', 'invoiceNo', 'invoice_id']);
        final items = _extractItems(reportMap);
        
        for (var item in items) {
          final itemMap = _convertToMap(item);
          final itemName = _extractValue(itemMap, ['name', 'productName', 'itemName']);
          final category = _extractValue(itemMap, ['category', 'type', 'group']);
          final quantity = _extractValue(itemMap, ['quantity', 'qty', 'amount']);
          final unit = _extractValue(itemMap, ['unit', 'measurement', 'uom']);
          final price = _extractAmountFromMap(itemMap, ['price', 'unitPrice', 'rate']);
          final total = _extractAmountFromMap(itemMap, ['total', 'amount', 'lineTotal']);
          
          csv += '"$invoiceNumber",'
                 '"$itemName",'
                 '"${category.isNotEmpty ? category : "Uncategorized"}",'
                 '"$quantity",'
                 '"$unit",'
                 '"${_currencyFormat.format(price)}",'
                 '"${_currencyFormat.format(total)}"\n';
        }
      } catch (e) {
        //print('⚠️ Error processing item details for CSV: $e');
      }
    }
    
    csv += '\n"Generated by Inventory Management System"';
    
    return csv;
  }

  // Purchase CSV Content
  String _createPurchaseCsvContent({
    required List<dynamic> reports,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    double totalPurchases = 0;
    double totalPaid = 0;
    double totalDue = 0;
    int invoiceCount = 0;
    
    String csv = '"PURCHASE REPORT"\n\n';
    
    csv += '"METADATA"\n';
    csv += '"User","$userMobile"\n';
    csv += '"Period","${formatDate(startDate)} to ${formatDate(endDate)}"\n';
    csv += '"Generated","${formatDate(DateTime.now())}"\n';
    
    csv += '\n"INVOICE SUMMARY"\n';
    csv += '"Invoice No.","Supplier","Mobile","Date","Categories","Items","Total Amount","Amount Paid","Amount Due","Status"\n';
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        
        final invoiceNumber = _extractValue(reportMap, ['invoiceNumber', 'invoiceNo', 'invoice_id']);
        final supplierName = _extractValue(reportMap, ['supplierName', 'supplier', 'vendorName']);
        final supplierMobile = _extractValue(reportMap, ['supplierMobile', 'mobile', 'phone', 'contact']);
        final date = _extractValue(reportMap, ['formattedDate', 'date', 'createdAt', 'invoiceDate']);
        final items = _extractItems(reportMap);
        final totalAmount = _extractAmountFromMap(reportMap, ['totalAmount', 'grandTotal', 'netAmount']);
        final amountPaid = _extractAmountFromMap(reportMap, ['amountPaid', 'paidAmount', 'paid']);
        final amountDue = _extractAmountFromMap(reportMap, ['amountDue', 'dueAmount', 'balance']);
        final paymentStatus = _extractValue(reportMap, ['paymentStatus', 'status', 'payment_state']);
        
        totalPurchases += totalAmount;
        totalPaid += amountPaid;
        totalDue += amountDue;
        invoiceCount++;
        
        csv += '"$invoiceNumber",'
               '"$supplierName",'
               '"$supplierMobile",'
               '"$date",'
               '"${_getUniqueCategories(items)}",'
               '"${_getItemsSummary(items)}",'
               '"${_currencyFormat.format(totalAmount)}",'
               '"${_currencyFormat.format(amountPaid)}",'
               '"${_currencyFormat.format(amountDue)}",'
               '"${paymentStatus.toUpperCase()}"\n';
      } catch (e) {
        //print('⚠️ Error processing purchase report for CSV: $e');
      }
    }
    
    final csvLines = csv.split('\n');
    csvLines.insert(5, '"Total Invoices","$invoiceCount"');
    csvLines.insert(6, '"Total Purchases","${_currencyFormat.format(totalPurchases)}"');
    csvLines.insert(7, '"Total Paid","${_currencyFormat.format(totalPaid)}"');
    csvLines.insert(8, '"Total Due","${_currencyFormat.format(totalDue)}"');
    csv = csvLines.join('\n');
    
    csv += '\n"ITEM DETAILS"\n';
    csv += '"Invoice No.","Item Name","Category","Quantity","Unit","Price","Total"\n';
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        final invoiceNumber = _extractValue(reportMap, ['invoiceNumber', 'invoiceNo', 'invoice_id']);
        final items = _extractItems(reportMap);
        
        for (var item in items) {
          final itemMap = _convertToMap(item);
          final itemName = _extractValue(itemMap, ['name', 'productName', 'itemName']);
          final category = _extractValue(itemMap, ['category', 'type', 'group']);
          final quantity = _extractValue(itemMap, ['quantity', 'qty', 'amount']);
          final unit = _extractValue(itemMap, ['unit', 'measurement', 'uom']);
          final price = _extractAmountFromMap(itemMap, ['price', 'unitPrice', 'rate']);
          final total = _extractAmountFromMap(itemMap, ['total', 'amount', 'lineTotal']);
          
          csv += '"$invoiceNumber",'
                 '"$itemName",'
                 '"${category.isNotEmpty ? category : "Uncategorized"}",'
                 '"$quantity",'
                 '"$unit",'
                 '"${_currencyFormat.format(price)}",'
                 '"${_currencyFormat.format(total)}"\n';
        }
      } catch (e) {
        //print('⚠️ Error processing purchase item details for CSV: $e');
      }
    }
    
    csv += '\n"Generated by Inventory Management System"';
    
    return csv;
  }

  // Sales Summary Calculation
  Map<String, dynamic> _calculateSalesSummary(List<dynamic> reports) {
    double totalAmount = 0;
    double paidAmount = 0;
    double pendingAmount = 0;
    int paidCount = 0;
    int pendingCount = 0;
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        final total = _extractAmountFromMap(reportMap, ['totalAmount', 'grandTotal', 'netAmount']);
        final due = _extractAmountFromMap(reportMap, ['amountDue', 'dueAmount', 'balance']);
        final status = _extractValue(reportMap, ['paymentStatus', 'status', 'payment_state']);
        
        totalAmount += total;
        
        if (status.toLowerCase().contains('paid') || due == 0) {
          paidAmount += total;
          paidCount++;
        } else {
          pendingAmount += due;
          pendingCount++;
        }
      } catch (e) {
        //print('⚠️ Error calculating sales summary: $e');
      }
    }
    
    return {
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': pendingAmount,
      'totalCount': reports.length,
      'paidCount': paidCount,
      'pendingCount': pendingCount,
    };
  }

  // Purchase Summary Calculation
  Map<String, dynamic> _calculatePurchaseSummary(List<dynamic> reports) {
    double totalAmount = 0;
    double paidAmount = 0;
    double pendingAmount = 0;
    int paidCount = 0;
    int pendingCount = 0;
    
    for (var report in reports) {
      try {
        final reportMap = _convertToMap(report);
        final total = _extractAmountFromMap(reportMap, ['totalAmount', 'grandTotal', 'netAmount']);
        final due = _extractAmountFromMap(reportMap, ['amountDue', 'dueAmount', 'balance']);
        final status = _extractValue(reportMap, ['paymentStatus', 'status', 'payment_state']);
        
        totalAmount += total;
        
        if (status.toLowerCase().contains('paid') || due == 0) {
          paidAmount += total;
          paidCount++;
        } else {
          pendingAmount += due;
          pendingCount++;
        }
      } catch (e) {
        //print('⚠️ Error calculating purchase summary: $e');
      }
    }
    
    return {
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': pendingAmount,
      'totalCount': reports.length,
      'paidCount': paidCount,
      'pendingCount': pendingCount,
    };
  }

  // ============ PDF GENERATION ============

  pw.Document _generatePdfDocument(
    List<Map<String, dynamic>> dataRows,
    Map<String, dynamic> summary,
    String title,
    String userMobile,
    DateTime startDate,
    DateTime endDate,
    String reportType,
  ) {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[
            _buildPdfHeader(title, userMobile, startDate, endDate, reportType, dataRows.length),
          ];

          // Add summary only for sales and purchase reports
          if (reportType == 'sales' || reportType == 'purchase') {
            widgets.add(pw.SizedBox(height: 12));
            widgets.add(_buildPdfSummary(summary, reportType));
          }

          widgets.add(pw.SizedBox(height: 12));
          widgets.add(_buildPdfDataTable(dataRows, reportType, context));
          widgets.add(pw.SizedBox(height: 20));
          widgets.add(_buildPdfFooter());

          return widgets;
        },
      ),
    );
    return pdf;
  }

  pw.Widget _buildPdfHeader(
    String title,
    String userMobile,
    DateTime startDate,
    DateTime endDate,
    String reportType,
    int recordCount,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _businessName ?? 'My Business',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  if (_userName != null && _userName!.isNotEmpty)
                    pw.Text(
                      _userName!,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  pw.SizedBox(height: 2),
                  if (_location != null && _location!.isNotEmpty)
                    pw.Text(
                      _location!,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                      maxLines: 2,
                    ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Text(
                        'Phone: ',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        userMobile,
                        style: pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: 7,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Inventory Management System',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.Text(
                    'Generated: ${formatDate(DateTime.now())} ${DateFormat('HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.blue200, width: 0.8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Report Type:', reportType.toUpperCase()),
                  _buildInfoRow('Period:', '${formatDate(startDate)} to ${formatDate(endDate)}'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Records:', recordCount.toString()),
                  _buildInfoRow('Report ID:', 'RPT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummary(Map<String, dynamic> summary, String reportType) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.blue200, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUMMARY',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.blue100, width: 0.5),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Total ${reportType == 'sales' ? 'Sales' : 'Purchases'}:',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('${summary['totalCount']}',
                      style: pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Total Amount:', 
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(_formatAmountForPdf(summary['totalAmount']),
                      style: pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Paid:', 
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('${summary['paidCount']}',
                      style: pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Paid Amount:', 
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(_formatAmountForPdf(summary['paidAmount']),
                      style: pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Pending:', 
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('${summary['pendingCount']}',
                      style: pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Pending Amount:', 
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(_formatAmountForPdf(summary['pendingAmount']),
                      style: pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmountForPdf(double amount) {
    return 'Rs. ${_pdfCurrencyFormat.format(amount)}';
  }

  Map<int, pw.TableColumnWidth> _getMobileColumnWidths(List<String> columns) {
    final widths = <int, pw.TableColumnWidth>{};
    
    for (var i = 0; i < columns.length; i++) {
      final col = columns[i].toLowerCase();
      
      if (col.contains('invoice') || col.contains('number')) {
        widths[i] = const pw.FixedColumnWidth(40);
      } else if (col.contains('customer') || col.contains('supplier')) {
        widths[i] = const pw.FixedColumnWidth(50);
      } else if (col.contains('mobile') || col.contains('phone')) {
        widths[i] = const pw.FixedColumnWidth(35);
      } else if (col.contains('date')) {
        widths[i] = const pw.FixedColumnWidth(30);
      } else if (col.contains('categories')) {
        widths[i] = const pw.FixedColumnWidth(50);
      } else if (col.contains('items')) {
        widths[i] = const pw.FixedColumnWidth(70);
      } else if (col.contains('amount') || col.contains('price') || col.contains('total')) {
        widths[i] = const pw.FixedColumnWidth(40);
      } else if (col.contains('status')) {
        widths[i] = const pw.FixedColumnWidth(25);
      } else if (col.contains('quantity')) {
        widths[i] = const pw.FixedColumnWidth(20);
      } else if (col.contains('unit')) {
        widths[i] = const pw.FixedColumnWidth(20);
      } else {
        widths[i] = const pw.FixedColumnWidth(40);
      }
    }
    
    return widths;
  }

  pw.Widget _buildPdfDataTable(List<Map<String, dynamic>> rows, String reportType, pw.Context context) {
    if (rows.isEmpty) {
      return pw.Center(
        child: pw.Text(
          'No data available',
          style: pw.TextStyle(
            fontSize: 11,
            color: PdfColors.grey500,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      );
    }
    
    final columns = rows.first.keys.toList();
    final tableData = <List<String>>[
      columns.map((col) => _formatColumnName(col)).toList(),
      ...rows.map((row) => 
        columns.map((col) => _formatPdfCellValue(col, row[col])).toList()
      ),
    ];
    
    return pw.Column(
      children: [
        pw.Text(
          _getTableTitle(reportType),
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          context: context,
          data: tableData,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: pw.BoxDecoration(
            color: PdfColors.blue700,
          ),
          cellStyle: pw.TextStyle(fontSize: 7),
          cellPadding: const pw.EdgeInsets.all(3),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: _getMobileColumnWidths(columns),
        ),
      ],
    );
  }

  String _formatPdfCellValue(String column, dynamic value) {
    if (value == null) return '-';
    
    final lowerColumn = column.toLowerCase();
    
    if (lowerColumn.contains('date') && value is String) {
      try {
        final date = DateTime.parse(value);
        return DateFormat('dd/MM').format(date);
      } catch (e) {
        return value.toString();
      }
    }
    
    if (lowerColumn.contains('amount') || 
        lowerColumn.contains('price') || 
        lowerColumn.contains('total') ||
        lowerColumn.contains('value')) {
      try {
        if (value is num) return _formatAmountForPdf(value.toDouble());
        if (value is String) {
          final numValue = double.tryParse(value.replaceAll(RegExp(r'[^\d.-]'), ''));
          if (numValue != null) return _formatAmountForPdf(numValue);
        }
      } catch (e) {
        // Fall through
      }
      return value.toString();
    }
    
    String truncate(String text, int maxLength) {
      if (text.length <= maxLength) return text;
      return '${text.substring(0, maxLength - 2)}..';
    }
    
    if (lowerColumn.contains('status')) {
      final status = value.toString().toLowerCase();
      
      if (status.contains('paid') || 
          status.contains('completed') || 
          status == 'true' ||
          status.contains('✓') ||
          status.contains('✅') ||
          status == '1') {
        return 'Paid';
      } else if (status.contains('pending') || 
                 status.contains('due') ||
                 status.contains('⏳') ||
                 status.contains('📄') ||
                 status.contains('invoice')) {
        return 'Pending';
      } else if (status.contains('cancel') || status.contains('void')) {
        return 'Canceled';
      } else {
        if (status.isNotEmpty) {
          return status[0].toUpperCase() + status.substring(1);
        }
        return truncate(value.toString(), 8);
      }
    }
    
    if (lowerColumn.contains('name')) {
      return truncate(value.toString(), 12);
    }
    
    if (lowerColumn.contains('mobile') || lowerColumn.contains('phone')) {
      return truncate(value.toString(), 10);
    }
    
    return truncate(value.toString(), 15);
  }

  pw.Widget _buildPdfFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Note: Computer-generated report.',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Authorized Signature: _________________',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by Inventory Management System',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                '(Authorized Person)',
                style: pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey500,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey500,
                ),
              ),
              pw.Text(
                'Page 1/1',
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Mobile PDF Generation
  Future<String> _generateMobilePdf({
    required List<Map<String, dynamic>> dataRows,
    required Map<String, dynamic> summary,
    required String title,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required String reportType,
  }) async {
    try {
      final pdf = _generatePdfDocument(dataRows, summary, title, userMobile, startDate, endDate, reportType);
      
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);
      
      //print('📄 PDF saved to: $filePath');
      await openFile(filePath);
      
      return '✅ PDF saved to: $filePath';
    } catch (e) {
      //print('❌ Mobile PDF generation error: $e');
      return 'Failed to generate PDF: $e';
    }
  }

  // File Operations
  Future<void> openFile(String filePath) async {
    if (!kIsWeb) {
      final result = await OpenFile.open(filePath);
      //print('📂 Open file result: ${result.message}');
    } else {
      //print('📂 On web, files are downloaded directly to browser');
    }
  }

  Future<String> _saveCsvToMobile(String csvContent, String reportType) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${reportType}_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      await file.writeAsString(csvContent);
      await openFile(filePath);
      
      return '✅ CSV saved to: $filePath';
    } catch (e) {
      //print('❌ Error saving CSV: $e');
      return 'Failed to save CSV file: $e';
    }
  }

  // Web Download Methods
  Future<bool> _downloadPdfWeb(Uint8List pdfBytes, String fileName) async {
    try {
      if (!kIsWeb) return false;
      
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      
      html.document.body?.append(anchor);
      anchor.click();
      
      Future.delayed(Duration(milliseconds: 100), () {
        anchor.remove();
        html.Url.revokeObjectUrl(url);
      });
      
      //print('✅ PDF download initiated: $fileName');
      return true;
    } catch (e) {
      //print('❌ PDF download failed: $e');
      return false;
    }
  }

  Future<bool> _realWebDownload(String content, String fileName, String mimeType) async {
    try {
      if (!kIsWeb) return false;
      
      final success = await _downloadWithUniversalHtml(content, fileName, mimeType);
      if (success) return true;
      
      return await _downloadWithDataUri(content, fileName);
    } catch (e) {
      //print('❌ Real web download error: $e');
      return false;
    }
  }

  Future<bool> _downloadWithUniversalHtml(String content, String fileName, String mimeType) async {
    try {
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      
      html.document.body?.append(anchor);
      anchor.click();
      
      Future.delayed(Duration(milliseconds: 100), () {
        anchor.remove();
        html.Url.revokeObjectUrl(url);
      });
      
      //print('✅ Download initiated via universal_html: $fileName');
      return true;
    } catch (e) {
      //print('❌ Universal HTML download failed: $e');
      return false;
    }
  }

  Future<bool> _downloadWithDataUri(String content, String fileName) async {
    try {
      final dataUri = 'data:text/plain;charset=utf-8,${Uri.encodeComponent(content)}';
      
      final downloadLink = '''
        <a href="$dataUri" download="$fileName" id="downloadLink" style="display:none;">
          Download $fileName
        </a>
        <script>
          document.getElementById('downloadLink').click();
        </script>
      ''';
      
      _injectHtml(downloadLink);
      
      //print('✅ Download attempted via data URI: $fileName');
      return true;
    } catch (e) {
      //print('❌ Data URI download failed: $e');
      return false;
    }
  }

  void _injectHtml(String htmlString) {
    if (kIsWeb) {
      final div = html.DivElement()
        ..style.display = 'none'
        ..innerHtml = htmlString;
      
      html.document.body?.append(div);
      
      Future.delayed(Duration(milliseconds: 100), () {
        div.remove();
      });
    }
  }

  // Generic CSV Content Creation (fallback)
  String _createCsvContent({
    required String reportType,
    required String userMobile,
    required DateTime startDate,
    required DateTime endDate,
    required dynamic data,
  }) {
    final dataRows = _parseDataToRows(data, reportType);
    
    String csv = '"${reportType.toUpperCase()} REPORT"\n\n';
    
    csv += '"METADATA"\n';
    csv += '"User","$userMobile"\n';
    csv += '"Start Date","${formatDate(startDate)}"\n';
    csv += '"End Date","${formatDate(endDate)}"\n';
    csv += '"Generated","${formatDate(DateTime.now())}"\n';
    csv += '"Total Records","${dataRows.length}"\n\n';
    
    if (dataRows.isNotEmpty) {
      final headers = dataRows.first.keys.toList();
      csv += '"REPORT DATA"\n';
      csv += '${headers.map((h) => '"${_formatColumnName(h)}"').join(',')}\n';
      
      for (var row in dataRows) {
        final rowData = headers.map((h) => '"${_formatCsvCellValue(h, row[h])}"').join(',');
        csv += '$rowData\n';
      }
    } else {
      csv += '"REPORT DATA"\n';
      csv += '"No data available for the selected period"\n';
    }
    
    csv += '\n"Generated by Inventory Management System"';
    
    return csv;
  }

  // Helper Methods
  List<Map<String, dynamic>> _parseDataToRows(dynamic data, String reportType) {
    final List<Map<String, dynamic>> rows = [];
    
    try {
      if (data == null) return rows;
      
      if (data is List) {
        for (var item in data) {
          if (item is Map) {
            rows.add(Map<String, dynamic>.from(item));
          }
        }
      } else if (data is Map) {
        rows.add(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      //print('❌ Error parsing data: $e');
    }
    
    return rows;
  }

  Map<String, dynamic> _calculateSummary(List<Map<String, dynamic>> rows, String reportType) {
    double totalAmount = 0;
    double paidAmount = 0;
    double pendingAmount = 0;
    int paidCount = 0;
    int pendingCount = 0;
    
    for (var row in rows) {
      try {
        final amount = _extractAmountFromRow(row);
        totalAmount += amount;
        
        final status = _extractStatusFromRow(row);
        if (status.toLowerCase().contains('paid') || status.toLowerCase().contains('completed')) {
          paidAmount += amount;
          paidCount++;
        } else {
          pendingAmount += amount;
          pendingCount++;
        }
      } catch (e) {
        continue;
      }
    }
    
    return {
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': pendingAmount,
      'totalCount': rows.length,
      'paidCount': paidCount,
      'pendingCount': pendingCount,
    };
  }

  double _extractAmountFromRow(Map<String, dynamic> row) {
    final amountFields = ['amount', 'total', 'value', 'price', 'grandTotal', 'netAmount', 'totalAmount'];
    
    for (var field in amountFields) {
      if (row.containsKey(field) && row[field] != null) {
        try {
          final value = row[field];
          if (value is num) return value.toDouble();
          if (value is String) {
            final cleanValue = value.replaceAll(RegExp(r'[^\d.-]'), '');
            return double.tryParse(cleanValue) ?? 0.0;
          }
        } catch (e) {
          continue;
        }
      }
    }
    return 0.0;
  }

  String _extractStatusFromRow(Map<String, dynamic> row) {
    final statusFields = ['status', 'paymentStatus', 'state', 'paymentState'];
    
    for (var field in statusFields) {
      if (row.containsKey(field) && row[field] != null) {
        final value = row[field].toString().toLowerCase();
        return value;
      }
    }
    return 'pending';
  }

  String _formatColumnName(String columnName) {
    return columnName
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => ' ${match.group(0)}')
        .trim()
        .split(' ')
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : '')
        .join(' ');
  }

  String _formatCsvCellValue(String column, dynamic value) {
    if (value == null) return '';
    
    final lowerColumn = column.toLowerCase();
    
    if (lowerColumn.contains('date') && value is String) {
      try {
        final date = DateTime.parse(value);
        return formatDate(date);
      } catch (e) {
        return value.toString();
      }
    }
    
    if (lowerColumn.contains('amount') || 
        lowerColumn.contains('price') || 
        lowerColumn.contains('total') ||
        lowerColumn.contains('value')) {
      try {
        if (value is num) return _currencyFormat.format(value);
        if (value is String) {
          final numValue = double.tryParse(value.replaceAll(RegExp(r'[^\d.-]'), ''));
          if (numValue != null) return _currencyFormat.format(numValue);
        }
      } catch (e) {
        // Fall through
      }
    }
    
    if (lowerColumn.contains('status')) {
      final status = value.toString().toLowerCase();
      
      if (status.contains('paid') || 
          status.contains('completed') || 
          status == 'true' ||
          status.contains('✓') ||
          status.contains('✅') ||
          status == '1') {
        return 'Paid';
      } else if (status.contains('pending') || 
                 status.contains('due') ||
                 status.contains('⏳') ||
                 status.contains('📄') ||
                 status.contains('invoice')) {
        return 'Pending';
      } else if (status.contains('cancel') || status.contains('void')) {
        return 'Canceled';
      }
    }
    
    return value.toString();
  }

  // Format date helper
  String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }
}