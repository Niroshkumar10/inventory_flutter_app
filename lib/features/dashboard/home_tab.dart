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

// ============ TIME FILTER ENUM (TOP LEVEL) ============
enum TimeFilter { day, week, month, year }

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
      appBar: AppBar(
        title: Text(_currentTitle),
        leading: _isOnDashboard
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              ),
      ),
      body: _currentScreen,
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
    Key? key,
    required this.userMobile,
    required this.inventoryService,
    required this.customerService,
    required this.supplierService,
    required this.onNavigate,
  }) : super(key: key);

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ===== SUMMARY CARDS ===== (Mobile Optimized)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: _summaryCardMobile(
                    title: 'Customers',
                    icon: Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                    stream: widget.customerService.getCustomers(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCardMobile(
                    title: 'Suppliers',
                    icon: Icons.people,
                    color: Theme.of(context).colorScheme.secondary,
                    stream: widget.supplierService.getSuppliers(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCardMobile(
                    title: 'Inventory',
                    icon: Icons.inventory_2,
                    color: Theme.of(context).colorScheme.tertiary,
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
              const Text(
                'Sales Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              _buildFilterChips(),
            ],
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
              
              // Get filtered data
              final filteredData = _getFilteredData(salesBills, _selectedFilter);
              final totalAmount = filteredData.total;
              final chartData = filteredData.data;
              final maxValue = chartData.isNotEmpty 
                  ? chartData.reduce((a, b) => a > b ? a : b) 
                  : 0.0;
              
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
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
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Total: ₹${totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Bar Graph
                      SizedBox(
                        height: 180,
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
                                    const TextStyle(
                                      color: Colors.white,
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
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
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
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
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
                                  color: Colors.grey[200]!,
                                  strokeWidth: 1,
                                  dashArray: const [4, 4],
                                );
                              },
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            barGroups: List.generate(chartData.length, (index) {
                              final sales = chartData[index];
                              final colors = sales > 0
                                  ? [
                                      Colors.blue.shade400,
                                      Colors.blue.shade200,
                                    ]
                                  : [
                                      Colors.grey.shade300,
                                      Colors.grey.shade200,
                                    ];
                              
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
                                    gradient: LinearGradient(
                                      colors: colors,
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    backDrawRodData: BackgroundBarChartRodData(
                                      show: true,
                                      toY: maxValue > 0 ? maxValue * 1.2 : 100,
                                      color: Colors.grey[50],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                      
                      // Today's Sales Indicator (for day filter)
                      if (_selectedFilter == TimeFilter.day)
                        const SizedBox(height: 16),
                      if (_selectedFilter == TimeFilter.day)
                        StreamBuilder<List<Bill>>(
                          stream: Provider.of<BillService>(context, listen: false).getBills(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();
                            
                            final todaySales = snapshot.data!
                                .where((bill) => bill.type == 'sales' && 
                                    _isToday(bill.date))
                                .fold<double>(0, (sum, bill) => sum + bill.totalAmount);
                            
                            if (todaySales == 0) return const SizedBox();
                            
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.shade100,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Today: ₹${todaySales.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.green.shade800,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.trending_up,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          /// ===== SALES VS PURCHASE COMPARISON =====
          const Text(
            'Sales vs Purchase',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          StreamBuilder<List<Bill>>(
            stream: Provider.of<BillService>(context, listen: false).getBills(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      height: 100,
                      child: Center(
                        child: Text('No comparison data'),
                      ),
                    ),
                  ),
                );
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Progress Bar
                      Stack(
                        children: [
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                flex: salesPercentage.toInt(),
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green.shade400,
                                        Colors.green.shade300,
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(6),
                                      bottomLeft: Radius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: purchasePercentage.toInt(),
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.orange.shade400,
                                        Colors.orange.shade300,
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(6),
                                      bottomRight: Radius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _legendItem(
                            color: Colors.green,
                            label: 'Sales',
                            value: '₹${totalSales.toStringAsFixed(0)}',
                            percentage: '${salesPercentage.toStringAsFixed(1)}%',
                          ),
                          _legendItem(
                            color: Colors.orange,
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
                title: 'Customers',
                icon: Icons.person,
                onTap: () => widget.onNavigate(
                  CustomerListScreen(userMobile: widget.userMobile),
                  'Customers',
                ),
              ),
              _actionCard(
                title: 'Suppliers',
                icon: Icons.people,
                onTap: () => widget.onNavigate(
                  SupplierListScreen(userMobile: widget.userMobile),
                  'Suppliers',
                ),
              ),
              _actionCard(
                title: 'Ledger',
                icon: Icons.menu_book,
                onTap: () => widget.onNavigate(
                  LedgerHomeScreen(userMobile: widget.userMobile),
                  'Ledger',
                ),
              ),
              _actionCard(
                title: 'Inventory',
                icon: Icons.inventory_2,
                onTap: () => widget.onNavigate(
                  InventoryDashboard(
                    inventoryService: widget.inventoryService,
                    userMobile: widget.userMobile,
                  ),
                  'Inventory',
                ),
              ),
            ],
          ),
        ],
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
    return Container(
      constraints: const BoxConstraints(minWidth: 70),
      child: StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          final count = snapshot.hasData ? (snapshot.data as List).length : 0;
          
          return Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
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
    return Container(
      constraints: const BoxConstraints(minWidth: 70),
      child: StreamBuilder<List<Bill>>(
        stream: Provider.of<BillService>(context, listen: false).getBills(),
        builder: (context, snapshot) {
          final balance = _calculateBalanceFromBills(snapshot.data);
          
          return Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 1,
            color: Colors.deepPurple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.deepPurple,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatBalance(balance),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Balance',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
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

  // ============ EXISTING METHODS (KEEP AS IS) ============

  /// ===== FILTER CHIPS =====
  Widget _buildFilterChips() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
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
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// ===== GET FILTERED DATA =====
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

  /// ===== GET BOTTOM LABELS =====
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

  /// ===== GET BAR WIDTH =====
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

  /// ===== BALANCE CARD ===== (Old version - you can remove if using mobile version)
  Widget _balanceCard(BuildContext context) {
    return Expanded(
      child: StreamBuilder<List<Bill>>(
        stream: Provider.of<BillService>(context, listen: false).getBills(),
        builder: (context, billSnap) {
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

  /// ===== STREAM SUMMARY CARD ===== (Old version)
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
          final count = snapshot.hasData ? snapshot.data!.length : 0;
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

  /// ===== SUMMARY CARD UI ===== (Old version)
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
  Widget _actionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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

  /// ===== LEGEND ITEM FOR COMPARISON CHART =====
  Widget _legendItem({
    required Color color,
    required String label,
    required String value,
    required String percentage,
  }) {
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
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          percentage,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  /// ===== HELPER METHODS =====
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }

  Widget _buildEmptyGraph() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sales Overview',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _buildFilterChips(),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No sales data available',
                      style: TextStyle(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}