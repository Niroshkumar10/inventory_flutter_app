import 'package:flutter/material.dart';
import '../services/ledger_service.dart';
import '../models/ledger_model.dart';
import 'add_ledger_entry_screen.dart';

class LedgerListScreen extends StatefulWidget {
  final String userMobile;
  final String? partyId;
  final String? partyType;

  const LedgerListScreen({
    super.key,
    required this.userMobile,
    this.partyId,
    this.partyType,
  });

  @override
  State<LedgerListScreen> createState() => _LedgerListScreenState();
}

class _LedgerListScreenState extends State<LedgerListScreen> {
  late final LedgerService _ledgerService;

  String _search = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String? _typeFilter;   // null = all
  String? _statusFilter; // null = all

  // type filter options: value → label
  static const _typeOptions = {
    null: 'All',
    'sale': 'Sale',
    'purchase': 'Purchase',
    'payment': 'Received',
    'receipt': 'Paid',
    'income': 'Income',
    'expense': 'Expense',
  };

  // status filter options
  static const _statusOptions = {
    null: 'All Status',
    'pending': 'Pending',
    'paid': 'Paid',
    'overdue': 'Overdue',
    'cancelled': 'Cancelled',
  };

  @override
  void initState() {
    super.initState();
    _ledgerService = LedgerService(widget.userMobile);
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? cs.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text('All Ledger Entries',
            style: TextStyle(color: cs.onSurface)),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: cs.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt, color: cs.onSurface),
            onPressed: _showDateFilterDialog,
            tooltip: 'Date filter',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Search by party or description',
                hintStyle:
                    TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search,
                    color: cs.onSurface.withValues(alpha: 0.5)),
                filled: true,
                fillColor: isDark ? cs.surfaceContainerHighest : Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 1.5)),
              ),
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
            ),
          ),

          // ── Type filter chips ─────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _typeOptions.entries.map((entry) {
                final isSelected = _typeFilter == entry.key;
                final color = _typeColor(entry.key);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? color : cs.onSurface.withValues(alpha: 0.7),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        )),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _typeFilter = entry.key),
                    backgroundColor: isDark
                        ? cs.surfaceContainerHighest
                        : Colors.grey.shade100,
                    selectedColor: color.withValues(alpha: 0.15),
                    checkmarkColor: color,
                    side: BorderSide(
                        color: isSelected ? color : cs.outline,
                        width: isSelected ? 1.5 : 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Status filter chips ───────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: _statusOptions.entries.map((entry) {
                final isSelected = _statusFilter == entry.key;
                final color = _statusColor(entry.key);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? color : cs.onSurface.withValues(alpha: 0.7),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        )),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _statusFilter = entry.key),
                    backgroundColor: isDark
                        ? cs.surfaceContainerHighest
                        : Colors.grey.shade100,
                    selectedColor: color.withValues(alpha: 0.15),
                    checkmarkColor: color,
                    side: BorderSide(
                        color: isSelected ? color : cs.outline,
                        width: isSelected ? 1.5 : 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Active date filter badge ───────────────────────────────────
          if (_startDate != null || _endDate != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      '${_startDate != null ? _formatDate(_startDate!) : 'Start'} → ${_endDate != null ? _formatDate(_endDate!) : 'End'}',
                      style: TextStyle(color: cs.primary, fontSize: 12),
                    ),
                    backgroundColor: cs.primary.withValues(alpha: 0.1),
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearFilters,
                    child: Text('Clear All',
                        style: TextStyle(color: cs.primary, fontSize: 12)),
                  ),
                ],
              ),
            ),

          // ── Entry list ────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<LedgerEntry>>(
              stream: _ledgerService.getLedgerEntries(
                partyId: widget.partyId,
                partyType: widget.partyType,
                type: _typeFilter,
                startDate: _startDate,
                endDate: _endDate,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: cs.primary));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: cs.error, size: 50),
                        const SizedBox(height: 10),
                        Text('Error: ${snapshot.error}',
                            style: TextStyle(color: cs.onSurface)),
                      ],
                    ),
                  );
                }

                var entries = snapshot.data ?? [];

                // client-side search
                if (_search.isNotEmpty) {
                  entries = entries
                      .where((e) =>
                          e.partyName
                              .toLowerCase()
                              .contains(_search) ||
                          e.description
                              .toLowerCase()
                              .contains(_search) ||
                          e.reference
                              .toLowerCase()
                              .contains(_search))
                      .toList();
                }

                // client-side status filter (overdue is computed)
                if (_statusFilter != null) {
                  entries = entries.where((e) {
                    if (_statusFilter == 'overdue') return e.isOverdue;
                    return e.status == _statusFilter && !e.isOverdue;
                  }).toList();
                }

                if (entries.isEmpty) return _emptyState(cs);

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  color: cs.primary,
                  backgroundColor: cs.surface,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    itemBuilder: (ctx, i) => _entryCard(entries[i], cs, isDark),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Card
  // ─────────────────────────────────────────────────────────────────────────

  Widget _entryCard(LedgerEntry entry, ColorScheme cs, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 4 : 2,
      color: cs.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.typeColor.withValues(alpha: 0.2),
          child: Icon(entry.typeIcon, color: entry.typeColor, size: 20),
        ),
        title: Text(
          entry.partyName.isNotEmpty ? entry.partyName : entry.description,
          style:
              TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(entry.typeLabel,
                      style: TextStyle(
                          color: entry.typeColor, fontSize: 10)),
                  backgroundColor: entry.typeColor.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 0),
                  side: BorderSide(
                      color: entry.typeColor.withValues(alpha: 0.3)),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                // status badge
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
                          color: entry.statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(_formatDate(entry.date),
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5))),
            if (entry.dueDate != null && entry.status == 'pending')
              Text(
                'Due: ${_formatDate(entry.dueDate!)}',
                style: TextStyle(
                    fontSize: 11,
                    color: entry.isOverdue ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.w500),
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
                color: entry.isDebit() ? cs.secondary : cs.error,
                fontSize: 16,
              ),
            ),
            if (entry.isPartyTransaction)
              Text(
                'Bal: ₹${entry.balance.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 11,
                    color: entry.balance >= 0 ? cs.secondary : cs.error),
              ),
          ],
        ),
        onTap: () => _showEntryDetails(entry),
        onLongPress: () => _showActionMenu(entry),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dialogs / Actions
  // ─────────────────────────────────────────────────────────────────────────

  void _showEntryDetails(LedgerEntry entry) {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Transaction Details',
            style: TextStyle(color: cs.onSurface)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Date', _formatDate(entry.date), cs),
              _detailRow('Type', entry.typeLabel, cs),
              if (entry.partyName.isNotEmpty)
                _detailRow('Party', entry.partyName, cs),
              _detailRow('Description', entry.description, cs),
              _detailRow('Reference',
                  entry.reference.isNotEmpty ? entry.reference : 'N/A', cs),
              _detailRow(
                  'Amount', '₹${entry.amount.toStringAsFixed(2)}', cs),
              if (entry.isPartyTransaction)
                _detailRow('Balance',
                    '₹${entry.balance.toStringAsFixed(2)}', cs),
              _detailRow('Status', entry.statusLabel, cs),
              if (entry.dueDate != null)
                _detailRow('Due Date', _formatDate(entry.dueDate!), cs),
              if (entry.category != null)
                _detailRow('Category', entry.category!, cs),
              if (entry.notes.isNotEmpty)
                _detailRow('Notes', entry.notes, cs),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }

  void _showActionMenu(LedgerEntry entry) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Actions',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.edit, color: cs.primary, size: 20),
              ),
              title: Text('Edit Entry',
                  style: TextStyle(color: cs.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _editEntry(entry);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.delete, color: cs.error, size: 20),
              ),
              title: Text('Delete Entry',
                  style: TextStyle(color: cs.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _deleteEntry(entry);
              },
            ),
            Container(
              margin: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: cs.outline),
                    foregroundColor: cs.onSurface,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editEntry(LedgerEntry entry) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLedgerEntryScreen(
          userMobile: widget.userMobile,
          entryToEdit: entry,
        ),
      ),
    );
    if (result == true && mounted) setState(() {});
  }

  void _deleteEntry(LedgerEntry entry) {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        title: Text('Delete Entry',
            style: TextStyle(color: cs.onSurface)),
        content: Text(
            'Are you sure you want to delete this ${entry.typeLabel} entry?',
            style: TextStyle(color: cs.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: cs.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: cs.error, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await _ledgerService.deleteLedgerEntry(entry.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Entry deleted'),
                    backgroundColor: cs.secondary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: cs.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDateFilterDialog() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cs.surface,
        title:
            Text('Date Filter', style: TextStyle(color: cs.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.calendar_today, color: cs.primary),
              title: Text('Start Date',
                  style: TextStyle(color: cs.onSurface)),
              subtitle: Text(
                  _startDate != null ? _formatDate(_startDate!) : 'Not set',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6))),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null && mounted) {
                  setState(() => _startDate = date);
                  Navigator.pop(context);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.calendar_today, color: cs.primary),
              title: Text('End Date',
                  style: TextStyle(color: cs.onSurface)),
              subtitle: Text(
                  _endDate != null ? _formatDate(_endDate!) : 'Not set',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6))),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null && mounted) {
                  setState(() => _endDate = date);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: cs.primary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary, foregroundColor: Colors.white),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _search = '';
      _startDate = null;
      _endDate = null;
      _typeFilter = null;
      _statusFilter = null;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Utilities
  // ─────────────────────────────────────────────────────────────────────────

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 80, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text('No ledger entries found',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 16)),
          const SizedBox(height: 8),
          if (_search.isNotEmpty ||
              _startDate != null ||
              _typeFilter != null ||
              _statusFilter != null)
            TextButton(
              onPressed: _clearFilters,
              child: Text('Clear Filters',
                  style: TextStyle(color: cs.primary)),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text('$label:',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: cs.onSurface)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.8))),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'sale':
        return Colors.green;
      case 'purchase':
        return Colors.orange;
      case 'payment':
        return Colors.purple;
      case 'receipt':
        return Colors.red;
      case 'income':
        return Colors.teal;
      case 'expense':
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
