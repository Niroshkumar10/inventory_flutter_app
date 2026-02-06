import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Import your existing models - UPDATE THESE PATHS BASED ON YOUR STRUCTURE
import '../../bill/models/bill_model.dart';
import '../../inventory/models/inventory_item_model.dart';
import '../../party/models/customer_model.dart';
import '../../party/models/supplier_model.dart';

// Report Summary Model
class ReportSummary {
  final String id;
  final String title;
  final double value;
  final String change;
  final bool isPositive;
  final String icon;
  final String subTitle;
  final String reportType; // sales, purchase, inventory, customer, supplier
  final DateTime periodStart;
  final DateTime periodEnd;
  final String userMobile;

  ReportSummary({
    required this.id,
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    required this.subTitle,
    required this.reportType,
    required this.periodStart,
    required this.periodEnd,
    required this.userMobile,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'value': value,
      'change': change,
      'isPositive': isPositive,
      'icon': icon,
      'subTitle': subTitle,
      'reportType': reportType,
      'periodStart': FieldValue.serverTimestamp(),
      'periodEnd': FieldValue.serverTimestamp(),
      'userMobile': userMobile,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ReportSummary.fromMap(Map<String, dynamic> map, String id) {
    return ReportSummary(
      id: id,
      title: map['title'] ?? '',
      value: (map['value'] ?? 0).toDouble(),
      change: map['change'] ?? '',
      isPositive: map['isPositive'] ?? false,
      icon: map['icon'] ?? '',
      subTitle: map['subTitle'] ?? '',
      reportType: map['reportType'] ?? '',
      periodStart: (map['periodStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodEnd: (map['periodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userMobile: map['userMobile'] ?? '',
    );
  }
}

class SalesReport {
  final String billId;
  final String invoiceNumber;
  final DateTime date;
  final String customerName;
  final String customerMobile;
  final String customerAddress;
  final int totalItems;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final double amountPaid;
  final double amountDue;
  final String paymentStatus;
  final String userMobile;
  final List<SaleItemDetail> items;

  SalesReport({
    required this.billId,
    required this.invoiceNumber,
    required this.date,
    required this.customerName,
    required this.customerMobile,
    required this.customerAddress,
    required this.totalItems,
    required this.subtotal,
    required this.gstAmount,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountDue,
    required this.paymentStatus,
    required this.userMobile,
    required this.items,
  });

  // Helper to format currency
  String get formattedTotal => '₹${NumberFormat('#,##0.00').format(totalAmount)}';
  String get formattedDue => '₹${NumberFormat('#,##0.00').format(amountDue)}';
  String get formattedDate => DateFormat('dd MMM yyyy').format(date);

  // Helper methods for UI
  String get itemNames {
    if (items.isEmpty) return 'No items';
    return items.map((item) => item.name).join(', ');
  }

  String get categories {
    if (items.isEmpty) return 'No categories';
    final uniqueCategories = items
        .where((item) => item.category != null && item.category!.isNotEmpty)
        .map((item) => item.category!)
        .toSet();
    return uniqueCategories.isEmpty ? 'No categories' : uniqueCategories.join(', ');
  }

  String get itemsWithQuantities {
    if (items.isEmpty) return 'No items';
    return items.map((item) => '${item.name} ×${item.quantity}').join(', ');
  }

  // Create from Bill model
  factory SalesReport.fromBill(Bill bill) {
    return SalesReport(
      billId: bill.id,
      invoiceNumber: bill.invoiceNumber,
      date: bill.date,
      customerName: bill.partyName,
      customerMobile: bill.partyPhone,
      customerAddress: bill.partyAddress,
      totalItems: bill.items.length,
      subtotal: bill.subtotal,
      gstAmount: bill.gstAmount,
      totalAmount: bill.totalAmount,
      amountPaid: bill.amountPaid,
      amountDue: bill.amountDue,
      paymentStatus: bill.paymentStatus,
      userMobile: bill.userMobile,
      items: bill.items.map((item) => SaleItemDetail.fromBillItem(item)).toList(),
    );
  }

  // Add toMap method if needed
  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'invoiceNumber': invoiceNumber,
      'date': date,
      'customerName': customerName,
      'customerMobile': customerMobile,
      'customerAddress': customerAddress,
      'totalItems': totalItems,
      'subtotal': subtotal,
      'gstAmount': gstAmount,
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'amountDue': amountDue,
      'paymentStatus': paymentStatus,
      'userMobile': userMobile,
      'items': items.map((item) => item.toMap()).toList(),
    'categories': categories, // Include categories string
    };
  }
}

class SaleItemDetail {
  final String id;
  final String name;
  final String? category;
  final double quantity;
  final double price;
  final double total;
  final String? unit;
  final String description;

  SaleItemDetail({
    required this.id,
    required this.name,
    this.category,
    required this.quantity,
    required this.price,
    required this.total,
    this.unit,
    required this.description,
  });

  factory SaleItemDetail.fromBillItem(BillItem item) {
    return SaleItemDetail(
      id: item.id,
      name: item.itemName,
      category: item.category,
      quantity: item.quantity,
      price: item.price,
      total: item.total,
      unit: item.unit,
      description: item.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'price': price,
      'total': total,
      'unit': unit,
      'description': description,
    };
  }
}

// Purchase Report Model (extends your Bill model for purchases)

class PurchaseReport {
  final String billId;
  final String invoiceNumber;
  final DateTime date;
  final String supplierName;
  final String supplierMobile;
  final String supplierAddress;
  final int totalItems;
  final double subtotal;
  final double gstAmount;
  final double totalAmount;
  final double amountPaid;
  final double amountDue;
  final String paymentStatus;
  final String userMobile;
  final List<PurchaseItemDetail> items; // Add this

  PurchaseReport({
    required this.billId,
    required this.invoiceNumber,
    required this.date,
    required this.supplierName,
    required this.supplierMobile,
    required this.supplierAddress,
    required this.totalItems,
    required this.subtotal,
    required this.gstAmount,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountDue,
    required this.paymentStatus,
    required this.userMobile,
    required this.items, // Add this
  });

  // Helper to format currency
  String get formattedTotal => '₹${NumberFormat('#,##0.00').format(totalAmount)}';
  String get formattedDue => '₹${NumberFormat('#,##0.00').format(amountDue)}';
  String get formattedDate => DateFormat('dd MMM yyyy').format(date);

  // Helper methods for UI
  String get itemNames {
    if (items.isEmpty) return 'No items';
    return items.map((item) => item.name).join(', ');
  }

  String get categories {
    if (items.isEmpty) return 'No categories';
    final uniqueCategories = items
        .where((item) => item.category != null && item.category!.isNotEmpty)
        .map((item) => item.category!)
        .toSet();
    return uniqueCategories.isEmpty ? 'No categories' : uniqueCategories.join(', ');
  }

  String get itemsWithQuantities {
    if (items.isEmpty) return 'No items';
    return items.map((item) => '${item.name} ×${item.quantity}').join(', ');
  }

  // Create from Bill model
  factory PurchaseReport.fromBill(Bill bill) {
    return PurchaseReport(
      billId: bill.id,
      invoiceNumber: bill.invoiceNumber,
      date: bill.date,
      supplierName: bill.partyName,
      supplierMobile: bill.partyPhone,
      supplierAddress: bill.partyAddress,
      totalItems: bill.items.length,
      subtotal: bill.subtotal,
      gstAmount: bill.gstAmount,
      totalAmount: bill.totalAmount,
      amountPaid: bill.amountPaid,
      amountDue: bill.amountDue,
      paymentStatus: bill.paymentStatus,
      userMobile: bill.userMobile,
      items: bill.items.map((item) => PurchaseItemDetail.fromBillItem(item)).toList(), // Add this
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'billId': billId,
      'invoiceNumber': invoiceNumber,
      'date': date,
      'supplierName': supplierName,
      'supplierMobile': supplierMobile,
      'supplierAddress': supplierAddress,
      'totalItems': totalItems,
      'subtotal': subtotal,
      'gstAmount': gstAmount,
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'amountDue': amountDue,
      'paymentStatus': paymentStatus,
      'userMobile': userMobile,
      'items': items.map((item) => item.toMap()).toList(), // Add this
          'categories': categories, // Include categories string

    };
  }
}

class PurchaseItemDetail {
  final String id;
  final String name;
  final String? category;
  final double quantity;
  final double price;
  final double total;
  final String? unit;
  final String description;

  PurchaseItemDetail({
    required this.id,
    required this.name,
    this.category,
    required this.quantity,
    required this.price,
    required this.total,
    this.unit,
    required this.description,
  });

  factory PurchaseItemDetail.fromBillItem(BillItem item) {
    return PurchaseItemDetail(
      id: item.id,
      name: item.itemName,
      category: item.category,
      quantity: item.quantity,
      price: item.price,
      total: item.total,
      unit: item.unit,
      description: item.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'price': price,
      'total': total,
      'unit': unit,
      'description': description,
    };
  }
}
// Inventory Report Model (extends your InventoryItem model)
class InventoryReport {
  final String itemId;
  final String name;
  final String sku;
  final String category;
  final int quantity;
  final int lowStockThreshold;
  final double price;
  final double cost;
  final double totalValue;
  final String unit;
  final String status; // in-stock, low-stock, out-of-stock
  final DateTime lastUpdated;
  final String userMobile;

  InventoryReport({
    required this.itemId,
    required this.name,
    required this.sku,
    required this.category,
    required this.quantity,
    required this.lowStockThreshold,
    required this.price,
    required this.cost,
    required this.totalValue,
    required this.unit,
    required this.status,
    required this.lastUpdated,
    required this.userMobile,
  });

  String get formattedValue => '₹${NumberFormat('#,##0.00').format(totalValue)}';
  String get formattedPrice => '₹${NumberFormat('#,##0.00').format(price)}';
  String get formattedCost => '₹${NumberFormat('#,##0.00').format(cost)}';
  String get formattedDate => DateFormat('dd MMM yyyy').format(lastUpdated);
  double get profitMargin => price > 0 ? ((price - cost) / price) * 100 : 0;
  String get formattedMargin => '${profitMargin.toStringAsFixed(1)}%';

  factory InventoryReport.fromInventoryItem(InventoryItem item) {
    String status = 'in-stock';
    if (item.quantity <= 0) {
      status = 'out-of-stock';
    } else if (item.quantity <= item.lowStockThreshold) {
      status = 'low-stock';
    }

    return InventoryReport(
      itemId: item.id,
      name: item.name,
      sku: item.sku,
      category: item.category,
      quantity: item.quantity,
      lowStockThreshold: item.lowStockThreshold,
      price: item.price,
      cost: item.cost,
      totalValue: item.totalValue,
      unit: item.unit,
      status: status,
      lastUpdated: item.updatedAt,
      userMobile: item.userMobile,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'name': name,
      'sku': sku,
      'category': category,
      'quantity': quantity,
      'lowStockThreshold': lowStockThreshold,
      'price': price,
      'cost': cost,
      'totalValue': totalValue,
      'unit': unit,
      'status': status,
      'lastUpdated': lastUpdated,
      'userMobile': userMobile,
    };
  }
}

// Customer Report Model (extends your Customer model)
class CustomerReport {
  final String customerId;
  final String name;
  final String mobile;
  final String address;
  final int totalPurchases;
  final double totalSpent;
  final double outstandingBalance;
  final DateTime lastPurchaseDate;
  final String userMobile;

  CustomerReport({
    required this.customerId,
    required this.name,
    required this.mobile,
    required this.address,
    required this.totalPurchases,
    required this.totalSpent,
    required this.outstandingBalance,
    required this.lastPurchaseDate,
    required this.userMobile,
  });

  String get formattedTotalSpent => '₹${NumberFormat('#,##0.00').format(totalSpent)}';
  String get formattedOutstanding => '₹${NumberFormat('#,##0.00').format(outstandingBalance)}';
  String get formattedLastPurchase => DateFormat('dd MMM yyyy').format(lastPurchaseDate);
  double get avgPurchaseValue => totalPurchases > 0 ? totalSpent / totalPurchases : 0;

  factory CustomerReport.fromCustomer(Customer customer, {
    required int totalPurchases,
    required double totalSpent,
    required double outstandingBalance,
    required DateTime lastPurchaseDate,
  }) {
    return CustomerReport(
      customerId: customer.id,
      name: customer.name,
      mobile: customer.mobile,
      address: customer.address,
      totalPurchases: totalPurchases,
      totalSpent: totalSpent,
      outstandingBalance: outstandingBalance,
      lastPurchaseDate: lastPurchaseDate,
      userMobile: customer.userMobile,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'name': name,
      'mobile': mobile,
      'address': address,
      'totalPurchases': totalPurchases,
      'totalSpent': totalSpent,
      'outstandingBalance': outstandingBalance,
      'lastPurchaseDate': lastPurchaseDate,
      'userMobile': userMobile,
    };
  }
}

// Supplier Report Model (extends your Supplier model)
class SupplierReport {
  final String supplierId;
  final String name;
  final String phone;
  final String email;
  final String address;
  final int totalOrders;
  final double totalPurchases;
  final double pendingPayment;
  final DateTime lastOrderDate;
  final String userMobile;
  final bool isActive; // Add this

  SupplierReport({
    required this.supplierId,
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
    required this.totalOrders,
    required this.totalPurchases,
    required this.pendingPayment,
    required this.lastOrderDate,
    required this.userMobile,
    required this.isActive, // Add this
  });

  String get formattedPurchases => '₹${NumberFormat('#,##0.00').format(totalPurchases)}';
  String get formattedPending => '₹${NumberFormat('#,##0.00').format(pendingPayment)}';
  String get formattedLastOrder => DateFormat('dd MMM yyyy').format(lastOrderDate);
  double get avgOrderValue => totalOrders > 0 ? totalPurchases / totalOrders : 0;

  factory SupplierReport.fromSupplier(Supplier supplier, {
    required int totalOrders,
    required double totalPurchases,
    required double pendingPayment,
    required DateTime lastOrderDate,
  }) {
    return SupplierReport(
      supplierId: supplier.id,
      name: supplier.name,
      phone: supplier.phone,
      email: supplier.email,
      address: supplier.address,
      totalOrders: totalOrders,
      totalPurchases: totalPurchases,
      pendingPayment: pendingPayment,
      lastOrderDate: lastOrderDate,
      userMobile: supplier.userMobile,
      isActive: supplier.isActive, // Add this
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'totalOrders': totalOrders,
      'totalPurchases': totalPurchases,
      'pendingPayment': pendingPayment,
      'lastOrderDate': lastOrderDate,
      'userMobile': userMobile,
      'isActive': isActive, // Add this
    };
  }
}
// Profit & Loss Report Model
class ProfitLossReport {
  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final double profitMargin;
  final String userMobile;
  final DateTime generatedAt;

  ProfitLossReport({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.profitMargin,
    required this.userMobile,
    required this.generatedAt,
  });

  String get formattedRevenue => '₹${NumberFormat('#,##0.00').format(totalRevenue)}';
  String get formattedProfit => '₹${NumberFormat('#,##0.00').format(netProfit)}';
  String get formattedMargin => '${profitMargin.toStringAsFixed(1)}%';
  String get formattedPeriod => '${DateFormat('dd MMM yyyy').format(periodStart)} - ${DateFormat('dd MMM yyyy').format(periodEnd)}';

  Map<String, dynamic> toMap() {
    return {
      'periodStart': FieldValue.serverTimestamp(),
      'periodEnd': FieldValue.serverTimestamp(),
      'totalRevenue': totalRevenue,
      'totalCost': totalCost,
      'grossProfit': grossProfit,
      'expenses': expenses,
      'netProfit': netProfit,
      'profitMargin': profitMargin,
      'userMobile': userMobile,
      'generatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ProfitLossReport.fromMap(Map<String, dynamic> map, String id) {
    return ProfitLossReport(
      id: id,
      periodStart: (map['periodStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      periodEnd: (map['periodEnd'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalRevenue: (map['totalRevenue'] ?? 0).toDouble(),
      totalCost: (map['totalCost'] ?? 0).toDouble(),
      grossProfit: (map['grossProfit'] ?? 0).toDouble(),
      expenses: (map['expenses'] ?? 0).toDouble(),
      netProfit: (map['netProfit'] ?? 0).toDouble(),
      profitMargin: (map['profitMargin'] ?? 0).toDouble(),
      userMobile: map['userMobile'] ?? '',
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// Report Filter Model
class ReportFilter {
  final DateTime startDate;
  final DateTime endDate;
  final String reportType;
  final String? customerId;
  final String? supplierId;
  final String? category;
  final String? paymentStatus;
  final String userMobile;

  ReportFilter({
    required this.startDate,
    required this.endDate,
    required this.reportType,
    this.customerId,
    this.supplierId,
    this.category,
    this.paymentStatus,
    required this.userMobile,
  });

  Map<String, dynamic> toQuery() {
    final query = <String, dynamic>{
      'userMobile': userMobile,
    };

    if (customerId != null && customerId!.isNotEmpty) {
      query['partyName'] = customerId; // Assuming customerId is stored as partyName in bills
    }

    if (supplierId != null && supplierId!.isNotEmpty) {
      query['partyName'] = supplierId; // Assuming supplierId is stored as partyName in bills
    }

    if (paymentStatus != null && paymentStatus!.isNotEmpty) {
      query['paymentStatus'] = paymentStatus;
    }

    return query;
  }
}

// Chart Data Model
class ChartData {
  final String label;
  final double value;
  final String color;

  ChartData({
    required this.label,
    required this.value,
    required this.color,
  });
}