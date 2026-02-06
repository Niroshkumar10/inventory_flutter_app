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
          title: const Text('My Accounts'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Summary'),
              Tab(icon: Icon(Icons.people), text: 'Customers'),
              Tab(icon: Icon(Icons.store), text: 'Suppliers'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.blue.shade700,
          icon: const Icon(Icons.add),
          label: const Text('Add Record'),
          onPressed: () => _addLedgerEntry(),
        ),
        body: TabBarView(
          children: [
            _buildSummaryScreen(),
            _buildPartyList('customer'),
            _buildPartyList('supplier'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryScreen() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 300));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Balance Card
            FutureBuilder<Map<String, dynamic>>(
              future: _ledgerService.getStatistics(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingCard();
                }
                
                final stats = snapshot.data ?? {};
                final netBalance = (stats['netBalance'] as num? ?? 0).toDouble();
                
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Your Balance',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _currencyFormat.format(netBalance),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: netBalance >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          netBalance >= 0 ? 'People owe you money' : 'You owe money to people',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // Quick Stats
            FutureBuilder<Map<String, dynamic>>(
              future: _ledgerService.getStatistics(),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {};
                
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _simpleStatCard(
                            'Sales',
                            stats['totalSales'] ?? 0,
                            Colors.green,
                            Icons.shopping_cart,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _simpleStatCard(
                            'Purchases',
                            stats['totalPurchases'] ?? 0,
                            Colors.orange,
                            Icons.shopping_bag,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _simpleStatCard(
                            'Received',
                            stats['totalPayments'] ?? 0,
                            Colors.blue,
                            Icons.download,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _simpleStatCard(
                            'Paid',
                            stats['totalReceipts'] ?? 0,
                            Colors.purple,
                            Icons.upload,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _simpleActionCard(
                  'Add Sale',
                  Icons.shopping_cart,
                  Colors.green,
                  () => _addSale(),
                ),
                _simpleActionCard(
                  'Add Purchase',
                  Icons.shopping_bag,
                  Colors.orange,
                  () => _addPurchase(),
                ),
                _simpleActionCard(
                  'Receive Money',
                  Icons.download,
                  Colors.blue,
                  () => _addPayment(),
                ),
                _simpleActionCard(
                  'Pay Money',
                  Icons.upload,
                  Colors.purple,
                  () => _addPaymentMade(),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Recent Records
            const Text(
              'Recent Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            StreamBuilder<List<LedgerEntry>>(
              stream: _ledgerService.getLedgerEntries(limit: 5),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final entries = snapshot.data ?? [];
                
                if (entries.isEmpty) {
                  return _simpleEmptyState();
                }
                
                return Column(
                  children: entries.map((entry) => _simpleTransactionItem(entry)).toList(),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            TextButton(
              onPressed: _viewAllEntries,
              child: const Text('View All Records'),
            ),
          ],
        ),
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
      return _emptyPartyState(partyType);
    }
    
    final parties = snapshot.data!;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: parties.length,
      itemBuilder: (context, index) {
        final party = parties[index];
        late String partyId;
        late String partyName;
        late String contact;
        
        if (partyType == 'customer') {
          final customer = party as Customer;
          partyId = customer.id;
          partyName = customer.name;
          contact = customer.mobile;
        } else {
          final supplier = party as Supplier;
          partyId = supplier.id;
          partyName = supplier.name;
          contact = supplier.phone;
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: partyType == 'customer' 
                  ? Colors.blue.shade100
                  : Colors.orange.shade100,
              child: Icon(
                partyType == 'customer' ? Icons.person : Icons.store,
                color: partyType == 'customer' ? Colors.blue : Colors.orange,
              ),
            ),
            title: Text(
              partyName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: FutureBuilder<double>(
              future: _ledgerService.getPartyBalance(partyId),
              builder: (context, balanceSnapshot) {
                if (balanceSnapshot.connectionState == ConnectionState.waiting) {
                  return Text(contact);
                }
                
                final balance = balanceSnapshot.data ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact),
                    const SizedBox(height: 4),
                    Text(
                      balance >= 0 ? 'Owes you: ${_currencyFormat.format(balance)}' 
                                 : 'You owe: ${_currencyFormat.format(balance.abs())}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: balance >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                );
              },
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.grey.shade500,
            ),
            onTap: () => _viewPartyLedger(party, partyType),
          ),
        );
      },
    );
  }

  Widget _simpleStatCard(String title, double value, Color color, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _currencyFormat.format(value),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _simpleActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _simpleTransactionItem(LedgerEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: entry.typeColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            entry.typeIcon,
            color: entry.typeColor,
            size: 20,
          ),
        ),
        title: Text(
          entry.partyName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.description,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              _dateFormat.format(entry.date),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: entry.isDebit() ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(top: 4),
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
        onTap: () => _showSimpleDetails(entry),
      ),
    );
  }

  Widget _simpleEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'No records yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first transaction',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _emptyPartyState(String partyType) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              partyType == 'customer' ? Icons.person : Icons.store,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${partyType == 'customer' ? 'customers' : 'suppliers'} yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              partyType == 'customer'
                  ? 'Add customers to track sales'
                  : 'Add suppliers to track purchases',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  // Navigation Methods
  void _addLedgerEntry({String? type, String? partyType}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLedgerEntryScreen(
          userMobile: widget.userMobile,
          initialType: type,
          initialPartyType: partyType,
        ),
      ),
    );
    
    if (mounted) {
      setState(() {});
    }
  }

  void _addSale() => _addLedgerEntry(type: 'sale', partyType: 'customer');
  void _addPurchase() => _addLedgerEntry(type: 'purchase', partyType: 'supplier');
  void _addPayment() => _addLedgerEntry(type: 'payment', partyType: 'customer');
  void _addPaymentMade() => _addLedgerEntry(type: 'receipt', partyType: 'supplier');

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

  void _showSimpleDetails(LedgerEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: entry.typeColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(entry.typeIcon, color: entry.typeColor),
                  ),
                  title: Text(
                    entry.typeLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text('with ${entry.partyName}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: entry.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.statusLabel,
                      style: TextStyle(
                        color: entry.statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _detailItem('Date', _dateFormat.format(entry.date)),
                      _detailItem('Amount', _currencyFormat.format(entry.amount)),
                      if (entry.description.isNotEmpty) _detailItem('Description', entry.description),
                      if (entry.reference.isNotEmpty) _detailItem('Reference', entry.reference),
                      if (entry.notes.isNotEmpty) _detailItem('Notes', entry.notes),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    if (entry.status.toLowerCase() == 'pending') ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _markAsPaid(entry);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Mark Paid'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsPaid(LedgerEntry entry) async {
    try {
      await _ledgerService.updateLedgerStatus(entry.id, 'paid');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as paid'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}