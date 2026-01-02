// lib/features/dashboard/home_tab.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../features/bill/models/bill_model.dart';
import '../../features/party/services/customer_service.dart';
import '../../features/party/services/supplier_service.dart';
import '../../features/inventory/services/inventory_repo_service.dart';
import '../../features/bill/services/bill_service.dart';

import '../party/screens/customer_list_screen.dart';
import '../party/screens/supplier_list_screen.dart';
import '../ledger/screens/ledger_home_screen.dart';
import '../inventory/screens/inventory_dashboard.dart';

// ============ HomeTab (StatefulWidget) ============
class HomeTab extends StatefulWidget {
  final String userMobile;

  const HomeTab({
    Key? key,
    required this.userMobile,
  }) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final CustomerService _customerService;
  late final SupplierService _supplierService;
  late Widget _currentScreen;
  bool _isOnDashboard = true;
  String _currentTitle = 'Dashboard';
  
  // ADD THIS: Declare inventoryService
  late InventoryService inventoryService;

  @override
  void initState() {
    super.initState();
    // ADD THIS: Get InventoryService from Provider
    inventoryService = Provider.of<InventoryService>(context, listen: false);
    _customerService = CustomerService(widget.userMobile);
    _supplierService = SupplierService(widget.userMobile);
    _currentScreen = _buildDashboardContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentTitle), // Fixed: Use Text widget
        leading: _isOnDashboard
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBackToDashboard,
              ),
      ),
      body: _currentScreen,
    );
  }

  // Method to navigate to different screens
  void _navigateTo(Widget screen, String screenTitle) {
    setState(() {
      _currentScreen = screen;
      _isOnDashboard = false;
      _currentTitle = screenTitle;
    });
  }

  // Method to go back to dashboard
  void _goBackToDashboard() {
    setState(() {
      _currentScreen = _buildDashboardContent();
      _isOnDashboard = true;
      _currentTitle = 'Dashboard';
    });
  }

  // Build dashboard content
  Widget _buildDashboardContent() {
    return DashboardContent(
      userMobile: widget.userMobile,
      inventoryService: inventoryService, // ✅ Use local variable
      customerService: _customerService,
      supplierService: _supplierService,
      onNavigate: _navigateTo,
    );
  }
}

// ============ DashboardContent (Separate Widget) ============
class DashboardContent extends StatelessWidget {
  final String userMobile;
  final InventoryService inventoryService;
  final CustomerService customerService;
  final SupplierService supplierService;
  final Function(Widget, String) onNavigate;

