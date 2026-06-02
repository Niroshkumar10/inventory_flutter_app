import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_app/features/bill/services/bill_service.dart';
import 'package:inventory_app/features/bill/models/bill_model.dart';
import 'package:inventory_app/core/providers/app_providers.dart';
import 'package:inventory_app/features/bill/screens/add_edit_bill_screen.dart';
import 'package:inventory_app/features/bill/screens/view_bill_screen.dart';

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
      final first = DateTime(now.year, now.month - 1, 1);
      final last  = DateTime(now.year, now.month, 0, 23, 59, 59);
      return (first, last);
    case 'year':
      return (DateTime(now.year, 1, 1), now);
    default:
      return (DateTime(2000), now);
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class TransactionsDashboardScreen extends StatefulWidget {
  final String userMobile;
  const TransactionsDashboardScreen({super.key, required this.userMobile});

  @override
  State<TransactionsDashboardScreen> createState() =>
      _TransactionsDashboardScreenState();
}

class _TransactionsDashboardScreenState
    extends State<TransactionsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final BillService _billService;
  late final TabController _tabController;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _billService = BillService(widget.userMobile);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addBill(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppProviders(
          userMobile: widget.userMobile,
          child: AddEditBillScreen(
            type: type,
            userMobile: widget.userMobile,
            billService: _billService,
          ),
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
        title: Text('Transactions',
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
            Tab(icon: Icon(Icons.trending_up, size: 18), text: 'Sales'),
            Tab(icon: Icon(Icons.trending_down, size: 18), text: 'Purchases'),
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
                _BillList(
                  billService: _billService,
                  type: 'sales',
                  userMobile: widget.userMobile,
                  startDate: start,
                  endDate: end,
                ),
                _BillList(
                  billService: _billService,
                  type: 'purchase',
                  userMobile: widget.userMobile,
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
          final isSales = _tabController.index == 0;
          return FloatingActionButton.extended(
            onPressed: () => _addBill(isSales ? 'sales' : 'purchase'),
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              isSales ? 'Add Sale' : 'Add Purchase',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: isSales ? cs.secondary : cs.tertiary,
          );
        },
      ),
    );
  }
}

// ─── Bill list ────────────────────────────────────────────────────────────────

class _BillList extends StatelessWidget {
  final BillService billService;
  final String type;
  final String userMobile;
  final DateTime startDate;
  final DateTime endDate;

  const _BillList({
    required this.billService,
    required this.type,
    required this.userMobile,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSales = type == 'sales';
    final accentColor = isSales ? cs.secondary : cs.tertiary;

    return StreamBuilder<List<Bill>>(
      stream: billService.getBills(filter: type),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: cs.primary));
        }

        // Apply date filter
        final bills = (snap.data ?? [])
            .where((b) =>
                !b.date.isBefore(startDate) && !b.date.isAfter(endDate))
            .toList();

        final total = bills.fold<double>(0, (s, b) => s + b.totalAmount);
        final due   = bills.fold<double>(0, (s, b) => s + b.amountDue);

        return Column(
          children: [
            Container(
              color: cs.surface,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  _SummaryChip(
                    label: isSales ? 'Total Sales' : 'Total Purchases',
                    value: '₹${NumberFormat('#,##0').format(total)}',
                    color: accentColor,
                  ),
                  const SizedBox(width: 12),
                  _SummaryChip(
                    label: 'Outstanding',
                    value: '₹${NumberFormat('#,##0').format(due)}',
                    color: cs.error,
                  ),
                  const Spacer(),
                  Text('${bills.length} bills',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: bills.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSales
                                ? Icons.shopping_bag_outlined
                                : Icons.inventory_2_outlined,
                            size: 56,
                            color: cs.onSurface.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isSales ? 'No sales found' : 'No purchases found',
                            style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.45),
                                fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: bills.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final bill = bills[i];
                        final isPaid    = bill.amountDue <= 0;
                        final isPartial = bill.amountPaid > 0 && bill.amountDue > 0;
                        final statusColor = isPaid
                            ? cs.secondary
                            : isPartial
                                ? cs.primary
                                : cs.error;
                        final statusLabel =
                            isPaid ? 'Paid' : isPartial ? 'Partial' : 'Due';

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
                              backgroundColor: accentColor.withValues(alpha: 0.12),
                              child: Icon(
                                isSales
                                    ? Icons.shopping_bag
                                    : Icons.inventory_2,
                                color: accentColor,
                                size: 20,
                              ),
                            ),
                            title: Text(bill.invoiceNumber,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                              '${bill.partyName}  •  ${DateFormat('dd MMM yyyy').format(bill.date)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.55)),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${NumberFormat('#,##0').format(bill.totalAmount)}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: accentColor),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(statusLabel,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: statusColor,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ViewBillScreen(
                                    billId: bill.id, userMobile: userMobile),
                              ),
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

// ─── Shared filter chip row ───────────────────────────────────────────────────

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
                    color: isActive ? Colors.white : cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                selected: isActive,
                selectedColor: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
                side: BorderSide(
                  color: isActive ? cs.primary : cs.outline.withValues(alpha: 0.3),
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

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        Text(value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
