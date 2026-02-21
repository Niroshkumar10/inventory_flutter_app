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
  
  const LedgerHomeScreen({super.key, required this.userMobile});

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? colorScheme.background : const Color(0xffF5F6FA),
        appBar: AppBar(
          backgroundColor: colorScheme.primary,
          title: const Text(
            'My Accounts',
            style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Summary'),
              Tab(icon: Icon(Icons.people), text: 'Customers'),
              Tab(icon: Icon(Icons.store), text: 'Suppliers'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Add Record',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: colorScheme.primary,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 300));
      },
      color: colorScheme.primary,
      backgroundColor: colorScheme.surface,
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
                  elevation: isDark ? 4 : 2,
                  color: colorScheme.primary.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Your Balance',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _currencyFormat.format(netBalance),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: netBalance >= 0 ? colorScheme.secondary : colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          netBalance >= 0 
                              ? 'People have to pay you money' 
                              : 'You have to pay money to people',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withOpacity(0.7),
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
                            colorScheme.secondary,
                            Icons.shopping_cart,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _simpleStatCard(
                            'Purchases',
                            stats['totalPurchases'] ?? 0,
                            colorScheme.tertiary,
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
                            colorScheme.primary,
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
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
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
                  colorScheme.secondary,
                  () => _addSale(),
                ),
                _simpleActionCard(
                  'Add Purchase',
                  Icons.shopping_bag,
                  colorScheme.tertiary,
                  () => _addPurchase(),
                ),
                _simpleActionCard(
                  'Receive Money',
                  Icons.download,
                  colorScheme.primary,
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
            Text(
              'Recent Records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            
            StreamBuilder<List<LedgerEntry>>(
              stream: _ledgerService.getLedgerEntries(limit: 5),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: colorScheme.primary));
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
              child: Text(
                'View All Records',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyList(String partyType) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCustomer = partyType == 'customer';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isCustomer = partyType == 'customer';

    if (snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator(color: colorScheme.primary));
    }
    
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return _emptyPartyState(partyType);
    }
    
    final parties = snapshot.data!;
    
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      color: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: parties.length,
        itemBuilder: (context, index) {
          final party = parties[index];
          late String partyId;
          late String partyName;
          late String contact;
          
          if (isCustomer) {
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
            elevation: isDark ? 4 : 2,
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: (isCustomer ? colorScheme.secondary : colorScheme.tertiary).withOpacity(0.2),
                child: Icon(
                  isCustomer ? Icons.person : Icons.store,
                  color: isCustomer ? colorScheme.secondary : colorScheme.tertiary,
                ),
              ),
              title: Text(
                partyName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              subtitle: FutureBuilder<double>(
                future: _ledgerService.getPartyBalance(partyId),
                builder: (context, balanceSnapshot) {
                  if (balanceSnapshot.connectionState == ConnectionState.waiting) {
                    return Text(contact, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)));
                  }
                  
                  final balance = balanceSnapshot.data ?? 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact,
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        balance >= 0 
                            ? 'Owes you: ${_currencyFormat.format(balance)}' 
                            : 'You owe: ${_currencyFormat.format(balance.abs())}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: balance >= 0 ? colorScheme.secondary : colorScheme.error,
                        ),
                      ),
                    ],
                  );
                },
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              onTap: () => _viewPartyLedger(party, partyType),
            ),
          );
        },
      ),
    );
  }

  Widget _simpleStatCard(String title, double value, Color color, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: isDark ? 4 : 2,
      color: colorScheme.surface,
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: isDark ? 4 : 2,
      color: colorScheme.surface,
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _simpleTransactionItem(LedgerEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: isDark ? 4 : 1,
      color: colorScheme.surface,
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
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.description,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              _dateFormat.format(entry.date),
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.5),
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
                color: entry.isDebit() ? colorScheme.secondary : colorScheme.error,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: entry.statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
    border: Border.all(color: entry.statusColor.withOpacity(0.3)), // Fixed: Use Border.all()
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No records yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first transaction',
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _emptyPartyState(String partyType) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              partyType == 'customer' ? Icons.person : Icons.store,
              size: 80,
              color: colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${partyType == 'customer' ? 'customers' : 'suppliers'} yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              partyType == 'customer'
                  ? 'Add customers to track sales'
                  : 'Add suppliers to track purchases',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.only(
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
                    color: colorScheme.onSurface.withOpacity(0.2),
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'with ${entry.partyName}',
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: entry.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
    border: Border.all(color: entry.statusColor.withOpacity(0.3)), // Fixed: Use Border.all()
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
                      _detailItem('Date', _dateFormat.format(entry.date), colorScheme),
                      _detailItem('Amount', _currencyFormat.format(entry.amount), colorScheme),
                      if (entry.description.isNotEmpty) 
                        _detailItem('Description', entry.description, colorScheme),
                      if (entry.reference.isNotEmpty) 
                        _detailItem('Reference', entry.reference, colorScheme),
                      if (entry.notes.isNotEmpty) 
                        _detailItem('Notes', entry.notes, colorScheme),
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
                          side: BorderSide(color: colorScheme.outline),
                          foregroundColor: colorScheme.onSurface,
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
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
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

  Widget _detailItem(String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsPaid(LedgerEntry entry) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    try {
      await _ledgerService.updateLedgerStatus(entry.id, 'paid');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Marked as paid'),
            backgroundColor: colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}