  const DashboardContent({
    Key? key,
    required this.userMobile,
    required this.inventoryService,
    required this.customerService,
    required this.supplierService,
    required this.onNavigate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ===== SUMMARY CARDS =====
          Row(
            children: [
              _summaryStreamCard(
                title: 'Customers',
                icon: Icons.person,
                color: Theme.of(context).colorScheme.primary,
                stream: customerService.getCustomers(),
              ),
              const SizedBox(width: 12),
              _summaryStreamCard(
                title: 'Suppliers',
                icon: Icons.people,
                color: Theme.of(context).colorScheme.secondary,
                stream: supplierService.getSuppliers(),
              ),
              const SizedBox(width: 12),
              _summaryStreamCard(
                title: 'Inventory',
                icon: Icons.inventory_2,
                color: Theme.of(context).colorScheme.tertiary,
                stream: inventoryService.getInventoryItems(),
              ),
              const SizedBox(width: 12),
              _balanceCard(context),
            ],
          ),

          const SizedBox(height: 24),

          /// ===== WEEKLY SALES GRAPH =====
          const Text(
            'Weekly Overview',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<Bill>>(
            stream: Provider.of<BillService>(context, listen: false).getBills(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return _buildEmptyGraph();
              }
              
              final bills = snapshot.data!;
              final salesBills = bills.where((bill) => bill.type == 'sales').toList();
              
              if (salesBills.isEmpty) {
                return _buildEmptyGraph();
              }
              
              final spots = List.generate(7, (index) {
                final daySales = salesBills
                    .where((bill) => _isSameDay(bill.date, index))
                    .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
                
                return FlSpot(index.toDouble(), daySales);
              });
              
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                                return Text(days[value.toInt() % 7]);
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 3,
                            color: Theme.of(context).colorScheme.primary,
                            dotData: FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          /// ===== QUICK ACTIONS =====
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            children: [
              _actionCard(
                'Customers',
                Icons.person,
                CustomerListScreen(userMobile: userMobile),
              ),
              _actionCard(
                'Suppliers',
                Icons.people,
                SupplierListScreen(userMobile: userMobile),
              ),
              _actionCard(
                'Ledger',
                Icons.menu_book,
                LedgerHomeScreen(userMobile: userMobile),
              ),
              _actionCard(
                'Inventory',
                Icons.inventory_2,
                InventoryDashboard(
                  inventoryService: inventoryService,
                  userMobile: userMobile,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ===== BALANCE CARD =====
  Widget _balanceCard(BuildContext context) {
    return Expanded(
      child: StreamBuilder<List<Bill>>(
        stream: Provider.of<BillService>(context, listen: false).getBills(),
        builder: (context, billSnap) {
          // Debug information
          if (billSnap.hasData) {
            print('📊 Total Bills: ${billSnap.data!.length}');
            
            // Count sales and purchases
            final salesCount = billSnap.data!.where((b) => b.type == 'sales').length;
            final purchaseCount = billSnap.data!.where((b) => b.type == 'purchase').length;
            print('🛒 Sales Bills: $salesCount');
            print('📦 Purchase Bills: $purchaseCount');
            
            // Calculate totals
            final totalSales = billSnap.data!
                .where((b) => b.type == 'sales')
                .fold<double>(0, (sum, b) => sum + b.totalAmount);
            
            final totalPurchases = billSnap.data!
                .where((b) => b.type == 'purchase')
                .fold<double>(0, (sum, b) => sum + b.totalAmount);
            
            print('💰 Total Sales Amount: ₹$totalSales');
            print('💰 Total Purchase Amount: ₹$totalPurchases');
            print('💰 Calculated Balance: ₹${totalSales - totalPurchases}');
          }
          
          final balance = _calculateBalanceFromBills(billSnap.data);
          
          return _summaryCard(
            'Balance',
            '₹ ${balance.toStringAsFixed(2)}',
            Icons.account_balance_wallet,
            const Color.fromARGB(255, 207, 194, 126),
          );
        },
      ),
    );
  }

  /// ===== STREAM SUMMARY CARD =====
  Widget _summaryStreamCard<T>({
    required String title,
    required IconData icon,
    required Color color,
    required Stream<List<T>> stream,
  }) {
    return Expanded(
      child: StreamBuilder<List<T>>(
        stream: stream,
        builder: (context, snapshot) {
          // Show loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _summaryCard(title, '...', icon, color);
          }
          
          // Show error
          if (snapshot.hasError) {
            print('❌ $title Error: ${snapshot.error}');
            return _summaryCard(title, '0', icon, Colors.grey);
          }
          
          final count = snapshot.hasData ? snapshot.data!.length : 0;
          print('✅ $title Count: $count');
          return _summaryCard(title, '$count', icon, color);
        },
      ),
    );
  }

  /// ===== BALANCE CALCULATION =====
  double _calculateBalanceFromBills(List<Bill>? bills) {
    if (bills == null || bills.isEmpty) return 0.0;
    
    double totalSales = 0.0;
    double totalPurchases = 0.0;
    
    for (final bill in bills) {
      if (bill.type == 'sales') {
        totalSales += bill.totalAmount;
      } else if (bill.type == 'purchase') {
        totalPurchases += bill.totalAmount;
      }
    }
    
    return totalSales - totalPurchases;
  }

  /// ===== SUMMARY CARD UI =====
  Widget _summaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  /// ===== UPDATED ACTION CARD =====
  Widget _actionCard(String title, IconData icon, Widget screen) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Use onNavigate instead of Navigator.push
          onNavigate(screen, title);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Colors.blue),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  /// ===== HELPER METHODS FOR WEEKLY GRAPH =====
  bool _isSameDay(DateTime date, int dayIndex) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final targetDay = weekStart.add(Duration(days: dayIndex));
    
    return date.year == targetDay.year &&
           date.month == targetDay.month &&
           date.day == targetDay.day;
  }

  Widget _buildEmptyGraph() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 180,
          child: Center(
            child: Text('No sales data available'),
          ),
        ),
      ),
    );
  }
}