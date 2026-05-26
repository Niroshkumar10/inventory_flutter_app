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
import 'outstanding_dues_screen.dart';

class LedgerHomeScreen extends StatefulWidget {
  final String userMobile;

  const LedgerHomeScreen({super.key, required this.userMobile});

  @override
  State<LedgerHomeScreen> createState() => _LedgerHomeScreenState();
}

class _LedgerHomeScreenState extends State<LedgerHomeScreen>
    with TickerProviderStateMixin {
  late final LedgerService _ledgerService;
  late final CustomerService _customerService;
  late final SupplierService _supplierService;
  late final TabController _tabController;

  int _currentTab = 0;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _ledgerService = LedgerService(widget.userMobile);
    _customerService = CustomerService(widget.userMobile);
    _supplierService = SupplierService(widget.userMobile);
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _currentTab = _tabController.index);
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FAB: context-aware per tab
  // ─────────────────────────────────────────────────────────────────────────

  Widget? _buildFab(ColorScheme cs) {
    switch (_currentTab) {
      case 0: // Summary
        return FloatingActionButton.extended(
          heroTag: 'fab_summary',
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Record', style: TextStyle(color: Colors.white)),
          backgroundColor: cs.primary,
          onPressed: () => _openAddEntry(),
        );
      case 1: // Customers
        return FloatingActionButton.extended(
          heroTag: 'fab_customer',
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Sale', style: TextStyle(color: Colors.white)),
          backgroundColor: cs.secondary,
          onPressed: () =>
              _openAddEntry(type: 'sale', partyType: 'customer'),
        );
      case 2: // Suppliers
        return FloatingActionButton.extended(
          heroTag: 'fab_supplier',
          icon: const Icon(Icons.add, color: Colors.white),
          label:
              const Text('Add Purchase', style: TextStyle(color: Colors.white)),
          backgroundColor: cs.tertiary,
          onPressed: () =>
              _openAddEntry(type: 'purchase', partyType: 'supplier'),
        );
      case 3: // Cash Book — two stacked mini FABs
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'fab_income',
              icon: const Icon(Icons.trending_up, color: Colors.white),
              label: const Text('Add Income',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.teal,
              onPressed: () => _openAddEntry(type: 'income'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'fab_expense',
              icon: const Icon(Icons.trending_down, color: Colors.white),
              label: const Text('Add Expense',
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.deepOrange,
              onPressed: () => _openAddEntry(type: 'expense'),
            ),
          ],
        );
      default:
        return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: cs.primary,
        title: const Text('My Accounts',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Summary'),
            Tab(icon: Icon(Icons.people), text: 'Customers'),
            Tab(icon: Icon(Icons.store), text: 'Suppliers'),
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Cash Book'),
          ],
        ),
      ),
      floatingActionButton: _buildFab(cs),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildPartyList('customer'),
          _buildPartyList('supplier'),
          _buildCashBookTab(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Summary Tab
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSummaryTab() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: cs.primary,
      backgroundColor: cs.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Net balance card ─────────────────────────────────────
            FutureBuilder<Map<String, dynamic>>(
              future: _ledgerService.getStatistics(),
              builder: (context, snap) {
                final stats = snap.data ?? {};
                final netBalance =
                    (stats['netBalance'] as num? ?? 0).toDouble();

                return SizedBox(
                  width: double.infinity,
                  child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: isDark ? 4 : 2,
                  color: cs.primary.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Your Balance',
                            style: TextStyle(
                                fontSize: 16,
                                color: cs.primary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        snap.connectionState == ConnectionState.waiting
                            ? CircularProgressIndicator(color: cs.primary)
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _currency.format(netBalance.abs()),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: netBalance >= 0
                                        ? cs.secondary
                                        : cs.error,
                                  ),
                                ),
                              ),
                        const SizedBox(height: 10),
                        Text(
                          netBalance >= 0
                              ? 'People have to pay you money'
                              : 'You have to pay money to people',
                          style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface.withValues(alpha: 0.7)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // ── Outstanding dues banner ───────────────────────────────
            FutureBuilder<List<LedgerEntry>>(
              future: _ledgerService.getOutstandingDues(),
              builder: (context, snap) {
                final count = snap.data?.length ?? 0;
                if (count == 0) return const SizedBox.shrink();

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OutstandingDuesScreen(
                          userMobile: widget.userMobile),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$count pending due${count == 1 ? '' : 's'} — tap to view',
                            style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Colors.orange),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Quick stats ──────────────────────────────────────────
            FutureBuilder<Map<String, dynamic>>(
              future: _ledgerService.getStatistics(),
              builder: (context, snap) {
                final stats = snap.data ?? {};
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                              'Sales',
                              (stats['totalSales'] ?? 0).toDouble(),
                              cs.secondary,
                              Icons.shopping_cart,
                              isDark: isDark,
                              cs: cs),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                              'Purchases',
                              (stats['totalPurchases'] ?? 0).toDouble(),
                              cs.tertiary,
                              Icons.shopping_bag,
                              isDark: isDark,
                              cs: cs),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                              'Received',
                              (stats['totalPayments'] ?? 0).toDouble(),
                              cs.primary,
                              Icons.download,
                              isDark: isDark,
                              cs: cs),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                              'Paid',
                              (stats['totalReceipts'] ?? 0).toDouble(),
                              Colors.purple,
                              Icons.upload,
                              isDark: isDark,
                              cs: cs),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // ── Quick actions ─────────────────────────────────────────
            Text('Quick Actions',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
              children: [
                _actionCard('Add Sale', Icons.shopping_cart, cs.secondary,
                    () => _openAddEntry(type: 'sale', partyType: 'customer')),
                _actionCard('Purchase', Icons.shopping_bag, cs.tertiary,
                    () => _openAddEntry(type: 'purchase', partyType: 'supplier')),
                _actionCard('Receive', Icons.download, cs.primary,
                    () => _openAddEntry(type: 'payment', partyType: 'customer')),
                _actionCard('Pay', Icons.upload, Colors.purple,
                    () => _openAddEntry(type: 'receipt', partyType: 'supplier')),
                _actionCard('Income', Icons.trending_up, Colors.teal,
                    () => _openAddEntry(type: 'income')),
                _actionCard('Expense', Icons.trending_down, Colors.deepOrange,
                    () => _openAddEntry(type: 'expense')),
              ],
            ),

            const SizedBox(height: 20),

            // ── Recent records ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Records',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
                TextButton(
                  onPressed: _viewAllEntries,
                  child:
                      Text('View All', style: TextStyle(color: cs.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            StreamBuilder<List<LedgerEntry>>(
              stream: _ledgerService.getLedgerEntries(limit: 5),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: cs.primary));
                }
                final entries = snap.data ?? [];
                if (entries.isEmpty) return _emptyState();
                return Column(
                  children: entries
                      .map((e) => _transactionTile(e, cs, isDark))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cash Book Tab
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCashBookTab() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: cs.primary,
      backgroundColor: cs.surface,
      child: StreamBuilder<List<LedgerEntry>>(
        stream: _ledgerService.getIncomeExpenseEntries(),
        builder: (context, snap) {
          final entries = snap.data ?? [];
          final totalIncome = entries
              .where((e) => e.type == 'income')
              .fold<double>(0, (s, e) => s + e.amount);
          final totalExpense = entries
              .where((e) => e.type == 'expense')
              .fold<double>(0, (s, e) => s + e.amount);
          final net = totalIncome - totalExpense;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              // ── Cash flow summary ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _cashCard('Income', totalIncome, Colors.teal,
                        Icons.trending_up,
                        isDark: isDark, cs: cs),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _cashCard('Expense', totalExpense, Colors.deepOrange,
                        Icons.trending_down,
                        isDark: isDark, cs: cs),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (net >= 0 ? Colors.green : Colors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (net >= 0 ? Colors.green : Colors.red)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Net Cash Flow',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: cs.onSurface)),
                    Flexible(
                      child: Text(
                        '${net >= 0 ? '+' : '-'}${_currency.format(net.abs())}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: net >= 0 ? Colors.green : Colors.red,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Entry list ─────────────────────────────────────────
              if (snap.connectionState == ConnectionState.waiting)
                Center(
                    child: CircularProgressIndicator(color: cs.primary))
              else if (entries.isEmpty)
                _cashBookEmptyState(cs)
              else
                ...entries.map((e) => _transactionTile(e, cs, isDark)),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Party List Tab (Customers / Suppliers)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPartyList(String partyType) {
    if (partyType == 'customer') {
      return StreamBuilder<List<Customer>>(
        stream: _customerService.getCustomers(),
        builder: (ctx, snap) => _partyListView(snap, partyType),
      );
    } else {
      return StreamBuilder<List<Supplier>>(
        stream: _supplierService.getSuppliers(),
        builder: (ctx, snap) => _partyListView(snap, partyType),
      );
    }
  }

  Widget _partyListView(AsyncSnapshot snap, String partyType) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCustomer = partyType == 'customer';

    if (snap.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (!snap.hasData || (snap.data as List).isEmpty) {
      return _emptyPartyState(partyType, cs);
    }

    final parties = snap.data as List;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: cs.primary,
      backgroundColor: cs.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: parties.length,
        itemBuilder: (ctx, i) {
          final party = parties[i];
          final partyId = party.id as String;
          final partyName = party.name as String;
          final contact = isCustomer
              ? (party as Customer).mobile
              : (party as Supplier).phone;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: isDark ? 4 : 2,
            color: cs.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  leading: CircleAvatar(
                    backgroundColor: (isCustomer ? cs.secondary : cs.tertiary)
                        .withValues(alpha: 0.2),
                    child: Icon(
                      isCustomer ? Icons.person : Icons.store,
                      color: isCustomer ? cs.secondary : cs.tertiary,
                    ),
                  ),
                  title: Text(partyName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(contact,
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.6),
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      FutureBuilder<double>(
                        future: _ledgerService.getPartyBalance(partyId),
                        builder: (ctx, balSnap) {
                          if (!balSnap.hasData) return const SizedBox.shrink();
                          final balance = balSnap.data!;
                          return Text(
                            balance >= 0
                                ? 'Owes you: ${_currency.format(balance)}'
                                : 'You owe: ${_currency.format(balance.abs())}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: balance >= 0 ? cs.secondary : cs.error,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  trailing: Icon(Icons.chevron_right,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                  onTap: () => _viewPartyLedger(party, partyType),
                ),
                FutureBuilder<List<LedgerEntry>>(
                  future:
                      _ledgerService.getPartyLedgerEntries(partyId, limit: 2),
                  builder: (ctx, snap) {
                    final entries = snap.data ?? [];
                    if (entries.isEmpty) return const SizedBox.shrink();

                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                              color: cs.outline.withValues(alpha: 0.2)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text('Recent Transactions',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.6))),
                          ),
                          ...entries.map((e) =>
                              _compactTransactionTile(e, cs)),
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 4),
                            child: TextButton(
                              onPressed: () =>
                                  _viewPartyLedger(party, partyType),
                              child: Text('View All',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.primary)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared widgets
  // ─────────────────────────────────────────────────────────────────────────

  Widget _transactionTile(LedgerEntry entry, ColorScheme cs, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isDark ? 4 : 1,
      color: cs.surface,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: entry.typeColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(entry.typeIcon, color: entry.typeColor, size: 20),
        ),
        title: Text(
          entry.partyName.isNotEmpty ? entry.partyName : entry.description,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: cs.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.partyName.isNotEmpty)
              Text(entry.description,
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            Text(_dateFormat.format(entry.date),
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5))),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currency.format(entry.amount),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: entry.isDebit() ? cs.secondary : cs.error),
            ),
            const SizedBox(height: 2),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: entry.statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: entry.statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(entry.statusLabel,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: entry.statusColor)),
            ),
          ],
        ),
        onTap: () => _showSimpleDetails(entry),
      ),
    );
  }

  Widget _compactTransactionTile(LedgerEntry entry, ColorScheme cs) {
    return InkWell(
      onTap: () => _showSimpleDetails(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: entry.typeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(entry.typeIcon, color: entry.typeColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.description,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(_dateFormat.format(entry.date),
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_currency.format(entry.amount),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color:
                            entry.isDebit() ? cs.secondary : cs.error)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: entry.statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(entry.statusLabel,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: entry.statusColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, double value, Color color, IconData icon,
      {required bool isDark, required ColorScheme cs}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isDark ? 4 : 2,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(_currency.format(value),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cashCard(String title, double value, Color color, IconData icon,
      {required bool isDark, required ColorScheme cs}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(_currency.format(value),
                style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isDark ? 4 : 2,
      color: cs.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 6),
              Text(title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.receipt_long,
              size: 70, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No records yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 8),
          Text('Add your first transaction',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _cashBookEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 70, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No income or expense recorded',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 8),
          Text('Use the buttons below to record income or expenses.',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5), fontSize: 14),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _emptyPartyState(String partyType, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              partyType == 'customer' ? Icons.person : Icons.store,
              size: 70,
              color: cs.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${partyType == 'customer' ? 'customers' : 'suppliers'} yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 8),
            Text(
              partyType == 'customer'
                  ? 'Add customers to track sales'
                  : 'Add suppliers to track purchases',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Detail bottom sheet
  // ─────────────────────────────────────────────────────────────────────────

  void _showSimpleDetails(LedgerEntry entry) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: entry.typeColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(entry.typeIcon, color: entry.typeColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.typeLabel,
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface)),
                          if (entry.partyName.isNotEmpty)
                            Text('with ${entry.partyName}',
                                style: TextStyle(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.7)))
                          else if (entry.category != null)
                            Text(entry.category!,
                                style: TextStyle(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: entry.statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: entry.statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(entry.statusLabel,
                          style: TextStyle(
                              color: entry.statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: cs.outline.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                _detailRow('Date', _dateFormat.format(entry.date), cs),
                _detailRow('Amount', _currency.format(entry.amount), cs),
                if (entry.description.isNotEmpty)
                  _detailRow('Description', entry.description, cs),
                if (entry.reference.isNotEmpty)
                  _detailRow('Reference', entry.reference, cs),
                if (entry.dueDate != null)
                  _detailRow(
                      'Due Date', _dateFormat.format(entry.dueDate!), cs),
                if (entry.notes.isNotEmpty)
                  _detailRow('Notes', entry.notes, cs),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: cs.outline),
                          foregroundColor: cs.onSurface,
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                    if (entry.status == 'pending') ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _markAsPaid(entry);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Mark Paid'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text('$label:',
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 14, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openAddEntry({String? type, String? partyType}) async {
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
    if (mounted) setState(() {});
  }

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

  Future<void> _markAsPaid(LedgerEntry entry) async {
    final cs = Theme.of(context).colorScheme;
    try {
      await _ledgerService.updateLedgerStatus(entry.id, 'paid');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Marked as paid'),
          backgroundColor: cs.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
