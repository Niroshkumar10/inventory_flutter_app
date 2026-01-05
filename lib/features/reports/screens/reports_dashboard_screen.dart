// lib/features/reports/screens/reports_dashboard_screen.dart
import 'package:flutter/foundation.dart'; // Add this import
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/report_service.dart';
import '../models/report_model.dart';
import '../../session/session_service_new.dart';
import '../services/export_service.dart';

class ReportsDashboardScreen extends StatefulWidget {
  const ReportsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  final ReportService _reportService = ReportService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ExportService _exportService = ExportService();
  
  final List<String> _periods = ['Today', 'This Week', 'This Month', 'Last Month', 'Custom'];
  String _selectedPeriod = 'This Month';
  int _selectedTab = 0;
  
  List<ReportSummary> _summaries = [];
  List<SalesReport> _salesReports = [];
  List<PurchaseReport> _purchaseReports = [];
  List<InventoryReport> _inventoryReports = [];
  List<CustomerReport> _customerReports = [];
  List<SupplierReport> _supplierReports = [];
  
  bool _isLoading = true;
  bool _isExporting = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  DateTimeRange? _selectedDateRange;

  // Dynamic user mobile - will be loaded from auth/storage
  String? _userMobile;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserAndReports();
  }

  Future<void> _loadCurrentUserAndReports() async {
    try {
      // ✅ USE SessionServiceNew
      _userMobile = await SessionServiceNew.getUserId();
      
      if (_userMobile == null || _userMobile!.isEmpty) {
        print('❌ No user mobile found via SessionService');
        _showError('Please login to view reports');
        setState(() => _isLoading = false);
        return;
      }
      
      print('👤 Reports using mobile from SessionService: $_userMobile');
      await _loadReports();
      
    } catch (e) {
      print('❌ Error loading user via SessionService: $e');
      setState(() => _isLoading = false);
      _showError('Failed to load user: $e');
    }
  }

  Future<void> _loadReports() async {
    if (_userMobile == null || _userMobile!.isEmpty) {
      print('❌ Cannot load reports: no user mobile available');
      _showError('User information not available');
      setState(() => _isLoading = false);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      print('=== LOADING REPORTS FOR USER: $_userMobile ===');
      print('Date range: $_startDate to $_endDate');

      // Load all reports in parallel for better performance
      final futures = await Future.wait([
        _reportService.getDashboardSummary(
          userMobile: _userMobile!,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _reportService.getSalesReports(
          userMobile: _userMobile!,
          startDate: _startDate,
          endDate: _endDate,
        ),
        _reportService.getInventoryReports(userMobile: _userMobile!),
        _reportService.getPurchaseReports(
          userMobile: _userMobile!,
          startDate: _startDate,
          endDate: _endDate,
        ),
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
        _summaries = futures[0] as List<ReportSummary>;
        _salesReports = futures[1] as List<SalesReport>;
        _inventoryReports = futures[2] as List<InventoryReport>;
        _purchaseReports = futures[3] as List<PurchaseReport>;
        _customerReports = futures[4] as List<CustomerReport>;
        _supplierReports = futures[5] as List<SupplierReport>;
        _isLoading = false;
      });
      
      print('✅ Reports loaded successfully for user: $_userMobile');
      
    } catch (e, stackTrace) {
      print('❌ ERROR loading reports: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      _showError('Failed to load reports: ${e.toString()}');
    }
  }

  // ==================== EXPORT METHODS ====================
  Future<void> _handleExport(String format) async {
    if (_userMobile == null) {
      _showError('Please login to export reports');
      return;
    }

    setState(() => _isExporting = true);

    try {
      final reportType = _getCurrentReportType();
      final reportData = await _getCurrentReportData();

      if (reportData == null || reportData.isEmpty) {
        _showError('No data available to export');
        return;
      }

      if (format == 'pdf' || format == 'both') {
        final filePath = await _exportService.exportToPdf(
          reportType: reportType,
          userMobile: _userMobile!,
          startDate: _startDate,
          endDate: _endDate,
          data: reportData,
          title: _getReportTitle(),
        );
        
        // On web, files are downloaded directly, so no need to open
        if (!kIsWeb) {
          await _exportService.openFile(filePath);
        }
        _showSuccess('PDF exported successfully!');
      }

      if (format == 'excel' || format == 'both') {
        final filePath = await _exportService.exportToExcel(
          reportType: reportType,
          userMobile: _userMobile!,
          startDate: _startDate,
          endDate: _endDate,
          data: reportData,
        );
        
        // On web, files are downloaded directly, so no need to open
        if (!kIsWeb) {
          await _exportService.openFile(filePath);
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
        return _inventoryReports.map((report) => report.toMap()).toList();
      case 4: // Customer
        return _customerReports.map((report) => report.toMap()).toList();
      case 5: // Supplier
        return _supplierReports.map((report) => report.toMap()).toList();
      default:
        return [];
    }
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

  void _showSuccess(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================== UI BUILD METHODS ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userMobile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'User Not Logged In',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please login to view reports',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Go to Login'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Report Tabs - moved to top with better spacing
                    Container(
                      color: Colors.grey[50],
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          // Export buttons
                          if (!_isExporting)
                            IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () => _showExportDialog(),
                              tooltip: 'Export Report',
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          const SizedBox(width: 8),
                          
                          // Date range display
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Report Period',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Period selector dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedPeriod,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                style: Theme.of(context).textTheme.bodyMedium,
                                items: _periods.map((period) {
                                  return DropdownMenuItem(
                                    value: period,
                                    child: Text(period),
                                  );
                                }).toList(),
                                onChanged: (value) => _selectPeriod(value!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Tabs navigation
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(6, (index) {
                            final titles = [
                              'Sales',
                              'Purchase',
                              'Profit & Loss',
                              'Inventory',
                              'Customer',
                              'Supplier',
                            ];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(titles[index]),
                                selected: _selectedTab == index,
                                onSelected: (_) => setState(() => _selectedTab = index),
                                selectedColor: Theme.of(context).primaryColor,
                                labelStyle: TextStyle(
                                  color: _selectedTab == index ? Colors.white : null,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Report Content
                    Expanded(
                      child: _buildReportContent(),
                    ),
                  ],
                ),
    );
  }
Future<void> _showExportDialog() async {
  return showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Select format to export',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Format Options
            _buildExportOption(
              context,
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
            
            _buildExportOption(
              context,
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
            
            _buildExportOption(
              context,
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

Widget _buildExportOption(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
}) {
  return Material(
    borderRadius: BorderRadius.circular(12),
    color: Colors.grey[50],
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    ),
  );
}
  // ==================== HELPER METHODS ====================
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
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange ?? DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedPeriod = 'Custom';
      });
      _loadReports();
    }
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

  void _refreshReports() {
    _loadReports();
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== REPORT CONTENT ====================
  Widget _buildReportContent() {
    if (_userMobile == null) {
      return const Center(
        child: Text('Please login to view reports'),
      );
    }

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

  Widget _buildSalesReport() {
    if (_salesReports.isEmpty) {
      return const Center(
        child: Text('No sales data available'),
      );
    }

    final totalSales = _salesReports.fold(0.0, (sum, report) => sum + report.totalAmount);
    final totalCollected = _salesReports.fold(0.0, (sum, report) => sum + report.amountPaid);
    final totalDue = _salesReports.fold(0.0, (sum, report) => sum + report.amountDue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary at top
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompactSummaryItem('Total Sales', totalSales, Colors.blue),
                  _buildCompactSummaryItem('Collected', totalCollected, Colors.green),
                  _buildCompactSummaryItem('Due', totalDue, Colors.orange),
                  _buildCompactSummaryItem('Invoices', _salesReports.length.toDouble(), Colors.purple),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Data table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales Report',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Invoice')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Amount', textAlign: TextAlign.right)),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: _salesReports.take(10).map((report) {
                        return DataRow(cells: [
                          DataCell(SizedBox(
                            width: 100,
                            child: Text(
                              report.invoiceNumber,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: 120,
                            child: Text(
                              report.customerName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(Text(report.formattedDate)),
                          DataCell(
                            Text(
                              report.formattedTotal,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(_buildStatusBadge(report.paymentStatus)),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseReport() {
    if (_purchaseReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Purchase Data',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'No purchase transactions found for this period',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final totalPurchases = _purchaseReports.fold(0.0, (sum, report) => sum + report.totalAmount);
    final totalPaid = _purchaseReports.fold(0.0, (sum, report) => sum + report.amountPaid);
    final totalDue = _purchaseReports.fold(0.0, (sum, report) => sum + report.amountDue);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary at top
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompactSummaryItem('Total Purchases', totalPurchases, Colors.blue),
                  _buildCompactSummaryItem('Paid', totalPaid, Colors.green),
                  _buildCompactSummaryItem('Due', totalDue, Colors.orange),
                  _buildCompactSummaryItem('Invoices', _purchaseReports.length.toDouble(), Colors.purple),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Data table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase Report',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Invoice')),
                        DataColumn(label: Text('Supplier')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Amount', textAlign: TextAlign.right)),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: _purchaseReports.take(10).map((report) {
                        return DataRow(cells: [
                          DataCell(SizedBox(
                            width: 100,
                            child: Text(
                              report.invoiceNumber,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(SizedBox(
                            width: 120,
                            child: Text(
                              report.supplierName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(Text(report.formattedDate)),
                          DataCell(
                            Text(
                              report.formattedTotal,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(_buildStatusBadge(report.paymentStatus)),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitLossReport() {
    return FutureBuilder<ProfitLossReport>(
      future: _reportService.getProfitLossReport(
        userMobile: _userMobile!,
        startDate: _startDate,
        endDate: _endDate,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData) {
          return const Center(child: Text('No profit/loss data available'));
        }
        
        final report = snapshot.data!;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Profit & Loss Statement',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    report.formattedPeriod,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  _buildPLRow('Total Revenue', report.formattedRevenue, Colors.green),
                  _buildPLRow('Cost of Goods Sold', '₹${NumberFormat('#,##0.00').format(report.totalCost)}', Colors.red),
                  const Divider(),
                  _buildPLRow('Gross Profit', '₹${NumberFormat('#,##0.00').format(report.grossProfit)}', Colors.blue),
                  _buildPLRow('Expenses', '₹${NumberFormat('#,##0.00').format(report.expenses)}', Colors.orange),
                  const Divider(thickness: 2),
                  _buildPLRow('Net Profit', report.formattedProfit, Colors.green, isBold: true),
                  _buildPLRow('Profit Margin', report.formattedMargin, Colors.green),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPLRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            value,
            style: (isBold
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.bodyLarge)?.copyWith(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryReport() {
    if (_inventoryReports.isEmpty) {
      return const Center(
        child: Text('No inventory data available'),
      );
    }

    final totalValue = _inventoryReports.fold(0.0, (sum, report) => sum + report.totalValue);
    final totalItems = _inventoryReports.length;
    final lowStockCount = _inventoryReports.where((r) => r.status == 'low-stock').length;
    final outOfStockCount = _inventoryReports.where((r) => r.status == 'out-of-stock').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary at top
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompactSummaryItem('Total Value', totalValue, Colors.blue),
                  _buildCompactSummaryItem('Items', totalItems.toDouble(), Colors.green),
                  _buildCompactSummaryItem('Low Stock', lowStockCount.toDouble(), Colors.orange),
                  _buildCompactSummaryItem('Out of Stock', outOfStockCount.toDouble(), Colors.red),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Data table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory Report',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Product')),
                        DataColumn(label: Text('SKU')),
                        DataColumn(label: Text('Stock')),
                        DataColumn(label: Text('Value', textAlign: TextAlign.right)),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: _inventoryReports.take(10).map((report) {
                        return DataRow(cells: [
                          DataCell(SizedBox(
                            width: 120,
                            child: Text(
                              report.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(Text(report.sku)),
                          DataCell(Text('${report.quantity} ${report.unit}')),
                          DataCell(
                            Text(
                              report.formattedValue,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(_buildInventoryStatusBadge(report.status)),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerReport() {
    if (_customerReports.isEmpty) {
      return const Center(
        child: Text('No customer data available'),
      );
    }

    final totalCustomers = _customerReports.length;
    final totalRevenue = _customerReports.fold(0.0, (sum, report) => sum + report.totalSpent);
    final totalOutstanding = _customerReports.fold(0.0, (sum, report) => sum + report.outstandingBalance);
    final avgPurchaseValue = totalCustomers > 0 ? totalRevenue / totalCustomers : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary at top
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompactSummaryItem('Customers', totalCustomers.toDouble(), Colors.blue),
                  _buildCompactSummaryItem('Revenue', totalRevenue, Colors.green),
                  _buildCompactSummaryItem('Outstanding', totalOutstanding, Colors.orange),
                  _buildCompactSummaryItem('Avg Purchase', avgPurchaseValue.toDouble(), Colors.purple),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Data table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Report',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Mobile')),
                        DataColumn(label: Text('Purchases')),
                        DataColumn(label: Text('Total Spent', textAlign: TextAlign.right)),
                        DataColumn(label: Text('Outstanding', textAlign: TextAlign.right)),
                      ],
                      rows: _customerReports.take(10).map((report) {
                        return DataRow(cells: [
                          DataCell(SizedBox(
                            width: 120,
                            child: Text(
                              report.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(Text(report.mobile)),
                          DataCell(Text('${report.totalPurchases}')),
                          DataCell(
                            Text(
                              report.formattedTotalSpent,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(
                            Text(
                              report.formattedOutstanding,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: report.outstandingBalance > 0 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierReport() {
    if (_supplierReports.isEmpty) {
      return const Center(
        child: Text('No supplier data available'),
      );
    }

    final totalSuppliers = _supplierReports.length;
    final totalPurchases = _supplierReports.fold(0.0, (sum, report) => sum + report.totalPurchases);
    final totalPending = _supplierReports.fold(0.0, (sum, report) => sum + report.pendingPayment);
    final avgOrderValue = totalSuppliers > 0 ? totalPurchases / totalSuppliers : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary at top
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompactSummaryItem('Suppliers', totalSuppliers.toDouble(), Colors.blue),
                  _buildCompactSummaryItem('Purchases', totalPurchases, Colors.green),
                  _buildCompactSummaryItem('Pending', totalPending, Colors.orange),
                  _buildCompactSummaryItem('Avg Order', avgOrderValue.toDouble(), Colors.purple),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Data table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supplier Report',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Supplier')),
                        DataColumn(label: Text('Contact')),
                        DataColumn(label: Text('Orders')),
                        DataColumn(label: Text('Total Purchases', textAlign: TextAlign.right)),
                        DataColumn(label: Text('Pending', textAlign: TextAlign.right)),
                      ],
                      rows: _supplierReports.take(10).map((report) {
                        return DataRow(cells: [
                          DataCell(SizedBox(
                            width: 120,
                            child: Text(
                              report.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          DataCell(Text(report.phone)),
                          DataCell(Text('${report.totalOrders}')),
                          DataCell(
                            Text(
                              report.formattedPurchases,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(
                            Text(
                              report.formattedPending,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: report.pendingPayment > 0 ? Colors.orange : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER WIDGETS ====================
  Widget _buildCompactSummaryItem(String title, double value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value < 1000
              ? '₹${NumberFormat('#,##0').format(value)}'
              : '₹${NumberFormat('#,##0.0').format(value / 1000)}K',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;
    
    switch (status) {
      case 'paid':
        bgColor = const Color(0xFFdcfce7);
        textColor = const Color(0xFF166534);
        label = 'Paid';
        break;
      case 'partial':
        bgColor = const Color(0xFFfef3c7);
        textColor = const Color(0xFF92400e);
        label = 'Partial';
        break;
      case 'due':
        bgColor = const Color(0xFFfee2e2);
        textColor = const Color(0xFF991b1b);
        label = 'Due';
        break;
      default:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        label = status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInventoryStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;
    
    switch (status) {
      case 'in-stock':
        bgColor = const Color(0xFFdbeafe);
        textColor = const Color(0xFF1e40af);
        label = 'In Stock';
        break;
      case 'low-stock':
        bgColor = const Color(0xFFfef3c7);
        textColor = const Color(0xFF92400e);
        label = 'Low Stock';
        break;
      case 'out-of-stock':
        bgColor = const Color(0xFFfee2e2);
        textColor = const Color(0xFF991b1b);
        label = 'Out of Stock';
        break;
      default:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        label = status;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}