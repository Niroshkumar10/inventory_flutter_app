import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_app/features/ledger/services/ledger_service.dart';
import 'package:inventory_app/features/ledger/models/ledger_model.dart';
import 'package:inventory_app/features/ledger/screens/add_ledger_entry_screen.dart';

// ─── Filter helpers ───────────────────────────────────────────────────────────

const _kFilters = [
  {'label': 'All',        'value': 'all'},
  {'label': 'This Week',  'value': 'week'},
  {'label': 'This Month', 'value': 'month'},
  {'label': 'Last Month', 'value': 'last_month'},
  {'label': 'This Year',  'value': 'year'},
];

(DateTime start, DateTime end) _dateRange(String filter) {
  final now = DateTime.now();
  switch (filter) {
    case 'week':
      return (now.subtract(const Duration(days: 7)), now);
    case 'month':
      return (DateTime(now.year, now.month, 1), now);
    case 'last_month':
      return (
        DateTime(now.year, now.month - 1, 1),
        DateTime(now.year, now.month, 0, 23, 59, 59),
      );
    case 'year':
      return (DateTime(now.year, 1, 1), now);
    default:
      return (DateTime(2000), now);
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class BorrowsDashboardScreen extends StatefulWidget {
  final String userMobile;
  const BorrowsDashboardScreen({super.key, required this.userMobile});

  @override
  State<BorrowsDashboardScreen> createState() => _BorrowsDashboardScreenState();
}

class _BorrowsDashboardScreenState extends State<BorrowsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final LedgerService _ledgerService;
  late final TabController _tabController;
  final _fmt = NumberFormat('#,##0.00', 'en_IN');
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _ledgerService = LedgerService(widget.userMobile);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addEntry(String partyType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLedgerEntryScreen(
          userMobile: widget.userMobile,
          initialPartyType: partyType,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (start, end) = _dateRange(_filter);

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text('Dues & Borrowing',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(color: cs.onSurface),
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
          indicatorColor: cs.primary,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Customer Paid Me'),
            Tab(icon: Icon(Icons.local_shipping_outlined, size: 18), text: 'I Paid Supplier'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Date filter chips ────────────────────────────────────────────
          _FilterChipRow(
            filters: _kFilters,
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const Divider(height: 1),
          // ── Tab content ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _EntryList(
                  ledgerService: _ledgerService,
                  partyType: 'customer',
                  fmt: _fmt,
                  startDate: start,
                  endDate: end,
                ),
                _EntryList(
                  ledgerService: _ledgerService,
                  partyType: 'supplier',
                  fmt: _fmt,
                  startDate: start,
                  endDate: end,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final isCustomer = _tabController.index == 0;
          return FloatingActionButton.extended(
            onPressed: () => _addEntry(isCustomer ? 'customer' : 'supplier'),
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              isCustomer ? 'Customer Paid Me' : 'I Paid Supplier',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: isCustomer ? Colors.green : Colors.orange,
          );
        },
      ),
    );
  }
}

// ─── Entry list ───────────────────────────────────────────────────────────────

class _EntryList extends StatelessWidget {
  final LedgerService ledgerService;
  final String partyType;
  final NumberFormat fmt;
  final DateTime startDate;
  final DateTime endDate;

  const _EntryList({
    required this.ledgerService,
    required this.partyType,
    required this.fmt,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCustomer = partyType == 'customer';
    final accentColor = isCustomer ? Colors.green : Colors.orange;

    return StreamBuilder<List<LedgerEntry>>(
      stream: ledgerService.getLedgerEntries(partyType: partyType),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: cs.primary));
        }

        // Apply date filter
        final entries = (snap.data ?? [])
            .where((e) =>
                !e.date.isBefore(startDate) && !e.date.isAfter(endDate))
            .toList();

        final totalAmt = entries.fold<double>(0, (s, e) => s + e.amount);
        final pending  = entries.where((e) => e.balance > 0).length;

        return Column(
          children: [
            Container(
              color: cs.surface,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  _Chip(
                    label: isCustomer ? 'Total Receivable' : 'Total Payable',
                    value: '₹${fmt.format(totalAmt)}',
                    color: accentColor,
                  ),
                  const SizedBox(width: 16),
                  _Chip(
                    label: 'Pending',
                    value: '$pending',
                    color: cs.error,
                  ),
                  const Spacer(),
                  Text('${entries.length} entries',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCustomer
                                ? Icons.person_outline
                                : Icons.local_shipping_outlined,
                            size: 56,
                            color: cs.onSurface.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isCustomer
                                ? 'No customer dues found'
                                : 'No supplier dues found',
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.45),
                                fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final isSettled = e.balance <= 0;

                        return Card(
                          elevation: 0,
                          color: cs.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: cs.outline.withValues(alpha: 0.15)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  accentColor.withValues(alpha: 0.12),
                              child: Text(
                                e.partyName.isNotEmpty
                                    ? e.partyName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ),
                            title: Text(e.partyName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                              DateFormat('dd MMM yyyy').format(e.date),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.5)),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${fmt.format(e.amount)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: accentColor)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isSettled ? cs.secondary : cs.error)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isSettled ? 'Settled' : 'Pending',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isSettled
                                            ? cs.secondary
                                            : cs.error,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _FilterChipRow extends StatelessWidget {
  final List<Map<String, String>> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChipRow({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isActive = selected == f['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  f['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                selected: isActive,
                selectedColor: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
                side: BorderSide(
                  color: isActive
                      ? cs.primary
                      : cs.outline.withValues(alpha: 0.3),
                ),
                onSelected: (_) => onSelected(f['value']!),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5))),
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
