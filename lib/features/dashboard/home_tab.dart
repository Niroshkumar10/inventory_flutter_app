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
import '../bill/screens/bill_home_screen.dart';
import '../bill/screens/view_bill_screen.dart';

import '../../core/providers/ai_provider.dart';
import '../../features/ai/screens/ai_chat_screen.dart';

// ============ TIME FILTER ENUM (TOP LEVEL) ============
enum TimeFilter { day, week, month, year }

// ============ HomeTab (StatefulWidget) ============
class HomeTab extends StatefulWidget {
  final String userMobile;

  const HomeTab({
    super.key,
    required this.userMobile,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final CustomerService _customerService;
  late final SupplierService _supplierService;
  late InventoryService inventoryService;
  Widget _currentScreen = Container();
  bool _isOnDashboard = true;
  String _currentTitle = 'Dashboard';
  
  final List<Map<String, dynamic>> _navigationStack = [];

  @override
  void initState() {
    super.initState();
    inventoryService = Provider.of<InventoryService>(context, listen: false);
    _customerService = CustomerService(widget.userMobile);
    _supplierService = SupplierService(widget.userMobile);
    _currentScreen = _buildDashboardContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentScreen,
      // Add AI FAB at bottom right
      floatingActionButton: Consumer<AIProvider>(
        builder: (context, aiProvider, child) {
          if (aiProvider.isAvailable) {
            return FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AiChatScreen(),
                  ),
                );
              },
              child: const Icon(Icons.chat),
              tooltip: 'AI Assistant',
              backgroundColor: Theme.of(context).primaryColor,
              elevation: 4,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _navigateTo(Widget screen, String screenTitle) {
    _navigationStack.add({
      'screen': _currentScreen,
      'title': _currentTitle,
      'isDashboard': _isOnDashboard,
    });

    setState(() {
      _currentScreen = screen;
      _isOnDashboard = false;
      _currentTitle = screenTitle;
    });
  }

  void _goBack() {
    if (_navigationStack.isNotEmpty) {
      final previousState = _navigationStack.removeLast();
      setState(() {
        _currentScreen = previousState['screen'];
        _currentTitle = previousState['title'];
        _isOnDashboard = previousState['isDashboard'];
      });
    } else {
      _goBackToDashboard();
    }
  }

  void _goBackToDashboard() {
    _navigationStack.clear();
    setState(() {
      _currentScreen = _buildDashboardContent();
      _isOnDashboard = true;
      _currentTitle = 'Dashboard';
    });
  }

  Widget _buildDashboardContent() {
    return DashboardContent(
      userMobile: widget.userMobile,
      inventoryService: inventoryService,
      customerService: _customerService,
      supplierService: _supplierService,
      onNavigate: _navigateTo,
    );
  }
}

// ============ DashboardContent (Separate Widget) ============
class DashboardContent extends StatefulWidget {
  final String userMobile;
  final InventoryService inventoryService;
  final CustomerService customerService;
  final SupplierService supplierService;
  final Function(Widget, String) onNavigate;

  const DashboardContent({
    super.key,
    required this.userMobile,
    required this.inventoryService,
    required this.customerService,
    required this.supplierService,
    required this.onNavigate,
  });

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  // Time filter state
  TimeFilter _selectedFilter = TimeFilter.week;
  final Map<TimeFilter, String> _filterTitles = {
    TimeFilter.week: 'This Week',
    TimeFilter.month: 'This Month',
    TimeFilter.year: 'This Year',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Welcome Header
          Text(
            'Welcome back!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Here\'s what\'s happening with your business today.',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 24),

          /// ===== SUMMARY CARDS =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: _summaryCardMobile(
                    title: 'Customers',
                    icon: Icons.person,
                    color: colorScheme.primary,
                    stream: widget.customerService.getCustomers(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCardMobile(
                    title: 'Suppliers',
                    icon: Icons.people,
                    color: colorScheme.secondary,
                    stream: widget.supplierService.getSuppliers(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCardMobile(
                    title: 'Inventory',
                    icon: Icons.inventory_2,
                    color: colorScheme.tertiary,
                    stream: widget.inventoryService.getInventoryItems(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _balanceCardMobile(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          /// ===== SALES GRAPH WITH FILTERS =====
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Overview',
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              _buildFilterChips(),
            ],
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<Bill>>(
            stream: Provider.of<BillService>(context, listen: false).getBills(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingGraph();
              }
              
              if (snapshot.hasError) {
                return _buildErrorGraph();
              }
              
              if (!snapshot.hasData) {
                return _buildEmptyGraph();
              }
              
              final bills = snapshot.data!;
              final salesBills = bills.where((bill) => bill.type == 'sales').toList();
              
              if (salesBills.isEmpty) {
                return _buildWelcomeGraph();
              }
              
              // Get filtered data
              final filteredData = _getFilteredData(salesBills, _selectedFilter);
              final totalAmount = filteredData.total;
              final chartData = filteredData.data;
              final maxValue = chartData.isNotEmpty 
                  ? chartData.reduce((a, b) => a > b ? a : b) 
                  : 0.0;
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Graph Header with Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _filterTitles[_selectedFilter]!,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorScheme.secondary.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Total: ₹${totalAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Bar Graph
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxValue > 0 ? maxValue * 1.2 : 100,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  return BarTooltipItem(
                                    '₹${rod.toY.toStringAsFixed(0)}',
                                    TextStyle(
                                      color: colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value == meta.min || value == meta.max) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        '₹${value.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: colorScheme.onSurface.withOpacity(0.5),
                                        ),
                                      ),
                                    );
                                  },
                                  reservedSize: 40,
                                ),
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
                                    final labels = _getBottomLabels(_selectedFilter);
                                    if (value >= 0 && value < labels.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          labels[value.toInt()],
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colorScheme.onSurface.withOpacity(0.5),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: maxValue > 0 ? maxValue / 4 : 25,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: colorScheme.onSurface.withOpacity(0.1),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(
                                color: colorScheme.onSurface.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            barGroups: List.generate(chartData.length, (index) {
                              final sales = chartData[index];
                              
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: sales,
                                    width: _getBarWidth(_selectedFilter),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(6),
                                      topRight: Radius.circular(6),
                                    ),
                                    color: colorScheme.primary,
                                    gradient: LinearGradient(
                                      colors: [
                                        colorScheme.primary,
                                        colorScheme.primary.withOpacity(0.5),
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                      
                      // Today's Sales Indicator
                      if (_selectedFilter == TimeFilter.day)
                        _buildTodayIndicator(),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          /// ===== SALES VS PURCHASE COMPARISON =====
          Text(
            'Sales vs Purchase',
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<Bill>>(
            stream: Provider.of<BillService>(context, listen: false).getBills(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyComparison();
              }
              
              final bills = snapshot.data!;
              final totalSales = bills
                  .where((bill) => bill.type == 'sales')
                  .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
              
              final totalPurchases = bills
                  .where((bill) => bill.type == 'purchase')
                  .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
              
              final total = totalSales + totalPurchases;
              final salesPercentage = total > 0 ? (totalSales / total * 100) : 0;
              final purchasePercentage = total > 0 ? (totalPurchases / total * 100) : 0;
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Progress Bar
                      Stack(
                        children: [
                          Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                flex: salesPercentage.toInt(),
                                child: Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        colorScheme.secondary,
                                        colorScheme.secondary.withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomLeft: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: purchasePercentage.toInt(),
                                child: Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        colorScheme.tertiary,
                                        colorScheme.tertiary.withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _legendItem(
                            color: colorScheme.secondary,
                            label: 'Sales',
                            value: '₹${totalSales.toStringAsFixed(0)}',
                            percentage: '${salesPercentage.toStringAsFixed(1)}%',
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: colorScheme.onSurface.withOpacity(0.2),
                          ),
                          _legendItem(
                            color: colorScheme.tertiary,
                            label: 'Purchase',
                            value: '₹${totalPurchases.toStringAsFixed(0)}',
                            percentage: '${purchasePercentage.toStringAsFixed(1)}%',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          /// ===== RECENT TRANSACTIONS =====
          Text(
            'Recent Transactions',
            style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<Bill>>(
            stream: Provider.of<BillService>(context, listen: false).getBills(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyActivity();
              }
              
              final recentBills = snapshot.data!
                  .where((bill) => bill.type == 'sales' || bill.type == 'purchase')
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));
              
              final recent = recentBills.take(5).toList();
              
              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: colorScheme.onSurface.withOpacity(0.1),
                  ),
                  itemBuilder: (context, index) {
                    final bill = recent[index];
                    final isSales = bill.type == 'sales';
                    
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isSales ? colorScheme.secondary : colorScheme.tertiary).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isSales ? Icons.shopping_cart : Icons.shopping_bag,
                          color: isSales ? colorScheme.secondary : colorScheme.tertiary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        bill.partyName ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        '${bill.invoiceNumber} • ${_formatDate(bill.date)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${bill.totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSales ? colorScheme.secondary : colorScheme.tertiary,
                            ),
                          ),
                          Text(
                            isSales ? 'Sales' : 'Purchase',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewBillScreen(
                              billId: bill.id,
                              userMobile: widget.userMobile,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 24),     
        ],
      ),
    );
  }

  // ============ HELPER WIDGETS ============

  Widget _actionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: Colors.blue),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

 Widget _buildTodayIndicator() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return StreamBuilder<List<Bill>>(
      stream: Provider.of<BillService>(context, listen: false).getBills(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        
        final todaySales = snapshot.data!
            .where((bill) => bill.type == 'sales' && _isToday(bill.date))
            .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
        
        if (todaySales == 0) return const SizedBox();
        
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.secondary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Sales',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        '₹${todaySales.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: colorScheme.secondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeGraph() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 80,
              color: colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to Your Dashboard!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first sale to see insights here.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyComparison() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 48,
                color: colorScheme.onSurface.withOpacity(0.2),
              ),
              const SizedBox(height: 12),
              Text(
                'No comparison data yet',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivity() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: colorScheme.onSurface.withOpacity(0.2),
              ),
              const SizedBox(height: 12),
              Text(
                'No recent transactions',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ MOBILE OPTIMIZED SUMMARY CARD METHODS ============
  
 Widget _summaryCardMobile({
    required String title,
    required IconData icon,
    required Color color,
    required Stream stream,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      constraints: const BoxConstraints(minWidth: 70),
      child: StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          final count = snapshot.hasData ? (snapshot.data as List).length : 0;
          
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      )
    );
  }

 Widget _balanceCardMobile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      constraints: const BoxConstraints(minWidth: 70),
      child: StreamBuilder<List<Bill>>(
        stream: Provider.of<BillService>(context, listen: false).getBills(),
        builder: (context, snapshot) {
          final balance = _calculateBalanceFromBills(snapshot.data);
          
          return Card(
            margin: EdgeInsets.zero,
            color: colorScheme.primary.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatBalance(balance),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      )
    );
  }

  Widget _buildFilterChips() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.onSurface.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _filterChip('Week', TimeFilter.week),
          _filterChip('Month', TimeFilter.month),
          _filterChip('Year', TimeFilter.year),
        ],
      ),
    );
  }

  Widget _filterChip(String label, TimeFilter filter) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedFilter == filter;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected 
                ? colorScheme.onPrimary 
                : colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatBalance(double balance) {
    if (balance >= 10000000) {
      return '₹${(balance / 10000000).toStringAsFixed(1)}Cr';
    } else if (balance >= 100000) {
      return '₹${(balance / 100000).toStringAsFixed(1)}L';
    } else if (balance >= 1000) {
      return '₹${(balance / 1000).toStringAsFixed(1)}K';
    } else if (balance >= 0) {
      return '₹${balance.toStringAsFixed(0)}';
    } else {
      final absBalance = balance.abs();
      if (absBalance >= 10000000) {
        return '-₹${(absBalance / 10000000).toStringAsFixed(1)}Cr';
      } else if (absBalance >= 100000) {
        return '-₹${(absBalance / 100000).toStringAsFixed(1)}L';
      } else if (absBalance >= 1000) {
        return '-₹${(absBalance / 1000).toStringAsFixed(1)}K';
      } else {
        return '-₹${absBalance.toStringAsFixed(0)}';
      }
    }
  }

  // ============ FILTER METHODS ============


  // ============ DATA FILTERING METHODS ============

  ({List<double> data, double total}) _getFilteredData(List<Bill> salesBills, TimeFilter filter) {
    switch (filter) {
      case TimeFilter.day:
        return _getTodayData(salesBills);
      case TimeFilter.week:
        return _getWeekData(salesBills);
      case TimeFilter.month:
        return _getMonthData(salesBills);
      case TimeFilter.year:
        return _getYearData(salesBills);
    }
  }

  ({List<double> data, double total}) _getTodayData(List<Bill> salesBills) {
    final now = DateTime.now();
    final todayBills = salesBills.where((bill) => 
      bill.date.year == now.year &&
      bill.date.month == now.month &&
      bill.date.day == now.day
    ).toList();
    
    final hourlyData = List.generate(24, (hour) {
      return todayBills
          .where((bill) => bill.date.hour == hour)
          .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    });
    
    final total = todayBills.fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    
    return (data: hourlyData, total: total);
  }

  ({List<double> data, double total}) _getWeekData(List<Bill> salesBills) {
    final now = DateTime.now();
    final dailyData = List.generate(7, (daysAgo) {
      final targetDate = now.subtract(Duration(days: daysAgo));
      return salesBills
          .where((bill) =>
            bill.date.year == targetDate.year &&
            bill.date.month == targetDate.month &&
            bill.date.day == targetDate.day)
          .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    }).reversed.toList();
    
    final weekBills = salesBills.where((bill) {
      final weekAgo = now.subtract(const Duration(days: 7));
      return bill.date.isAfter(weekAgo);
    }).toList();
    
    final total = weekBills.fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    
    return (data: dailyData, total: total);
  }

  ({List<double> data, double total}) _getMonthData(List<Bill> salesBills) {
    final now = DateTime.now();
    final weeklyData = List.generate(4, (weekIndex) {
      final weekStart = now.subtract(Duration(days: (weekIndex + 1) * 7));
      final weekEnd = now.subtract(Duration(days: weekIndex * 7));
      return salesBills
          .where((bill) => 
            bill.date.isAfter(weekStart) && 
            bill.date.isBefore(weekEnd))
          .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    }).reversed.toList();
    
    final monthAgo = now.subtract(const Duration(days: 30));
    final monthBills = salesBills.where((bill) => bill.date.isAfter(monthAgo)).toList();
    
    final total = monthBills.fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    
    return (data: weeklyData, total: total);
  }

  ({List<double> data, double total}) _getYearData(List<Bill> salesBills) {
    final now = DateTime.now();
    final monthlyData = List.generate(12, (monthIndex) {
      final month = (now.month - monthIndex - 1) % 12 + 1;
      final year = now.year - (monthIndex >= now.month ? 1 : 0);
      return salesBills
          .where((bill) => 
            bill.date.year == year &&
            bill.date.month == month)
          .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    }).reversed.toList();
    
    final yearAgo = DateTime(now.year - 1, now.month, now.day);
    final yearBills = salesBills.where((bill) => bill.date.isAfter(yearAgo)).toList();
    
    final total = yearBills.fold<double>(0, (sum, bill) => sum + bill.totalAmount);
    
    return (data: monthlyData, total: total);
  }

  // ============ HELPER METHODS ============

  List<String> _getBottomLabels(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.day:
        return List.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00');
      case TimeFilter.week:
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case TimeFilter.month:
        return ['W1', 'W2', 'W3', 'W4'];
      case TimeFilter.year:
        return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    }
  }

  double _getBarWidth(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.day:
        return 12;
      case TimeFilter.week:
        return 20;
      case TimeFilter.month:
        return 30;
      case TimeFilter.year:
        return 25;
    }
  }

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

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

 
  Widget _legendItem({
    required Color color,
    required String label,
    required String value,
    required String percentage,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          percentage,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  // ============ GRAPH STATE WIDGETS ============

  Widget _buildLoadingGraph() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Loading sales data...',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorGraph() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load data',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyGraph() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.bar_chart,
              size: 48,
              color: colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No sales data',
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  
}