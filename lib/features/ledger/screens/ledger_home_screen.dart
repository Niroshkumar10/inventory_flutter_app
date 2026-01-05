import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ledger_service.dart';
import '../models/ledger_model.dart';
import '../../party/services/customer_service.dart';
import '../../party/services/supplier_service.dart';
import '../../party/models/customer_model.dart';
import '../../party/models/supplier_model.dart';
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
  
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

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
          title: const Text('Ledger Management'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Dashboard', icon: Icon(Icons.dashboard)),
              Tab(text: 'Customers', icon: Icon(Icons.people)),
              Tab(text: 'Suppliers', icon: Icon(Icons.store)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.blue,
          icon: const Icon(Icons.add),
          label: const Text('Add Entry'),
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
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _ledgerService.getStatistics(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final stats = snapshot.data ?? {};
                  
                  return Column(
                    children: [
                      const Text(
                        'Financial Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          _statCard('Total Sales', stats['totalSales'] ?? 0, Colors.green, Icons.shopping_cart),
                          const SizedBox(width: 12),
                          _statCard('Total Purchases', stats['totalPurchases'] ?? 0, Colors.orange, Icons.inventory),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _statCard('Payments Received', stats['totalPayments'] ?? 0, Colors.purple, Icons.arrow_circle_down),
                          const SizedBox(width: 12),
                          _statCard('Payments Made', stats['totalReceipts'] ?? 0, Colors.red, Icons.arrow_circle_up),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 12),
                      
                      // Status Summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${stats['paidCount'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Text('Paid', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${stats['pendingCount'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const Text('Pending', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${stats['totalEntries'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const Text('Total', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      const Divider(color: Colors.grey),
                      const SizedBox(height: 8),
                      
                      // Net Balance
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: (stats['netBalance'] as num? ?? 0) >= 0 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Net Balance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _currencyFormat.format(stats['netBalance'] ?? 0),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: (stats['netBalance'] as num? ?? 0) >= 0 
                                    ? Colors.green
                                    : Colors.red,
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
          ),
          
          const SizedBox(height: 12),
          
          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          
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
                'All Entries',
                Icons.list_alt,
                Colors.blue,
                () => _viewAllEntries(),
              ),
              _actionCard(
                'Add Sale',
                Icons.shopping_cart,
                Colors.green,
                () => _addSale(),
              ),
              _actionCard(
                'Add Purchase',
                Icons.inventory,
                Colors.orange,
                () => _addPurchase(),
              ),
              _actionCard(
                'Add Payment',
                Icons.payment,
                Colors.purple,
                () => _addPayment(),
              ),
              _actionCard(
                'Export Report',
                Icons.picture_as_pdf,
                Colors.red,
                () => _exportReport(),
              ),
              _actionCard(
                'View Stats',
                Icons.bar_chart,
                Colors.teal,
                () => _viewStatistics(),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Recent Transactions
          StreamBuilder<List<LedgerEntry>>(
            stream: _ledgerService.getLedgerEntries(limit: 5),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final entries = snapshot.data ?? [];
              
              if (entries.isEmpty) {
                return _emptyState();
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => _viewAllEntries(),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  ...entries.map((entry) => _transactionItem(entry)).toList(),
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
              partyType == 'customer' ? Icons.person_outline : Icons.store_mall_directory,
              size: 80,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${partyType}s found',
              style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first ${partyType} to get started',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    final parties = snapshot.data!;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: parties.length,
      itemBuilder: (context, index) {
        final party = parties[index];
        final partyId = party.id;
        final partyName = partyType == 'customer' 
            ? (party as Customer).name
            : (party as Supplier).name;
        final contact = partyType == 'customer'
            ? (party as Customer).mobile
            : (party as Supplier).phone;
            
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: partyType == 'customer' 
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              child: Icon(
                partyType == 'customer' ? Icons.person : Icons.store,
                color: partyType == 'customer' ? Colors.blue : Colors.orange,
              ),
            ),
            title: Text(
              partyName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact),
                const SizedBox(height: 4),
                FutureBuilder<double>(
                  future: _ledgerService.getPartyBalance(partyId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text(
                        'Balance: Calculating...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      return const Text(
                        'Balance: Error',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      );
                    }
                    
                    final balance = snapshot.data ?? 0;
                    return Text(
                      'Balance: ${_currencyFormat.format(balance)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: balance >= 0 ? Colors.green : Colors.red,
                      ),
                    );
                  },
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _viewPartyLedger(party, partyType),
          ),
        );
      },
    );
  }

  Widget _statCard(String title, double value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _currencyFormat.format(value),
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

  Widget _actionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      margin: EdgeInsets.zero, // Remove default margin

      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: entry.typeColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(entry.typeIcon, color: entry.typeColor, size: 20),
        ),
        title: Text(
          entry.partyName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.description,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: entry.statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _dateFormat.format(entry.date),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currencyFormat.format(entry.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: entry.isDebit() ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Bal: ${_currencyFormat.format(entry.balance)}',
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
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 20),
          const Text(
            'No ledger entries yet',
            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first transaction to see it here',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _addLedgerEntry(),
            child: const Text('Add First Entry'),
          ),
        ],
      ),
    );
  }

  // Navigation Methods
  void _addLedgerEntry({String? type, String? partyType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLedgerEntryScreen(
          userMobile: widget.userMobile,
          initialType: type,
          initialPartyType: partyType,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {}); // Refresh data
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

  Future<void> _exportReport() async {
    try {
      final result = await _ledgerService.exportLedgerReport(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
        format: 'pdf',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _viewStatistics() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Statistics'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: _ledgerService.getStatistics(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final stats = snapshot.data ?? {};
            
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _statItem('Total Sales', _currencyFormat.format(stats['totalSales'] ?? 0), Colors.green),
                  _statItem('Total Purchases', _currencyFormat.format(stats['totalPurchases'] ?? 0), Colors.orange),
                  _statItem('Payments Received', _currencyFormat.format(stats['totalPayments'] ?? 0), Colors.purple),
                  _statItem('Payments Made', _currencyFormat.format(stats['totalReceipts'] ?? 0), Colors.red),
                  _statItem('Paid Entries', '${stats['paidCount'] ?? 0}', Colors.green),
                  _statItem('Pending Entries', '${stats['pendingCount'] ?? 0}', Colors.orange),
                  const Divider(),
                  _statItem('Net Balance', _currencyFormat.format(stats['netBalance'] ?? 0), 
                      (stats['netBalance'] as num? ?? 0) >= 0 ? Colors.green : Colors.red),
                ],
              ),
            );
          },
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

  Widget _statItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
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
              _detailRow('Date', _dateFormat.format(entry.date)),
              _detailRow('Type', entry.typeLabel),
              _detailRow('Status', entry.statusLabel),
              _detailRow('Party', entry.partyName),
              _detailRow('Description', entry.description),
              _detailRow('Reference', entry.reference.isNotEmpty ? entry.reference : 'N/A'),
              _detailRow('Amount', _currencyFormat.format(entry.amount)),
              _detailRow('Debit', _currencyFormat.format(entry.debit)),
              _detailRow('Credit', _currencyFormat.format(entry.credit)),
              _detailRow('Balance', _currencyFormat.format(entry.balance)),
              if (entry.notes.isNotEmpty) _detailRow('Notes', entry.notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (entry.status.toLowerCase() == 'pending')
            ElevatedButton(
              onPressed: () => _markAsPaid(entry),
              child: const Text('Mark as Paid'),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _markAsPaid(LedgerEntry entry) async {
    try {
      await _ledgerService.updateLedgerStatus(entry.id, 'paid');
      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction marked as paid')),
      );
      if (mounted) setState(() {}); // Refresh UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}