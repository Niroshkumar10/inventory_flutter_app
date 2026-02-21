// lib/features/bill/screens/bill_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bill_service.dart';
import '../models/bill_model.dart';
import 'add_edit_bill_screen.dart';
import 'view_bill_screen.dart';
import '../../inventory/services/inventory_repo_service.dart';
import '../../../core/providers/app_providers.dart';

class BillHomeScreen extends StatefulWidget {
  final String userMobile;

  const BillHomeScreen({super.key, required this.userMobile});

  @override
  State<BillHomeScreen> createState() => _BillHomeScreenState();
}

class _BillHomeScreenState extends State<BillHomeScreen> {
  String _currentFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(
          'Bills & Transactions',
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
          // Search Button
          IconButton(
            icon: Icon(Icons.search, color: colorScheme.onSurface),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _BillSearchDelegate(
                  userMobile: widget.userMobile,
                ),
              );
            },
          ),
          // Refresh Button
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onSurface),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards Section
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<BillSummary>(
              stream: Provider.of<BillService>(context, listen: false)
                  .getBillSummary(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: colorScheme.primary),
                  );
                }
                
                final summary = snapshot.data!;
                return Column(
                  children: [
                    // Welcome Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Financial Overview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Track your sales and purchases',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.receipt_long,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Summary Cards in Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactSummaryCard(
                            'Sales',
                            summary.totalSales,
                            Icons.trending_up,
                            colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCompactSummaryCard(
                            'Purchases',
                            summary.totalPurchases,
                            Icons.trending_down,
                            colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Due Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.error.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.access_time,
                              color: colorScheme.error,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Amount Due',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.error,
                                  ),
                                ),
                                Text(
                                  '₹${summary.totalDue.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${summary.dueCount} pending',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Filter Tabs
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter Transactions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all', colorScheme.primary),
                      _buildFilterChip('Sales', 'sales', colorScheme.secondary),
                      _buildFilterChip('Purchases', 'purchase', colorScheme.tertiary),
                      _buildFilterChip('Due', 'due', colorScheme.error),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Transactions List
          Expanded(
            child: StreamBuilder<List<Bill>>(
              stream: Provider.of<BillService>(context, listen: false)
                  .getBills(filter: _currentFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading transactions',
                          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  );
                }
                
                final bills = snapshot.data ?? [];
                
                if (bills.isEmpty) {
                  return _buildEmptyState();
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  color: _getFilterColor(),
                  backgroundColor: colorScheme.surface,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      return _buildTransactionCard(bill);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Dynamic Floating Action Button based on filter
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_currentFilter == 'sales') {
            _navigateToAddBill('sales');
          } else if (_currentFilter == 'purchase') {
            _navigateToAddBill('purchase');
          } else {
            _showAddBillDialog(context);
          }
        },
        icon: Icon(_getFabIcon(), color: Colors.white),
        label: Text(_getFabLabel(), style: const TextStyle(color: Colors.white)),
        backgroundColor: _getFabColor(),
        elevation: isDark ? 4 : 2,
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isActive = _currentFilter == value;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isActive,
        onSelected: (selected) {
          setState(() {
            _currentFilter = value;
          });
        },
        backgroundColor: theme.brightness == Brightness.dark 
            ? colorScheme.surfaceContainerHighest 
            : Colors.grey.shade100,
        selectedColor: color.withOpacity(0.2),
        labelStyle: TextStyle(
          color: isActive ? color : colorScheme.onSurface.withOpacity(0.7),
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
        checkmarkColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: isActive 
            ? BorderSide(color: color)
            : BorderSide(color: colorScheme.outline),
      ),
    );
  }

  Widget _buildCompactSummaryCard(String title, double amount, IconData icon, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Bill bill) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    Color iconColor;
    
    if (bill.amountDue == 0) {
      statusColor = colorScheme.secondary;
      statusText = 'Paid';
    } else if (bill.amountPaid > 0) {
      statusColor = colorScheme.primary;
      statusText = 'Partial';
    } else {
      statusColor = colorScheme.error;
      statusText = 'Due';
    }
    
    final isSales = bill.type == 'sales';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 4 : 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon with gradient
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSales 
                        ? [colorScheme.secondary, colorScheme.secondary.withOpacity(0.7)]
                        : [colorScheme.tertiary, colorScheme.tertiary.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    isSales ? Icons.shopping_cart : Icons.inventory,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Bill Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bill.invoiceNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
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
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bill.partyName,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(bill.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        Text(
                          '₹${bill.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSales ? colorScheme.secondary : colorScheme.tertiary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    IconData icon;
    String title;
    String subtitle;
    Color color;
    
    switch (_currentFilter) {
      case 'sales':
        icon = Icons.shopping_cart;
        title = 'No Sales Found';
        subtitle = 'Start by creating your first sales entry';
        color = colorScheme.secondary;
        break;
      case 'purchase':
        icon = Icons.inventory;
        title = 'No Purchases Found';
        subtitle = 'Start by creating your first purchase entry';
        color = colorScheme.tertiary;
        break;
      case 'due':
        icon = Icons.access_time;
        title = 'No Due Payments';
        subtitle = 'All your payments are cleared';
        color = colorScheme.error;
        break;
      default:
        icon = Icons.receipt_long;
        title = 'No Transactions Yet';
        subtitle = 'Create your first sales or purchase transaction';
        color = colorScheme.primary;
    }
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: color.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (_currentFilter == 'sales') {
                  _navigateToAddBill('sales');
                } else if (_currentFilter == 'purchase') {
                  _navigateToAddBill('purchase');
                } else {
                  _showAddBillDialog(context);
                }
              },
              icon: Icon(_getFabIcon(), color: Colors.white),
              label: Text(_getFabLabel(), style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getFabColor(),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: theme.brightness == Brightness.dark ? 4 : 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for dynamic FAB
  IconData _getFabIcon() {
    switch (_currentFilter) {
      case 'sales':
        return Icons.add_shopping_cart;
      case 'purchase':
        return Icons.add_business;
      default:
        return Icons.add;
    }
  }

  String _getFabLabel() {
    switch (_currentFilter) {
      case 'sales':
        return 'Add Sale';
      case 'purchase':
        return 'Add Purchase';
      default:
        return 'New Transaction';
    }
  }

  Color _getFabColor() {
    final colorScheme = Theme.of(context).colorScheme;
    
    switch (_currentFilter) {
      case 'sales':
        return colorScheme.secondary;
      case 'purchase':
        return colorScheme.tertiary;
      default:
        return colorScheme.primary;
    }
  }

  Color _getFilterColor() {
    final colorScheme = Theme.of(context).colorScheme;
    
    switch (_currentFilter) {
      case 'sales':
        return colorScheme.secondary;
      case 'purchase':
        return colorScheme.tertiary;
      case 'due':
        return colorScheme.error;
      default:
        return colorScheme.primary;
    }
  }

  void _showAddBillDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Create New Transaction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.shopping_cart, color: colorScheme.secondary),
                  ),
                  title: Text('Sales Entry', style: TextStyle(color: colorScheme.onSurface)),
                  subtitle: Text('Record a sale to customer', 
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToAddBill('sales');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory, color: colorScheme.tertiary),
                  ),
                  title: Text('Purchase Entry', style: TextStyle(color: colorScheme.onSurface)),
                  subtitle: Text('Record a purchase from supplier',
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6))),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToAddBill('purchase');
                  },
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: colorScheme.outline),
                        foregroundColor: colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToAddBill(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppProviders(
          userMobile: widget.userMobile,
          child: AddEditBillScreen(
            type: type,
            userMobile: widget.userMobile,
            billService: BillService(widget.userMobile),
          ),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Search Delegate
class _BillSearchDelegate extends SearchDelegate {
  final String userMobile;
  late final BillService _billService;

  _BillSearchDelegate({required this.userMobile}) {
    _billService = BillService(userMobile);
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    final theme = Theme.of(context);
    return [
      IconButton(
        icon: Icon(Icons.clear, color: theme.colorScheme.onSurface),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<Bill>>(
      stream: _billService.searchBills(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colorScheme.primary));
        }
        
        final bills = snapshot.data ?? [];
        
        if (bills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: colorScheme.onSurface.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  query.isEmpty ? 'Start typing to search' : 'No results found',
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                ),
              ],
            ),
          );
        }
        
        return Container(
          color: colorScheme.background,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              final isSales = bill.type == 'sales';
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: colorScheme.surface,
                elevation: isDark ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isSales ? colorScheme.secondary : colorScheme.tertiary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSales ? Icons.shopping_cart : Icons.inventory,
                      color: isSales ? colorScheme.secondary : colorScheme.tertiary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    bill.invoiceNumber,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    '${bill.partyName} • ${bill.type}',
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  trailing: Text(
                    '₹${bill.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  onTap: () {
                    close(context, null);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewBillScreen(
                          billId: bill.id,
                          userMobile: userMobile,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  String get searchFieldLabel => 'Search transactions...';
}