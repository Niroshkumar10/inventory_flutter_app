// lib/features/bill/screens/bill_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bill_service.dart';
import '../models/bill_model.dart';
import 'add_edit_bill_screen.dart';
import 'view_bill_screen.dart';

class BillHomeScreen extends StatefulWidget {
  final String userMobile;

  const BillHomeScreen({super.key, required this.userMobile});

  @override
  State<BillHomeScreen> createState() => _BillHomeScreenState();
}

class _BillHomeScreenState extends State<BillHomeScreen> {
  String _currentFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _BillSearchDelegate(
                  userMobile: widget.userMobile,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          _buildSummaryCards(),
          
          // Filter Tabs (Only Sales & Purchase)
          _buildFilterTabs(),
          
          // Transactions List
          Expanded(
            child: _buildTransactionsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAddBillDialog(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Transaction'),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return StreamBuilder<BillSummary>(
      stream: Provider.of<BillService>(context, listen: false)
          .getBillSummary(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final summary = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  _buildSummaryCard(
                    title: 'Total Sales',
                    amount: summary.totalSales,
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryCard(
                    title: 'Total Purchases',
                    amount: summary.totalPurchases,
                    icon: Icons.trending_down,
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildSummaryCard(
                    title: 'Amount Due',
                    amount: summary.totalDue,
                    icon: Icons.access_time,
                    color: Colors.red,
                    dueCount: summary.dueCount,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    int? dueCount,
  }) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.5), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (dueCount != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$dueCount pending',
                        style: TextStyle(
                          color: color.withOpacity(0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(icon, size: 40, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final List<Map<String, dynamic>> filters = [
      {'value': 'all', 'label': 'All', 'color': Colors.blue},
      {'value': 'sales', 'label': 'Sales', 'color': Colors.green},
      {'value': 'purchase', 'label': 'Purchases', 'color': Colors.orange},
      {'value': 'due', 'label': 'Due', 'color': Colors.red},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: filters.map((filter) {
            final isActive = _currentFilter == filter['value'];
            final color = filter['color'] as Color;
            final label = filter['label'] as String;
            final value = filter['value'] as String;
            
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                selected: isActive,
                onSelected: (selected) {
                  setState(() {
                    _currentFilter = value;
                  });
                },
                label: Text(label),
                backgroundColor: isActive 
                  ? color.withOpacity(0.2)
                  : Colors.grey.shade200,
                selectedColor: color.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isActive ? color : Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                checkmarkColor: color,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<List<Bill>>(
      stream: Provider.of<BillService>(context, listen: false)
          .getBills(filter: _currentFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final bills = snapshot.data ?? [];
        
        if (bills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _currentFilter == 'sales' ? Icons.shopping_cart :
                  _currentFilter == 'purchase' ? Icons.inventory : Icons.receipt,
                  size: 64,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                Text(
                  _currentFilter == 'all' 
                    ? 'No transactions found'
                    : 'No ${_currentFilter} transactions found',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first transaction to get started',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: bills.length,
          itemBuilder: (context, index) {
            final bill = bills[index];
            return _buildTransactionCard(bill);
          },
        );
      },
    );
  }

  Widget _buildTransactionCard(Bill bill) {
    Color statusColor;
    String statusText;
    
    if (bill.amountDue == 0) {
      statusColor = Colors.green.shade100;
      statusText = 'Paid';
    } else if (bill.amountPaid > 0) {
      statusColor = Colors.blue.shade100;
      statusText = 'Partial';
    } else {
      statusColor = Colors.red.shade100;
      statusText = 'Due';
    }
    
    final isSales = bill.type == 'sales';
    final iconColor = isSales ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      child: ListTile(
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
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isSales ? Icons.shopping_cart : Icons.inventory,
            color: iconColor,
            size: 30,
          ),
        ),
        title: Text(
          bill.invoiceNumber,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bill.partyName),
            const SizedBox(height: 2),
            Text(
              '${_formatDate(bill.date)} • ${bill.type.toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${bill.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: iconColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusText == 'Due' ? Colors.red : Colors.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBillDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Create New Transaction',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart, color: Colors.green),
                title: const Text('Sales Entry'),
                subtitle: const Text('Record a sale to customer'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToAddBill('sales');
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory, color: Colors.orange),
                title: const Text('Purchase Entry'),
                subtitle: const Text('Record a purchase from supplier'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToAddBill('purchase');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

 void _navigateToAddBill(String type) {
  final billService = Provider.of<BillService>(context, listen: false);
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => AddEditBillScreen(
        type: type,
        userMobile: widget.userMobile,
        billService: billService, // Pass the service
      ),
    ),
  );
}

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
// Search Delegate - FIXED
class _BillSearchDelegate extends SearchDelegate {
  final String userMobile;
  late final BillService _billService;

  _BillSearchDelegate({required this.userMobile}) {
    _billService = BillService(userMobile);
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return StreamBuilder<List<Bill>>(
      stream: _billService.searchBills(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final bills = snapshot.data!;
        
        if (bills.isEmpty) {
          return const Center(
            child: Text('No matching transactions found'),
          );
        }
        
        return ListView.builder(
          itemCount: bills.length,
          itemBuilder: (context, index) {
            final bill = bills[index];
            return ListTile(
              leading: Icon(
                bill.type == 'sales' ? Icons.shopping_cart : Icons.inventory,
                color: bill.type == 'sales' ? Colors.green : Colors.orange,
              ),
              title: Text(bill.invoiceNumber),
              subtitle: Text('${bill.partyName} • ${bill.type}'),
              trailing: Text(
                '₹${bill.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
            );
          },
        );
      },
    );
  }

  @override
  String get searchFieldLabel => 'Search transactions...';
}