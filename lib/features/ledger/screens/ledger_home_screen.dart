import 'package:flutter/material.dart';
import '../services/ledger_service.dart';
import '../models/ledger_model.dart'; // ADD THIS IMPORT
import '../../party/services/customer_service.dart';
import '../../party/services/supplier_service.dart';
import '../../party/models/customer_model.dart'; // ADD THIS
import '../../party/models/supplier_model.dart'; // ADD THIS
import 'ledger_list_screen.dart';
import 'add_ledger_entry_screen.dart';
import 'party_ledger_screen.dart';

class LedgerHomeScreen extends StatefulWidget {
  final String userMobile;
  
  const LedgerHomeScreen({Key? key, required this.userMobile}) : super(key: key);

  @override
  State<LedgerHomeScreen> createState() => _LedgerHomeScreenState();
}

class _LedgerHomeScreenState extends State<LedgerHomeScreen> {
  late final LedgerService _ledgerService;
  late final CustomerService _customerService;
  late final SupplierService _supplierService;
  
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _ledgerService = LedgerService(widget.userMobile);
    _customerService = CustomerService(widget.userMobile);
    _supplierService = SupplierService(widget.userMobile);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ledger'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Customers'),
              Tab(text: 'Suppliers'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add),
          onPressed: () => _addLedgerEntry(),
        ),
        body: TabBarView(
          children: [
            _buildDashboard(),
            _buildPartyList('customer'),
            _buildPartyList('supplier'),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _ledgerService.getStatistics(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final stats = snapshot.data ?? {};
                  
                  return Column(
                    children: [
                      Row(
                        children: [
                          _statCard('Total Sales', '₹${stats['totalSales'] ?? 0}', const Color.fromARGB(255, 255, 255, 255)),
                          const SizedBox(width: 12),
                          _statCard('Total Purchases', '₹${stats['totalPurchases'] ?? 0}', const Color.fromARGB(255, 255, 255, 255)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _statCard('Payments Received', '₹${stats['totalPayments'] ?? 0}', const Color.fromARGB(255, 255, 254, 254)),
                          const SizedBox(width: 12),
                          _statCard('Payments Made', '₹${stats['totalReceipts'] ?? 0}', const Color.fromARGB(255, 255, 255, 255)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Balance', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '₹${stats['netBalance'] ?? 0}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: (stats['netBalance'] as num? ?? 0) >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Quick Actions
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
              childAspectRatio: 1.5,
            ),
            children: [
              _actionCard(
                context,
                'All Entries',
                Icons.list,
                Colors.blue,
                () => _viewAllEntries(),
              ),
              _actionCard(
                context,
                'Add Sale',
                Icons.shopping_cart,
                Colors.green,
                () => _addSale(),
              ),
              _actionCard(
                context,
                'Add Purchase',
                Icons.inventory,
                Colors.red,
                () => _addPurchase(),
              ),
              _actionCard(
                context,
                'Add Payment',
                Icons.arrow_circle_down,
                Colors.purple,
                () => _addPayment(),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Recent Transactions
          StreamBuilder<List<LedgerEntry>>(
            stream: _ledgerService.getLedgerEntries(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final entries = snapshot.data ?? [];
              
              if (entries.isEmpty) {
                return _emptyState();
              }
              
              // Take only first 5 entries for dashboard
              final recentEntries = entries.take(5).toList();
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...recentEntries.map((entry) => _transactionItem(entry)).toList(),
                  
                  if (entries.length > 5)
                    TextButton(
                      onPressed: () => _viewAllEntries(),
                      child: const Text('View All Transactions'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPartyList(String partyType) {
    if (partyType == 'customer') {
      return StreamBuilder<List<Customer>>(
        stream: _customerService.getCustomers(),
        builder: (context, snapshot) {
          return _buildPartyListView(snapshot, partyType);
        },
      );
    } else {
      return StreamBuilder<List<Supplier>>(
        stream: _supplierService.getSuppliers(),
        builder: (context, snapshot) {
          return _buildPartyListView(snapshot, partyType);
        },
      );
    }
  }

  Widget _buildPartyListView(AsyncSnapshot snapshot, String partyType) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              partyType == 'customer' ? Icons.person : Icons.store,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              'No ${partyType}s found',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    final parties = snapshot.data!;
    
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: parties.length,
      itemBuilder: (context, index) {
        final party = parties[index];
        return
    // In ledger_home_screen.dart, update the balance display:
FutureBuilder<double>(
  future: _ledgerService.getPartyBalance(party.id),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Text(
        'Balance: Calculating...',
        style: TextStyle(color: Colors.grey),
      );
    }
    
    if (snapshot.hasError) {
      return Text(
        'Balance: Error',
        style: TextStyle(color: Colors.orange),
      );
    }
    
    final balance = snapshot.data ?? 0;
    return Text(
      'Balance: ₹${balance.toStringAsFixed(2)}',
      style: TextStyle(
        color: balance >= 0 ? Colors.green : Colors.red,
        fontWeight: FontWeight.bold,
      ),
    );

          },
        );
      },
    );
  }

  String _getPartyContact(dynamic party, String partyType) {
    if (partyType == 'customer') {
      return (party as Customer).mobile;
    } else {
      return (party as Supplier).phone;
    }
  }

  Widget _statCard(String title, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
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
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _transactionItem(LedgerEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.typeColor.withOpacity(0.2),
          child: Icon(entry.typeIcon, color: entry.typeColor, size: 20),
        ),
        title: Text(entry.partyName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              entry.description,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              '${entry.date.day}/${entry.date.month}/${entry.date.year}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${entry.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: entry.isDebit() ? Colors.green : const Color.fromARGB(255, 228, 132, 125),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Bal: ₹${entry.balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11,
                color: entry.balance >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        onTap: () => _viewEntryDetails(entry),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 80, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'No ledger entries yet',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first transaction',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Navigation Methods
  void _addLedgerEntry({String? type, String? partyType}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddLedgerEntryScreen(
        userMobile: widget.userMobile,
        initialType: type,
        initialPartyType: partyType,
      ),
    ).then((_) {
      setState(() {}); // Refresh data
    });
  }

  void _addSale() => _addLedgerEntry(type: 'sale', partyType: 'customer');
  void _addPurchase() => _addLedgerEntry(type: 'purchase', partyType: 'supplier');
  void _addPayment() => _addLedgerEntry(type: 'payment', partyType: 'customer');

  void _viewAllEntries() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LedgerListScreen(userMobile: widget.userMobile),
      ),
    );
  }

  void _viewPartyLedger(dynamic party, String partyType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartyLedgerScreen(
          userMobile: widget.userMobile,
          party: party,
          partyType: partyType,
        ),
      ),
    );
  }

  void _viewEntryDetails(LedgerEntry entry) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Date', '${entry.date.day}/${entry.date.month}/${entry.date.year}'),
              _detailRow('Type', entry.typeLabel),
              _detailRow('Party', entry.partyName),
              _detailRow('Description', entry.description),
              _detailRow('Reference', entry.reference.isNotEmpty ? entry.reference : 'N/A'),
              _detailRow('Amount', '₹${entry.amount.toStringAsFixed(2)}'),
              _detailRow('Balance', '₹${entry.balance.toStringAsFixed(2)}'),
              if (entry.notes.isNotEmpty) _detailRow('Notes', entry.notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}