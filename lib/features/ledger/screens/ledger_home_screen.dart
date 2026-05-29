import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ledger_service.dart';
import '../models/ledger_model.dart';
import '../../party/services/customer_service.dart';
import '../../party/services/supplier_service.dart';
import '../../party/models/customer_model.dart';
import '../../party/models/supplier_model.dart';
import 'add_ledger_entry_screen.dart';
import 'party_ledger_screen.dart';
import 'outstanding_dues_screen.dart';
import 'package:inventory_app/core/theme/colors.dart';

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
  final _fmt = NumberFormat('#,##0.00', 'en_IN');
  final _dateFmt = DateFormat('dd MMM');

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

  // ─── FAB — one clear action per tab ───────────────────────────────────────

  Widget? _buildFab(ColorScheme cs) {
    switch (_currentTab) {
      case 0:
        return FloatingActionButton.extended(
          heroTag: 'fab_home',
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: cs.primary,
          onPressed: _showAddEntrySheet,
        );
      case 1:
        return FloatingActionButton.extended(
          heroTag: 'fab_cust',
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Sale', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: cs.secondary,
          onPressed: () => _openAddEntry(type: 'sale', partyType: 'customer'),
        );
      case 2:
        return FloatingActionButton.extended(
          heroTag: 'fab_supp',
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Purchase', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: cs.tertiary,
          onPressed: () => _openAddEntry(type: 'purchase', partyType: 'supplier'),
        );
      case 3:
        return FloatingActionButton.extended(
          heroTag: 'fab_cash',
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Add Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.secondary,
          onPressed: () => _showCashEntrySheet(),
        );
      default:
        return null;
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : AppColors.background,
      appBar: AppBar(
        backgroundColor: cs.primary,
        title: const Text('Accounts Book',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Home'),
            Tab(text: 'Customers'),
            Tab(text: 'Suppliers'),
            Tab(text: 'Cash Book'),
          ],
        ),
      ),
      floatingActionButton: _buildFab(cs),
      body: TabBarView(
        controller: _tabController,
        children: [
          _homeTab(),
          _partyTab('customer'),
          _partyTab('supplier'),
          _cashBookTab(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HOME TAB
  // ─────────────────────────────────────────────────────────────────────────

  Widget _homeTab() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: cs.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Money snapshot ─────────────────────────────────────────
            FutureBuilder<Map<String, dynamic>>(
              future: _ledgerService.getStatistics(),
              builder: (context, snap) {
                final stats = snap.data ?? {};
                final toCollect = (stats['totalSales'] as num? ?? 0).toDouble();
                final toPay     = (stats['totalPurchases'] as num? ?? 0).toDouble();
                final net       = toCollect - toPay;
                final loading   = snap.connectionState == ConnectionState.waiting;

                return Column(
                  children: [
                    // Net balance big card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: net >= 0
                              ? [const Color(0xFF047857), AppColors.success]
                              : [const Color(0xFFB91C1C), AppColors.error],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (net >= 0 ? AppColors.success : AppColors.error)
                                .withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                net >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                                color: Colors.white70,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                net >= 0 ? 'You are in Profit' : 'You Need to Pay',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          loading
                              ? const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                              : FittedBox(
                                  child: Text(
                                    '₹${_fmt.format(net.abs())}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 6),
                          Text(
                            net >= 0
                                ? 'Total money people owe you'
                                : 'Total money you owe others',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // To Collect + To Pay row
                    Row(
                      children: [
                        Expanded(
                          child: _balanceCard(
                            label: 'To Collect',
                            sublabel: 'From customers',
                            amount: toCollect,
                            color: AppColors.success,
                            icon: Icons.call_received,
                            loading: loading,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _balanceCard(
                            label: 'To Pay',
                            sublabel: 'To suppliers',
                            amount: toPay,
                            color: cs.error,
                            icon: Icons.call_made,
                            loading: loading,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // ── Pending dues alert ─────────────────────────────────────
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
                            userMobile: widget.userMobile)),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$count payment${count == 1 ? '' : 's'} still pending — tap to see',
                            style: const TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.warning),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Recent records ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Transactions',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 10),

            StreamBuilder<List<LedgerEntry>>(
              stream: _ledgerService.getLedgerEntries(limit: 8),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: cs.primary),
                  ));
                }
                final entries = snap.data ?? [];
                if (entries.isEmpty) return _emptyRecordsWidget(cs);
                return Column(
                    children: entries.map((e) => _entryTile(e, cs, isDark)).toList());
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CUSTOMERS / SUPPLIERS TAB
  // ─────────────────────────────────────────────────────────────────────────

  Widget _partyTab(String type) {
    final isCustomer = type == 'customer';
    if (isCustomer) {
      return StreamBuilder<List<Customer>>(
        stream: _customerService.getCustomers(),
        builder: (ctx, snap) => _partyListView(snap, type),
      );
    }
    return StreamBuilder<List<Supplier>>(
      stream: _supplierService.getSuppliers(),
      builder: (ctx, snap) => _partyListView(snap, type),
    );
  }

  Widget _partyListView(AsyncSnapshot snap, String type) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCustomer = type == 'customer';
    final accentColor = isCustomer ? cs.secondary : cs.tertiary;

    if (snap.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (!snap.hasData || (snap.data as List).isEmpty) {
      return _emptyPartyWidget(type, cs);
    }

    final parties = snap.data as List;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: cs.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: parties.length,
        itemBuilder: (ctx, i) {
          final party = parties[i];
          final name    = party.name as String;
          final contact = isCustomer ? (party as Customer).mobile : (party as Supplier).phone;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: isDark ? 3 : 1,
            color: cs.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openPartyLedger(party, type),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: accentColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: cs.onSurface)),
                          const SizedBox(height: 2),
                          Text(contact,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.55))),
                        ],
                      ),
                    ),

                    // Balance
                    FutureBuilder<double>(
                      future: _ledgerService.getPartyBalance(party.id as String),
                      builder: (ctx, balSnap) {
                        if (!balSnap.hasData) {
                          return SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: cs.outline));
                        }
                        final bal = balSnap.data!;
                        final isPositive = bal >= 0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${_fmt.format(bal.abs())}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isPositive ? AppColors.success : cs.error),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isPositive ? AppColors.success : cs.error)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                bal == 0
                                    ? 'Settled'
                                    : isPositive
                                        ? 'Owes You'
                                        : 'You Owe',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isPositive ? AppColors.success : cs.error),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        color: cs.onSurface.withValues(alpha: 0.3), size: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CASH BOOK TAB
  // ─────────────────────────────────────────────────────────────────────────

  Widget _cashBookTab() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<LedgerEntry>>(
      stream: _ledgerService.getIncomeExpenseEntries(),
      builder: (context, snap) {
        final entries = snap.data ?? [];
        final income  = entries.where((e) => e.type == 'income').fold<double>(0, (s, e) => s + e.amount);
        final expense = entries.where((e) => e.type == 'expense').fold<double>(0, (s, e) => s + e.amount);
        final net = income - expense;

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          color: cs.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Summary row
              Row(
                children: [
                  Expanded(
                    child: _cashSummaryCard(
                      label: 'Money In',
                      amount: income,
                      color: AppColors.secondary,
                      icon: Icons.south_west,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _cashSummaryCard(
                      label: 'Money Out',
                      amount: expense,
                      color: AppColors.error,
                      icon: Icons.north_east,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Net balance
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: (net >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: (net >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Net Balance',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            fontSize: 15)),
                    Text(
                      '${net >= 0 ? '+' : '-'} ₹${_fmt.format(net.abs())}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: net >= 0 ? AppColors.success : AppColors.error),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text('Transactions',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
              const SizedBox(height: 10),

              if (snap.connectionState == ConnectionState.waiting)
                Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: cs.primary),
                ))
              else if (entries.isEmpty)
                _cashEmptyWidget(cs)
              else
                ...entries.map((e) => _entryTile(e, cs, isDark)),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared widgets
  // ─────────────────────────────────────────────────────────────────────────

  Widget _balanceCard({
    required String label,
    required String sublabel,
    required double amount,
    required Color color,
    required IconData icon,
    required bool loading,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(sublabel,
              style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.45))),
          const SizedBox(height: 8),
          loading
              ? SizedBox(height: 20, child: LinearProgressIndicator(color: color, backgroundColor: color.withValues(alpha: 0.1)))
              : FittedBox(
                  child: Text(
                    '₹${_fmt.format(amount)}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _cashSummaryCard({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              '₹${_fmt.format(amount)}',
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryTile(LedgerEntry entry, ColorScheme cs, bool isDark) {
    final isIncoming = entry.isDebit();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isDark ? 2 : 0.5,
      color: cs.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEntryDetails(entry, cs),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Type icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: entry.typeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Icon(entry.typeIcon, color: entry.typeColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Description + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.partyName.isNotEmpty ? entry.partyName : entry.description,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.partyName.isNotEmpty
                          ? '${entry.description}  •  ${_dateFmt.format(entry.date)}'
                          : _dateFmt.format(entry.date),
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.5)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Amount + status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${isIncoming ? '+' : '-'} ₹${_fmt.format(entry.amount)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isIncoming ? AppColors.success : cs.error),
                  ),
                  const SizedBox(height: 3),
                  if (entry.status == 'pending')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('Pending',
                          style: TextStyle(
                              fontSize: 9,
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('Paid',
                          style: TextStyle(
                              fontSize: 9,
                              color: AppColors.success,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Entry detail bottom sheet — simple, shop-friendly
  // ─────────────────────────────────────────────────────────────────────────

  void _showEntryDetails(LedgerEntry entry, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),

                // Header row
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: entry.typeColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle),
                      child: Icon(entry.typeIcon, color: entry.typeColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.typeLabel,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface)),
                          if (entry.partyName.isNotEmpty)
                            Text(entry.partyName,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurface.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                    Text(
                      '₹${_fmt.format(entry.amount)}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: entry.isDebit() ? AppColors.success : cs.error),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(color: cs.outline.withValues(alpha: 0.2)),
                const SizedBox(height: 8),

                // Simple detail rows
                _row('Date', DateFormat('dd MMM yyyy').format(entry.date), cs),
                if (entry.description.isNotEmpty)
                  _row('Note', entry.description, cs),
                if (entry.reference.isNotEmpty)
                  _row('Ref', entry.reference, cs),
                if (entry.dueDate != null)
                  _row('Due', DateFormat('dd MMM yyyy').format(entry.dueDate!), cs),
                _row('Status', entry.status == 'pending' ? 'Pending' : 'Paid', cs,
                    valueColor: entry.status == 'pending' ? AppColors.warning : AppColors.success),

                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: cs.outline),
                            foregroundColor: cs.onSurface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: const Text('Close'),
                      ),
                    ),
                    if (entry.status == 'pending') ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _markPaid(entry);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10))),
                          child: const Text('Mark as Paid'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, ColorScheme cs, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.5))),
          ),
          Text('  :  ',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.3), fontSize: 13)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? cs.onSurface)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Add entry sheets
  // ─────────────────────────────────────────────────────────────────────────

  void _showAddEntrySheet() {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('What do you want to record?',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const SizedBox(height: 20),

            _sheetOption(
              ctx: ctx,
              icon: Icons.shopping_cart_outlined,
              title: 'Sold to Customer',
              subtitle: 'Customer bought something from your shop',
              color: cs.secondary,
              onTap: () => _openAddEntry(type: 'sale', partyType: 'customer'),
            ),
            const SizedBox(height: 10),
            _sheetOption(
              ctx: ctx,
              icon: Icons.storefront_outlined,
              title: 'Bought from Supplier',
              subtitle: 'You purchased goods or items',
              color: cs.tertiary,
              onTap: () => _openAddEntry(type: 'purchase', partyType: 'supplier'),
            ),
            const SizedBox(height: 10),
            _sheetOption(
              ctx: ctx,
              icon: Icons.call_received,
              title: 'Customer Paid Me',
              subtitle: 'Received payment from a customer',
              color: AppColors.success,
              onTap: () => _openAddEntry(type: 'payment', partyType: 'customer'),
            ),
            const SizedBox(height: 10),
            _sheetOption(
              ctx: ctx,
              icon: Icons.call_made,
              title: 'I Paid Supplier',
              subtitle: 'Sent payment to a supplier',
              color: AppColors.warning,
              onTap: () => _openAddEntry(type: 'receipt', partyType: 'supplier'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCashEntrySheet() {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Cash Book Entry',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const SizedBox(height: 20),

            _sheetOption(
              ctx: ctx,
              icon: Icons.south_west,
              title: 'Money Came In',
              subtitle: 'Any income — rent, interest, other earnings',
              color: AppColors.secondary,
              onTap: () => _openAddEntry(type: 'income'),
            ),
            const SizedBox(height: 10),
            _sheetOption(
              ctx: ctx,
              icon: Icons.north_east,
              title: 'Money Went Out',
              subtitle: 'Any expense — electricity, rent, staff salary',
              color: AppColors.error,
              onTap: () => _openAddEntry(type: 'expense'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetOption({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.55))),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: cs.onSurface.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Empty states
  // ─────────────────────────────────────────────────────────────────────────

  Widget _emptyRecordsWidget(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No transactions yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          Text('Tap "+ Add Entry" to record your first transaction',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.35)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _cashEmptyWidget(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No cash entries yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          Text('Tap "+ Add Entry" below to record income or expense',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.35)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _emptyPartyWidget(String type, ColorScheme cs) {
    final isCustomer = type == 'customer';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isCustomer ? Icons.people_outline : Icons.store_outlined,
                size: 64, color: cs.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(isCustomer ? 'No customers yet' : 'No suppliers yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 6),
            Text(
              isCustomer
                  ? 'Add customers from the Parties menu'
                  : 'Add suppliers from the Parties menu',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.35)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation / service helpers
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

  void _openPartyLedger(dynamic party, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartyLedgerScreen(
          userMobile: widget.userMobile,
          party: party,
          partyType: type,
        ),
      ),
    );
  }

  Future<void> _markPaid(LedgerEntry entry) async {
    final cs = Theme.of(context).colorScheme;
    try {
      await _ledgerService.updateLedgerStatus(entry.id, 'paid');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Marked as paid'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
