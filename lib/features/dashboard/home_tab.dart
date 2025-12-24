import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../features/billings/services/purchase_service.dart';
import '../../features/billings/services/sale_service.dart';
import '../../features/billings/models/purchase_model.dart';
import '../../features/billings/models/sale_model.dart';

import '../../features/party/services/customer_service.dart';
import '../../features/party/services/supplier_service.dart';
import '../../features/inventory/services/inventory_repo_service.dart';


import '../party/screens/customer_list_screen.dart';
import '../party/screens/supplier_list_screen.dart';
import '../ledger/screens/ledger_home_screen.dart';
import '../inventory/screens/inventory_dashboard.dart'; // NEW

import '../inventory/services/inventory_repo_service.dart'; // Add import

class HomeTab extends StatelessWidget {
    final InventoryService inventoryService; // Add this

  final String userMobile;
  
  // Declare services
  late final CustomerService _customerService;
  late final SupplierService _supplierService;
  final SalesService _saleService = SalesService();
  final PurchaseService _purchaseService = PurchaseService();

  // Constructor with initialization in body
  HomeTab({
    Key? key,
    required this.userMobile,
        required this.inventoryService, // Add this

  }) : super(key: key) {
    // Initialize services in constructor body

    _customerService = CustomerService(userMobile);
    _supplierService = SupplierService(userMobile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(
    title: const Text('Dashboard'),
  ),

      body: SingleChildScrollView(
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
                  stream: _customerService.getCustomers(),
                ),
                const SizedBox(width: 12),
                _summaryStreamCard(
                  title: 'Suppliers',
                  icon: Icons.people,
  color: Theme.of(context).colorScheme.secondary,
                  stream: _supplierService.getSuppliers(),
                ),
                const SizedBox(width: 12),
    _summaryStreamCard(
      title: 'Inventory',
      icon: Icons.inventory_2,
     color: Theme.of(context).  colorScheme.tertiary,
      stream: InventoryService(userMobile).getInventoryItems(),
    ),
    const SizedBox(width: 12),
    _balanceCard(),
              ],
            ),

            const SizedBox(height: 24),

            /// ===== WEEKLY SALES GRAPH =====
            const Text(
              'Weekly Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<Sale>>(
              stream: _saleService.getSales(),
              builder: (context, snapshot) {
                final spots = List.generate(7, (index) {
                  if (!snapshot.hasData) {
                    return FlSpot(index.toDouble(), 0);
                  }

                  final daySales = snapshot.data!
                      .where((s) => s.date.weekday % 7 == index)
                      .fold<double>(0, (sum, s) => sum + s.totalAmount);

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
                  context, 
                  'Customers', 
                  Icons.person, 
                  CustomerListScreen(userMobile: userMobile),
                ),
                _actionCard(
                  context, 
                  'Suppliers', 
                  Icons.people, 
                  SupplierListScreen(userMobile: userMobile),
                ),
                _actionCard(
                  context, 
                  'Ledger', 
                  Icons.menu_book, 
                  LedgerHomeScreen(userMobile: userMobile),
                ),
                _actionCard(
                  context, 
                  'Inventory', 
                  Icons.inventory_2, 
InventoryDashboard(
        inventoryService: inventoryService, // Pass it here
        userMobile: userMobile,
      ),                ),
                
              ],
            ),
          ],
        ),
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

  /// ===== BALANCE CARD =====
  Widget _balanceCard() {
    return Expanded(
      child: StreamBuilder<List<Sale>>(
        stream: _saleService.getSales(),
        builder: (context, saleSnap) {
          return StreamBuilder<List<Purchase>>(
            stream: _purchaseService.getPurchases(),
            builder: (context, purchaseSnap) {
              final balance =
                  _calculateBalance(saleSnap.data, purchaseSnap.data);

              return _summaryCard(
                'Balance',
                '₹ ${balance.toStringAsFixed(2)}',
                Icons.account_balance_wallet,
                Colors.green,
              );
            },
          );
        },
      ),
    );
  }


  /// ===== BALANCE CALCULATION =====
  double _calculateBalance(List<Sale>? sales, List<Purchase>? purchases) {
    final totalSales =
        sales?.fold<double>(0, (sum, s) => sum + s.totalAmount) ?? 0;
    final totalPurchases =
        purchases?.fold<double>(0, (sum, p) => sum + p.totalAmount) ?? 0;

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

  /// ===== ACTION CARD =====
  Widget _actionCard(
      BuildContext context, String title, IconData icon, Widget screen) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
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
}