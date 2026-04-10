// lib/features/reports/screens/reports_dashboard_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/report_service.dart';
import '../models/report_model.dart';
import '../../session/session_service_new.dart';
import '../services/export_service.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({super.key});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  final ReportService _reportService = ReportService();
  final ExportService _exportService = ExportService();
  
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'Last Month', 'Custom'];
  String _selectedPeriod = 'This Month';
  int _selectedTab = 0;
  String _searchQuery = '';
  String _inventoryFilter = "all"; // all | low | out
String _getFilterLabel() {
  switch (_inventoryFilter) {
    case "low":
      return "Low Stock";
    case "out":
      return "Out of Stock";
    default:
      return "All";
  }
}
  List<SalesReport> _salesReports = [];
  List<PurchaseReport> _purchaseReports = [];
  List<InventoryReport> _inventoryReports = [];
  List<CustomerReport> _customerReports = [];
  List<SupplierReport> _supplierReports = [];
  
  
bool _exportLowStockOnly = false;
  bool _isLoading = true;
  bool _isExporting = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  DateTimeRange? _selectedDateRange;

  String? _userMobile;
  String _paymentStatusFilter = 'all';
  String _sortBy = 'date_desc';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndReports();
  }

  Future<void> _loadCurrentUserAndReports() async {
    try {
      _userMobile = await SessionServiceNew.getUserId();
      if (_userMobile == null || _userMobile!.isEmpty) {
        _showError('Please login to view reports');
        setState(() => _isLoading = false);
        return;
      }
      await _loadReports();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load user: $e');
    }
  }

  Future<void> _loadReports() async {
    if (_userMobile == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final futures = await Future.wait([
        _reportService.getSalesReports(
          userMobile: _userMobile!,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _reportService.getPurchaseReports(
          userMobile: _userMobile!,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _reportService.getInventoryReports(userMobile: _userMobile!),
        _reportService.getCustomerReports(
          userMobile: _userMobile!,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _reportService.getSupplierReports(
          userMobile: _userMobile!,
          startDate: _startDate,
          endDate: _endDate,
        ),
      ]);

      setState(() {
        _salesReports = futures[0] as List<SalesReport>;
        _purchaseReports = futures[1] as List<PurchaseReport>;
        _inventoryReports = futures[2] as List<InventoryReport>;
        _customerReports = futures[3] as List<CustomerReport>;
        _supplierReports = futures[4] as List<SupplierReport>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load reports: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Reports',
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          if (!_isExporting)
            IconButton(
              icon: Icon(Icons.download, color: colorScheme.onSurface),
              onPressed: _showExportDialog,
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onSurface),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _userMobile == null
              ? _buildNotLoggedInState()
              : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Date Range Card
          _buildDateRangeCard(),
          
          // Report Type Selector
          _buildReportTypeSelector(),
          
          // Dynamic Content based on selected tab
          _buildReportContent(),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
  final isSelected = _inventoryFilter == value;

  return GestureDetector(
    onTap: () {
      setState(() {
        _inventoryFilter = value;
      });
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.purple.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.purple : Colors.grey,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.purple : Colors.black,
        ),
      ),
    ),
  );
}

  Widget _buildDateRangeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: isDark ? colorScheme.surface : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with period dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Date Range',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    
                    // Period dropdown - Mobile optimized
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPeriod,
                          isDense: true,
                          icon: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          items: _periods.map((period) {
                            return DropdownMenuItem<String>(
                              value: period,
                              child: Text(
                                period,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _selectPeriod(value);
                            }
                          },
                          dropdownColor: isDark ? colorScheme.surface : Colors.white,
                          elevation: isDark ? 8 : 4,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Date range boxes
                Row(
                  children: [
                    Expanded(
                      child: _buildDateBox(
                        'START DATE',
                        DateFormat('dd MMM yyyy').format(_startDate),
                        Icons.calendar_today_rounded,
                      ),
                    ),
                    
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                    
                    Expanded(
                      child: _buildDateBox(
                        'END DATE',
                        DateFormat('dd MMM yyyy').format(_endDate),
                        Icons.calendar_today_rounded,
                      ),
                    ),
                  ],
                ),
                
                if (_selectedPeriod == 'Custom') ...[
                  const SizedBox(height: 16),
                  // Custom range button
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextButton.icon(
                        onPressed: () {
                          _selectCustomDateRange();
                        },
                        icon: Icon(
                          Icons.edit_calendar_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        label: Text(
                          'Change Custom Range',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateBox(String label, String date, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11, 
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 14, color: colorScheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  date,
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final types = ['Sales', 'Purchase', 'P&L', 'Inventory', 'Customer', 'Supplier'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedTab == index;
          final tabColor = _getTabColor(index);
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTab = index;
                _paymentStatusFilter = 'all';
              });
            },
            child: Container(
              width: 90,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? tabColor.withOpacity(0.1) 
                    : colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? tabColor : colorScheme.outline,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected ? null : [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getTabIcon(index),
                    color: isSelected ? tabColor : colorScheme.onSurface.withOpacity(0.6),
                    size: 26,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    types[index],
                    style: TextStyle(
                      color: isSelected ? tabColor : colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getTabIcon(int index) {
    switch (index) {
      case 0: return Icons.trending_up;
      case 1: return Icons.shopping_cart;
      case 2: return Icons.analytics;
      case 3: return Icons.inventory;
      case 4: return Icons.people;
      case 5: return Icons.group;
      default: return Icons.receipt;
    }
  }

  Color _getTabColor(int index) {
    switch (index) {
      case 0: return Colors.green;
      case 1: return Colors.orange;
      case 2: return Colors.blue;
      case 3: return Colors.purple;
      case 4: return Colors.teal;
      case 5: return Colors.indigo;
      default: return Colors.blue;
    }
  }

  Widget _buildReportContent() {
    switch (_selectedTab) {
      case 0: return _buildSalesReport();
      case 1: return _buildPurchaseReport();
      case 2: return _buildProfitLossReport();
      case 3: return _buildInventoryReport();
      case 4: return _buildCustomerReport();
      case 5: return _buildSupplierReport();
      default: return _buildSalesReport();
    }
  }

  // Sales Report
  Widget _buildSalesReport() {
    if (_salesReports.isEmpty) {
      return _buildEmptyState(
        icon: Icons.trending_up,
        title: 'No Sales Data',
        message: 'No sales transactions found for this period',
        color: Colors.green,
      );
    }

    final filteredReports = _filterAndSortReports(_salesReports);
    final totalSales = _salesReports.fold(0.0, (sum, r) => sum + r.totalAmount);
    final totalDue = _salesReports.fold(0.0, (sum, r) => sum + r.amountDue);
    final totalPaid = _salesReports.fold(0.0, (sum, r) => sum + r.amountPaid);

    return Column(
      children: [
        // Summary Cards
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Sales',
                  '₹${NumberFormat('#,##0.00').format(totalSales)}',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Collected',
                  '₹${NumberFormat('#,##0.00').format(totalPaid)}',
                  Icons.check_circle,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Due',
                  '₹${NumberFormat('#,##0.00').format(totalDue)}',
                  Icons.access_time,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Invoices',
                  '${_salesReports.length}',
                  Icons.receipt,
                  Colors.purple,
                  isCount: true,
                ),
              ),
            ],
          ),
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Status',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusChip('All', 'all', Colors.blue),
                    _buildStatusChip('Paid', 'paid', Colors.green),
                    _buildStatusChip('Partial', 'partial', Colors.orange),
                    _buildStatusChip('Due', 'due', Colors.red),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sort By',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildSortChip('Newest', 'date_desc'),
                  _buildSortChip('Oldest', 'date_asc'),
                  _buildSortChip('Amount ↑', 'amount_asc'),
                  _buildSortChip('Amount ↓', 'amount_desc'),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search by invoice or customer',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search, 
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ],
          ),
        ),

        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Showing ${filteredReports.length} of ${_salesReports.length} transactions',
            style: TextStyle(
              fontSize: 13, 
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),

        // List
        ...filteredReports.map((report) => _buildSalesCard(report)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isCount = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12, 
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesCard(SalesReport report) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
                   Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.shopping_cart, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.invoiceNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.customerName,
                      style: TextStyle(
                        fontSize: 14, 
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    // 👇 NEW: Show paid amount for partial payments
                    if (report.paymentStatus == 'partial')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Paid: ₹${NumberFormat('#,##0.00').format(report.amountPaid)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildStatusBadge(report.paymentStatus),
            ],
          ),
          Divider(height: 20, color: colorScheme.outline),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    report.formattedDate,
                    style: TextStyle(
                      fontSize: 13, 
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              Text(
                '₹${NumberFormat('#,##0.00').format(report.totalAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 18, 
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory, size: 14, color: colorScheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    report.items.map((i) => i.name).join(', '),
                    style: TextStyle(
                      fontSize: 13, 
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Purchase Report
  Widget _buildPurchaseReport() {
    if (_purchaseReports.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_cart,
        title: 'No Purchase Data',
        message: 'No purchase transactions found',
        color: Colors.orange,
      );
    }

    final filteredReports = _filterAndSortReports(_purchaseReports);
    final totalPurchases = _purchaseReports.fold(0.0, (sum, r) => sum + r.totalAmount);
    final totalDue = _purchaseReports.fold(0.0, (sum, r) => sum + r.amountDue);
    final totalPaid = _purchaseReports.fold(0.0, (sum, r) => sum + r.amountPaid);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Purchases',
                  '₹${NumberFormat('#,##0.00').format(totalPurchases)}',
                  Icons.shopping_cart,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Paid',
                  '₹${NumberFormat('#,##0.00').format(totalPaid)}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Due',
                  '₹${NumberFormat('#,##0.00').format(totalDue)}',
                  Icons.access_time,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Invoices',
                  '${_purchaseReports.length}',
                  Icons.receipt,
                  Colors.purple,
                  isCount: true,
                ),
              ),
            ],
          ),
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Status',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusChip('All', 'all', Colors.blue),
                    _buildStatusChip('Paid', 'paid', Colors.green),
                    _buildStatusChip('Partial', 'partial', Colors.orange),
                    _buildStatusChip('Due', 'due', Colors.red),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sort By',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildSortChip('Newest', 'date_desc'),
                  _buildSortChip('Oldest', 'date_asc'),
                  _buildSortChip('Amount ↑', 'amount_asc'),
                  _buildSortChip('Amount ↓', 'amount_desc'),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search by invoice or supplier',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search, 
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Showing ${filteredReports.length} of ${_purchaseReports.length} transactions',
            style: TextStyle(
              fontSize: 13, 
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),

        ...filteredReports.map((report) => _buildPurchaseCard(report)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPurchaseCard(PurchaseReport report) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.inventory, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.invoiceNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.supplierName,
                      style: TextStyle(
                        fontSize: 14, 
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(report.paymentStatus),
            ],
          ),
          Divider(height: 20, color: colorScheme.outline),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    report.formattedDate,
                    style: TextStyle(
                      fontSize: 13, 
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              Text(
                '₹${NumberFormat('#,##0.00').format(report.totalAmount)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 18, 
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory, size: 14, color: colorScheme.onSurface.withOpacity(0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    report.items.map((i) => i.name).join(', '),
                    style: TextStyle(
                      fontSize: 13, 
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Profit & Loss Report
  Widget _buildProfitLossReport() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<ProfitLossReport>(
      future: _reportService.getProfitLossReport(
        userMobile: _userMobile!,
        startDate: _startDate,
        endDate: _endDate,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildEmptyState(
            icon: Icons.analytics,
            title: 'No Data Available',
            message: 'No profit/loss data for this period',
            color: Colors.blue,
          );
        }
        
        final report = snapshot.data!;
        final isProfit = report.netProfit >= 0;
        final grossMargin = report.grossProfit > 0 && report.totalCost > 0
            ? (report.grossProfit / (report.grossProfit + report.totalCost)) * 100
            : 0;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Period
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                ),
                child: Text(
                  '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                  style: TextStyle(
                    color: colorScheme.primary, 
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // P&L Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildPLRow('Revenue', report.formattedRevenue, Colors.green),
                    const SizedBox(height: 12),
_buildPLRow('Cost of Goods', '₹${NumberFormat('#,##0.00').format(report.totalCost)}', Colors.red),    
                Divider(height: 24, color: colorScheme.outline),
                    _buildPLRow('Gross Profit', '₹${NumberFormat('#,##0.00').format(report.grossProfit)}', Colors.blue, isBold: true),
                    if (report.grossProfit > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Gross Margin: ${grossMargin.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: colorScheme.primary, 
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
if (report.expenses > 0) ...[
  _buildPLRow('Expenses', '₹${NumberFormat('#,##0.00').format(report.expenses)}', Colors.orange),
  Divider(height: 24, thickness: 1, color: colorScheme.outline),
] else ...[
  Divider(height: 24, thickness: 1, color: colorScheme.outline), // Keep divider even if expenses zero
],                    Divider(height: 24, thickness: 1, color: colorScheme.outline),
                    
                    // Net Profit
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isProfit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isProfit ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isProfit ? Icons.trending_up : Icons.trending_down,
                              color: isProfit ? Colors.green : Colors.red,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isProfit ? 'Net Profit' : 'Net Loss',
                                  style: TextStyle(
                                    color: isProfit ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  report.formattedProfit,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: isProfit ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isProfit ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
                            ),
                            child: Text(
                              '${report.profitMargin.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isProfit ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPLRow(String label, String value, Color color, {bool isBold = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // Inventory Report


Widget _buildInventoryReport() {
  if (_inventoryReports.isEmpty) {
    return _buildEmptyState(
      icon: Icons.inventory,
      title: 'No Inventory Data',
      message: 'No inventory items found',
      color: Colors.purple,
    );
  }

  // ✅ APPLY FILTER HERE
  List<InventoryReport> filteredReports;

  switch (_inventoryFilter) {
    case "low":
      filteredReports = _inventoryReports
          .where((r) => r.status == 'low-stock')
          .toList();
      break;

    case "out":
      filteredReports = _inventoryReports
          .where((r) => r.status == 'out-of-stock')
          .toList();
      break;

    default:
      filteredReports = _inventoryReports;
  }

  final totalValue =
      filteredReports.fold(0.0, (sum, r) => sum + r.totalValue);

  final lowStock =
      _inventoryReports.where((r) => r.status == 'low-stock').length;

  final outOfStock =
      _inventoryReports.where((r) => r.status == 'out-of-stock').length;

  return Column(
    children: [
      // ✅ STATS
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Value',
                '₹${NumberFormat('#,##0.00').format(totalValue)}',
                Icons.attach_money,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Items',
                '${filteredReports.length}',
                Icons.inventory,
                Colors.green,
                isCount: true,
              ),
            ),
          ],
        ),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Low Stock',
                '$lowStock',
                Icons.warning,
                Colors.orange,
                isCount: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Out of Stock',
                '$outOfStock',
                Icons.error,
                Colors.red,
                isCount: true,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 10),

      // ✅ FILTER DROPDOWN (ADD THIS)
     Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        "Filter: ${_getFilterLabel()}",
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),

      ElevatedButton.icon(
        onPressed: () async {
          final selected = await _showExportFilterDialog();

          if (selected != null) {
            setState(() {
              _inventoryFilter = selected; // ✅ UPDATE FILTER
            });
          }
        },
        icon: const Icon(Icons.filter_list),
        label: const Text("Change"),
      ),
    ],
  ),
),

      const SizedBox(height: 10),

      // ✅ LIST OF ITEMS (IMPORTANT)
      ...filteredReports.map((report) {
        return _buildInventoryCard(report); // your existing card UI
      }).toList(),

      const SizedBox(height: 16),
    ],
  );
}
  Widget _buildInventoryCard(InventoryReport report) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    
    switch (report.status) {
      case 'in-stock':
        statusColor = Colors.green;
        statusText = 'In Stock';
        break;
      case 'low-stock':
        statusColor = Colors.orange;
        statusText = 'Low Stock';
        break;
      case 'out-of-stock':
        statusColor = Colors.red;
        statusText = 'Out of Stock';
        break;
      default:
        statusColor = Colors.grey;
        statusText = report.status;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2, color: statusColor, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.sku,
                  style: TextStyle(
                    fontSize: 13, 
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11, 
                          color: statusColor, 
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${report.quantity} ${report.unit}',
                      style: TextStyle(
                        fontSize: 13, 
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                report.formattedValue,
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '@ ₹${report.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12, 
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Customer Report
  Widget _buildCustomerReport() {
    if (_customerReports.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people,
        title: 'No Customer Data',
        message: 'No customer transactions found',
        color: Colors.teal,
      );
    }

    final totalRevenue = _customerReports.fold(0.0, (sum, r) => sum + r.totalSpent);
    final avgPurchase = totalRevenue / _customerReports.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Customers',
                  '${_customerReports.length}',
                  Icons.people,
                  Colors.teal,
                  isCount: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Revenue',
                  '₹${NumberFormat('#,##0.00').format(totalRevenue)}',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildStatCard(
            'Avg Purchase',
            '₹${NumberFormat('#,##0.00').format(avgPurchase)}',
            Icons.shopping_cart,
            Colors.purple,
          ),
        ),
        ..._customerReports.map((report) => _buildCustomerCard(report)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCustomerCard(CustomerReport report) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.teal.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                report.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.name, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.mobile, 
                  style: TextStyle(
                    fontSize: 13, 
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${report.totalPurchases} purchases',
                    style: TextStyle(
                      fontSize: 11, 
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                report.formattedTotalSpent,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, 
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                report.formattedOutstanding,
                style: TextStyle(
                  fontSize: 13,
                  color: report.outstandingBalance > 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Supplier Report
  Widget _buildSupplierReport() {
    if (_supplierReports.isEmpty) {
      return _buildEmptyState(
        icon: Icons.group,
        title: 'No Supplier Data',
        message: 'No supplier transactions found',
        color: Colors.indigo,
      );
    }

    final totalPurchases = _supplierReports.fold(0.0, (sum, r) => sum + r.totalPurchases);
    final avgOrder = totalPurchases / _supplierReports.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Suppliers',
                  '${_supplierReports.length}',
                  Icons.group,
                  Colors.indigo,
                  isCount: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Purchases',
                  '₹${NumberFormat('#,##0.00').format(totalPurchases)}',
                  Icons.shopping_cart,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildStatCard(
            'Avg Order',
            '₹${NumberFormat('#,##0.00').format(avgOrder)}',
            Icons.trending_up,
            Colors.purple,
          ),
        ),
        ..._supplierReports.map((report) => _buildSupplierCard(report)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSupplierCard(SupplierReport report) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                report.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.name, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.phone, 
                  style: TextStyle(
                    fontSize: 13, 
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${report.totalOrders} orders',
                        style: TextStyle(
                          fontSize: 11, 
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      report.formattedLastOrder,
                      style: TextStyle(
                        fontSize: 11, 
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                report.formattedPurchases,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, 
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                report.formattedPending,
                style: TextStyle(
                  fontSize: 13,
                  color: report.pendingPayment > 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper Methods
  List<T> _filterAndSortReports<T>(List<T> reports) {
    var filtered = reports;
    
    if (_searchQuery.isNotEmpty) {
      if (T == SalesReport) {
        filtered = (reports as List<SalesReport>)
            .where((r) => 
                r.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                r.customerName.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList() as List<T>;
      } else if (T == PurchaseReport) {
        filtered = (reports as List<PurchaseReport>)
            .where((r) => 
                r.invoiceNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                r.supplierName.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList() as List<T>;
      }
    }
    
    if (_paymentStatusFilter != 'all') {
      if (T == SalesReport) {
        filtered = (filtered as List<SalesReport>)
            .where((r) => r.paymentStatus == _paymentStatusFilter)
            .toList() as List<T>;
      } else if (T == PurchaseReport) {
        filtered = (filtered as List<PurchaseReport>)
            .where((r) => r.paymentStatus == _paymentStatusFilter)
            .toList() as List<T>;
      }
    }
    
    if (T == SalesReport) {
      final list = filtered as List<SalesReport>;
      switch (_sortBy) {
        case 'date_desc': list.sort((a, b) => b.date.compareTo(a.date)); break;
        case 'date_asc': list.sort((a, b) => a.date.compareTo(b.date)); break;
        case 'amount_desc': list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount)); break;
        case 'amount_asc': list.sort((a, b) => a.totalAmount.compareTo(b.totalAmount)); break;
      }
      filtered = list as List<T>;
    } else if (T == PurchaseReport) {
      final list = filtered as List<PurchaseReport>;
      switch (_sortBy) {
        case 'date_desc': list.sort((a, b) => b.date.compareTo(a.date)); break;
        case 'date_asc': list.sort((a, b) => a.date.compareTo(b.date)); break;
        case 'amount_desc': list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount)); break;
        case 'amount_asc': list.sort((a, b) => a.totalAmount.compareTo(b.totalAmount)); break;
      }
      filtered = list as List<T>;
    }
    
    return filtered;
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _paymentStatusFilter == value;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (selected) => setState(() => _paymentStatusFilter = value),
        backgroundColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
        selectedColor: color.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? color : colorScheme.onSurface.withOpacity(0.7),
        ),
        checkmarkColor: color,
        side: isSelected 
            ? BorderSide(color: color)
            : BorderSide(color: colorScheme.outline),
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _sortBy == value;
    
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) => setState(() => _sortBy = value),
      backgroundColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
      selectedColor: colorScheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7),
      ),
      side: isSelected 
          ? BorderSide(color: colorScheme.primary)
          : BorderSide(color: colorScheme.outline),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message, required Color color}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 60, color: color.withOpacity(0.5)),
            ),
            const SizedBox(height: 20),
            Text(
              title, 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message, 
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
              ), 
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    Color bgColor;
    Color textColor;
    String label;
    
    switch (status) {
      case 'paid':
        bgColor = Colors.green;
        textColor = Colors.white;
        label = 'Paid';
        break;
      case 'partial':
        bgColor = Colors.orange;
        textColor = Colors.white;
        label = 'Partial';
        break;
      case 'due':
        bgColor = Colors.red;
        textColor = Colors.white;
        label = 'Due';
        break;
      default:
        bgColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurface;
        label = status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label, 
        style: TextStyle(
          color: textColor, 
          fontSize: 11, 
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildNotLoggedInState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.error.withOpacity(0.1), 
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_off, 
                size: 60, 
                color: colorScheme.error.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Not Logged In', 
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please login to view reports', 
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary, 
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }

  void _selectPeriod(String period) {
    setState(() {
      _selectedPeriod = period;
      final now = DateTime.now();
      
      switch (period) {
        case 'Today':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = now;
          break;
        case 'This Week':
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = now;
          break;
        case 'This Month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
        case 'Last Month':
          final lastMonth = DateTime(now.year, now.month - 1, 1);
          _startDate = lastMonth;
          _endDate = DateTime(lastMonth.year, lastMonth.month + 1, 0);
          break;
        case 'Custom':
          _selectCustomDateRange();
          return;
      }
    });
    _loadReports();
  }

  Future<void> _selectCustomDateRange() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: colorScheme.copyWith(
              primary: colorScheme.primary,
              onPrimary: Colors.white,
              surface: colorScheme.surface,
              onSurface: colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedPeriod = 'Custom';
      });
      _loadReports();
    }
  }

  Future<void> _showExportDialog() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Export Report',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Select format to export',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // PDF Option
              _buildExportOption(
                icon: Icons.picture_as_pdf,
                title: 'PDF Document',
                subtitle: 'Best for printing & sharing',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _handleExport('pdf');
                },
              ),
              
              const SizedBox(height: 16),
              
              // Excel Option
              _buildExportOption(
                icon: Icons.table_chart,
                title: 'Excel Spreadsheet',
                subtitle: 'Best for data analysis',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _handleExport('excel');
                },
              ),
              
              const SizedBox(height: 16),
              
              // Both Formats
              _buildExportOption(
                icon: Icons.file_copy,
                title: 'Both Formats',
                subtitle: 'Export as PDF & Excel',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _handleExport('both');
                },
              ),
              
              const SizedBox(height: 24),
              
              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: colorScheme.outline),
                    foregroundColor: colorScheme.onSurface,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      borderRadius: BorderRadius.circular(12),
      color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey[50],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurface.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

Future<void> _handleExport(String format) async {
  if (_userMobile == null) {
    _showError('Please login to export reports');
    return;
  }

  setState(() => _isExporting = true);

  try {
    // IMPORTANT: Fetch the user data from Firestore
    print('📱 Fetching user data for: $_userMobile');
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userMobile!)
        .get();
    
    Map<String, dynamic>? userData;
    if (userDoc.exists) {
      userData = userDoc.data() as Map<String, dynamic>;
      print('✅ User data fetched:');
      print('  - name: ${userData['name']}');
      print('  - businessName: ${userData['businessName']}');
      print('  - location: ${userData['location']}');
    } else {
      print('⚠️ No user document found for $_userMobile');
    }

    final reportType = _getCurrentReportType();
    final reportData = await _getCurrentReportData();

    if (reportData.isEmpty) {
      _showError('No data available to export');
      return;
    }

    if (format == 'pdf' || format == 'both') {
      final result = await _exportService.exportToPdf(
        reportType: reportType,
        userMobile: _userMobile!,
        startDate: _startDate,
        endDate: _endDate,
        data: reportData,
        title: _getReportTitle(),
        userData: userData, // THIS IS CRITICAL - passing user data
      );
      
      if (!kIsWeb) {
        // For mobile, we need to open the file
        // The exportToPdf method already handles this internally
      }
      _showSuccess('PDF exported successfully!');
    }

    if (format == 'excel' || format == 'both') {
      final result = await _exportService.exportToExcel(
        reportType: reportType,
        userMobile: _userMobile!,
        startDate: _startDate,
        endDate: _endDate,
        data: reportData,
      );
      
      if (!kIsWeb) {
        // The exportToExcel method already handles opening the file
      }
      _showSuccess('Excel exported successfully!');
    }
  } catch (e) {
    print('❌ Export error: $e');
    _showError('Export failed: ${e.toString()}');
  } finally {
    setState(() => _isExporting = false);
  }
}
  Future<List<Map<String, dynamic>>> _getCurrentReportData() async {
    switch (_selectedTab) {
      case 0: // Sales
        return _salesReports.map((report) => report.toMap()).toList();
      case 1: // Purchase
        return _purchaseReports.map((report) => report.toMap()).toList();
      case 2: // Profit & Loss
        final plReport = await _getProfitLossData();
        return [plReport.toMap()];
      case 3: // Inventory

  List<InventoryReport> filteredReports;

  switch (_inventoryFilter) {
    case "low":
      filteredReports = _inventoryReports
          .where((r) => r.status == 'low-stock')
          .toList();
      break;

    case "out":
      filteredReports = _inventoryReports
          .where((r) => r.status == 'out-of-stock')
          .toList();
      break;

    default:
      filteredReports = _inventoryReports;
  }

  return filteredReports.map((report) => report.toMap()).toList();
      case 4: // Customer
        return _customerReports.map((report) => report.toMap()).toList();
      case 5: // Supplier
        return _supplierReports.map((report) => report.toMap()).toList();
      default:
        return [];
    }
  }

Future<String?> _showExportFilterDialog() async {
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Select Export Type"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text("All Items"),
              onTap: () => Navigator.pop(context, "all"),
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text("Low Stock Only"),
              onTap: () => Navigator.pop(context, "low"),
            ),
            ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: const Text("Out of Stock"),
              onTap: () => Navigator.pop(context, "out"),
            ),
          ],
        ),
      );
    },
  );
}
  Future<ProfitLossReport> _getProfitLossData() async {
    return await _reportService.getProfitLossReport(
      userMobile: _userMobile!,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  String _getReportTitle() {
    final titles = [
      'Sales',
      'Purchase',
      'Profit & Loss',
      'Inventory',
      'Customer',
      'Supplier',
    ];
    return titles[_selectedTab];
  }

  String _getCurrentReportType() {
    switch (_selectedTab) {
      case 0: return 'sales';
      case 1: return 'purchase';
      case 2: return 'profit-loss';
      case 3: return 'inventory';
      case 4: return 'customer';
      case 5: return 'supplier';
      default: return 'sales';
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _refreshReports() {
    _loadReports();
  }

  // Detail view methods
  void _showSaleDetails(SalesReport report) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _buildSaleDetailsSheet(report),
      ),
    );
  }

  Widget _buildSaleDetailsSheet(SalesReport report) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shopping_cart, color: Colors.green.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.invoiceNumber,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(report.paymentStatus),
              ],
            ),
          ),
          
          Divider(height: 1, color: colorScheme.outline),
          
          // Customer Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.person, size: 16, color: colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.customerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (report.customerMobile.isNotEmpty)
                        Text(
                          report.customerMobile,
                          style: TextStyle(
                            fontSize: 12, 
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: colorScheme.outline),
          
          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ...report.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (item.category != null)
                                Text(
                                  item.category!,
                                  style: TextStyle(
                                    fontSize: 11, 
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${item.quantity} × ₹${item.price}',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '₹${item.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          
          Divider(height: 1, color: colorScheme.outline),
          
          // Totals
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal:', style: TextStyle(color: colorScheme.onSurface)),
                    Text(
                      '₹${report.subtotal.toStringAsFixed(2)}',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ],
                ),
                if (report.gstAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('GST:', style: TextStyle(color: colorScheme.onSurface)),
                      Text(
                        '₹${report.gstAmount.toStringAsFixed(2)}',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                ],
                Divider(height: 16, color: colorScheme.outline),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '₹${report.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                if (report.amountDue > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount Paid:',
                        style: TextStyle(color: colorScheme.secondary),
                      ),
                      Text(
                        '₹${report.amountPaid.toStringAsFixed(2)}',
                        style: TextStyle(color: colorScheme.secondary),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount Due:',
                        style: TextStyle(color: colorScheme.error),
                      ),
                      Text(
                        '₹${report.amountDue.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: colorScheme.error, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDetails(PurchaseReport report) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _buildPurchaseDetailsSheet(report),
      ),
    );
  }

  Widget _buildPurchaseDetailsSheet(PurchaseReport report) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.inventory, color: Colors.orange.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.invoiceNumber,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(report.paymentStatus),
              ],
            ),
          ),
          
          Divider(height: 1, color: colorScheme.outline),
          
          // Supplier Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.business, size: 16, color: colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.supplierName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (report.supplierMobile.isNotEmpty)
                        Text(
                          report.supplierMobile,
                          style: TextStyle(
                            fontSize: 12, 
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: colorScheme.outline),
          
          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ...report.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (item.category != null)
                                Text(
                                  item.category!,
                                  style: TextStyle(
                                    fontSize: 11, 
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${item.quantity} × ₹${item.price}',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '₹${item.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          
          Divider(height: 1, color: colorScheme.outline),
          
          // Totals
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal:', style: TextStyle(color: colorScheme.onSurface)),
                    Text(
                      '₹${report.subtotal.toStringAsFixed(2)}',
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ],
                ),
                if (report.gstAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('GST:', style: TextStyle(color: colorScheme.onSurface)),
                      Text(
                        '₹${report.gstAmount.toStringAsFixed(2)}',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                ],
                Divider(height: 16, color: colorScheme.outline),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '₹${report.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                if (report.amountDue > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount Paid:',
                        style: TextStyle(color: colorScheme.secondary),
                      ),
                      Text(
                        '₹${report.amountPaid.toStringAsFixed(2)}',
                        style: TextStyle(color: colorScheme.secondary),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount Due:',
                        style: TextStyle(color: colorScheme.error),
                      ),
                      Text(
                        '₹${report.amountDue.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: colorScheme.error, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}