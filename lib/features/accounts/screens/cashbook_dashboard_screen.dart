import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_app/features/ledger/services/ledger_service.dart';
import 'package:inventory_app/features/ledger/models/ledger_model.dart';
import 'package:inventory_app/features/ledger/screens/add_ledger_entry_screen.dart';
import 'package:inventory_app/core/theme/colors.dart';

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

class CashBookDashboardScreen extends StatefulWidget {
  final String userMobile;
  const CashBookDashboardScreen({super.key, required this.userMobile});

  @override
  State<CashBookDashboardScreen> createState() =>
      _CashBookDashboardScreenState();
}

class _CashBookDashboardScreenState extends State<CashBookDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final LedgerService _ledgerService;
  late final TabController _tabController;
  final _fmt = NumberFormat('#,##0.00', 'en_IN');
  String _filter = 'all';

  // tab indices: 0 = All, 1 = Income, 2 = Expense
  @override
  void initState() {
    super.initState();
    _ledgerService = LedgerService(widget.userMobile);
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addEntry(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLedgerEntryScreen(
          userMobile: widget.userMobile,
          initialType: type,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _showAddEntryPicker() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: cs.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Add Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
                  child: Icon(Icons.add_circle_outline, color: AppColors.secondary),
                ),
                title: const Text('Add Income', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context); _addEntry('income'); },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.error.withValues(alpha: 0.12),
                  child: Icon(Icons.remove_circle_outline, color: AppColors.error),
                ),
                title: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context); _addEntry('expense'); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabIndex = _tabController.index;
    final (start, end) = _dateRange(_filter);

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text('Cash Book',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(color: cs.onSurface),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: StreamBuilder<List<LedgerEntry>>(
            stream: _ledgerService.getIncomeExpenseEntries(),
            builder: (context, snap) {
              final entries = snap.data ?? [];
              final income  = entries.where((e) => e.type == 'income').fold<double>(0, (s, e) => s + e.amount);
              final expense = entries.where((e) => e.type == 'expense').fold<double>(0, (s, e) => s + e.amount);
              final net = income - expense;
              return Container(
                color: cs.surface,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    _NetChip(label: 'Income', value: income, color: AppColors.secondary, fmt: _fmt),
                    const SizedBox(width: 16),
                    _NetChip(label: 'Expense', value: expense, color: AppColors.error, fmt: _fmt),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Net Balance', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                        Text(
                          '₹${_fmt.format(net)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: net >= 0 ? AppColors.secondary : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      body: Column(
        children: [
          // Tab bar — All | Income | Expense
          Container(
            color: cs.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
              indicatorColor: cs.primary,
              tabs: const [
                Tab(icon: Icon(Icons.list_alt, size: 18), text: 'All'),
                Tab(icon: Icon(Icons.add_circle_outline, size: 18), text: 'Income'),
                Tab(icon: Icon(Icons.remove_circle_outline, size: 18), text: 'Expense'),
              ],
            ),
          ),
          // ── Date filter chips ──────────────────────────────────────────
          Container(
            color: cs.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _kFilters.map((f) {
                  final isActive = _filter == f['value'];
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
                      onSelected: (_) => setState(() => _filter = f['value']!),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CashEntryList(ledgerService: _ledgerService, type: 'all',     fmt: _fmt, startDate: start, endDate: end),
                _CashEntryList(ledgerService: _ledgerService, type: 'income',  fmt: _fmt, startDate: start, endDate: end),
                _CashEntryList(ledgerService: _ledgerService, type: 'expense', fmt: _fmt, startDate: start, endDate: end),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          // All tab → picker; Income/Expense → direct action
          if (tabIndex == 0) {
            return FloatingActionButton.extended(
              onPressed: _showAddEntryPicker,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              backgroundColor: cs.primary,
            );
          }
          final isIncome = tabIndex == 1;
          return FloatingActionButton.extended(
            onPressed: () => _addEntry(isIncome ? 'income' : 'expense'),
            icon: Icon(
              isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
              color: Colors.white,
            ),
            label: Text(
              isIncome ? 'Add Income' : 'Add Expense',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: isIncome ? AppColors.secondary : AppColors.error,
          );
        },
      ),
    );
  }
}

// ─── Entry list (supports type: 'all' | 'income' | 'expense') ────────────────

class _CashEntryList extends StatelessWidget {
  final LedgerService ledgerService;
  final String type; // 'all' | 'income' | 'expense'
  final NumberFormat fmt;
  final DateTime startDate;
  final DateTime endDate;

  const _CashEntryList({
    required this.ledgerService,
    required this.type,
    required this.fmt,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAll     = type == 'all';
    final isIncome  = type == 'income';

    return StreamBuilder<List<LedgerEntry>>(
      stream: ledgerService.getIncomeExpenseEntries(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: cs.primary));
        }

        final all     = snap.data ?? [];
        // Filter by type and date range, sorted newest first
        final entries = (isAll
                ? List<LedgerEntry>.from(all)
                : all.where((e) => e.type == type).toList())
            .where((e) =>
                !e.date.isBefore(startDate) && !e.date.isAfter(endDate))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final total = entries.fold<double>(0, (s, e) => s + e.amount);

        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isAll
                      ? Icons.list_alt
                      : isIncome
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                  size: 56,
                  color: cs.onSurface.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  isAll
                      ? 'No entries yet'
                      : isIncome
                          ? 'No income entries'
                          : 'No expense entries',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45), fontSize: 15),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Summary bar
            Container(
              color: cs.surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Text(
                    isAll ? 'All Entries:' : 'Total ${isIncome ? 'Income' : 'Expense'}:',
                    style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(width: 8),
                  if (!isAll)
                    Text(
                      '₹${fmt.format(total)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isIncome ? AppColors.secondary : AppColors.error,
                      ),
                    ),
                  const Spacer(),
                  Text('${entries.length} entries',
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  final entryIsIncome = e.type == 'income';
                  final color = entryIsIncome ? AppColors.secondary : AppColors.error;

                  return Card(
                    elevation: 0,
                    color: cs.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Icon(
                          entryIsIncome ? Icons.arrow_downward : Icons.arrow_upward,
                          color: color,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        e.description.isNotEmpty
                            ? e.description
                            : (entryIsIncome ? 'Income' : 'Expense'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy').format(e.date),
                            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                          ),
                          if (isAll) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                entryIsIncome ? 'Income' : 'Expense',
                                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Text(
                        '₹${fmt.format(e.amount)}',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color),
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

class _NetChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final NumberFormat fmt;
  const _NetChip({required this.label, required this.value, required this.color, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        Text('₹${fmt.format(value)}',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
