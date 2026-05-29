import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ledger_service.dart';
import '../models/ledger_model.dart';
import 'add_ledger_entry_screen.dart';
import 'package:inventory_app/core/theme/colors.dart';

class PartyLedgerScreen extends StatefulWidget {
  final String userMobile;
  final dynamic party;
  final String partyType;

  const PartyLedgerScreen({
    super.key,
    required this.userMobile,
    required this.party,
    required this.partyType,
  });

  @override
  State<PartyLedgerScreen> createState() => _PartyLedgerScreenState();
}

class _PartyLedgerScreenState extends State<PartyLedgerScreen> {
  late final LedgerService _ledgerService;
  double _currentBalance = 0;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  String get _partyId => widget.party.id as String;
  String get _partyName => widget.party.name as String;
  String get _partyContact => widget.partyType == 'customer'
      ? widget.party.mobile as String
      : widget.party.phone as String;

  @override
  void initState() {
    super.initState();
    _ledgerService = LedgerService(widget.userMobile);
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final balance = await _ledgerService.getPartyBalance(_partyId);
    if (mounted) setState(() => _currentBalance = balance);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isCustomer = widget.partyType == 'customer';

    return Scaffold(
      backgroundColor:
          isDark ? cs.surface : AppColors.background,
      appBar: AppBar(
        title: Text('$_partyName Ledger',
            style: TextStyle(color: cs.onSurface)),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTransaction,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Transaction',
            style: TextStyle(color: Colors.white)),
        backgroundColor: cs.primary,
      ),
      body: Column(
        children: [
          // ── Balance card ────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.all(16),
            color: cs.surface,
            elevation: isDark ? 4 : 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Current Balance',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface)),
                      Text(
                        _currency.format(_currentBalance.abs()),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _currentBalance >= 0
                              ? AppColors.success
                              : cs.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCustomer
                        ? (_currentBalance >= 0
                            ? 'Customer owes you'
                            : 'You owe customer')
                        : (_currentBalance >= 0
                            ? 'You owe supplier'
                            : 'Supplier owes you'),
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // ── Party info ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: cs.surface,
              elevation: isDark ? 4 : 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (isCustomer
                          ? AppColors.customerColor
                          : AppColors.supplierColor)
                      .withValues(alpha: 0.15),
                  child: Icon(
                    isCustomer ? Icons.person : Icons.store,
                    color: isCustomer
                        ? AppColors.customerColor
                        : AppColors.supplierColor,
                  ),
                ),
                title: Text(_partyName,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface)),
                subtitle: Text(_partyContact,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6))),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Transaction history ───────────────────────────────────
          Expanded(
            child: StreamBuilder<List<LedgerEntry>>(
              stream: _ledgerService.getLedgerEntries(
                partyId: _partyId,
                partyType: widget.partyType,
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

                final entries = snapshot.data ?? [];
                if (entries.isEmpty) return _emptyState(cs);

                return RefreshIndicator(
                  onRefresh: _loadBalance,
                  color: cs.primary,
                  backgroundColor: cs.surface,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                    itemCount: entries.length,
                    itemBuilder: (ctx, i) =>
                        _transactionCard(entries[i], cs, isDark),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionCard(
      LedgerEntry entry, ColorScheme cs, bool isDark) {
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
        title: Text(entry.description,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: cs.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: entry.typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: entry.typeColor.withValues(alpha: 0.3)),
              ),
              child: Text(entry.typeLabel,
                  style:
                      TextStyle(color: entry.typeColor, fontSize: 10)),
            ),
            Text(
              '${entry.date.day}/${entry.date.month}/${entry.date.year}',
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
            if (entry.dueDate != null && entry.status == 'pending')
              Text(
                'Due: ${entry.dueDate!.day}/${entry.dueDate!.month}/${entry.dueDate!.year}',
                style: TextStyle(
                    fontSize: 11,
                    color: entry.isOverdue ? AppColors.error : AppColors.warning,
                    fontWeight: FontWeight.w500),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${entry.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: entry.isDebit() ? AppColors.success : cs.error,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: entry.statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: entry.statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(entry.statusLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: entry.statusColor)),
            ),
          ],
        ),
        onTap: () => _showEntryDetails(entry, cs),
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 80, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text('No transactions yet',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text('Tap + Add Transaction to get started',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                  fontSize: 14)),
        ],
      ),
    );
  }

  void _showEntryDetails(LedgerEntry entry, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cs.surface,
        title: Row(
          children: [
            Expanded(
              child: Text('Transaction Details',
                  style: TextStyle(color: cs.onSurface)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: entry.statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: entry.statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(entry.statusLabel,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: entry.statusColor)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Date',
                  '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                  cs),
              _detailRow('Type', entry.typeLabel, cs),
              _detailRow('Description', entry.description, cs),
              _detailRow('Reference',
                  entry.reference.isNotEmpty ? entry.reference : 'N/A',
                  cs),
              _detailRow(
                  'Amount', '₹${entry.amount.toStringAsFixed(2)}', cs),
              _detailRow(
                  'Balance', '₹${entry.balance.toStringAsFixed(2)}', cs),
              if (entry.dueDate != null)
                _detailRow(
                    'Due Date',
                    '${entry.dueDate!.day}/${entry.dueDate!.month}/${entry.dueDate!.year}',
                    cs),
              if (entry.notes.isNotEmpty)
                _detailRow('Notes', entry.notes, cs),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Close', style: TextStyle(color: cs.primary)),
          ),
          if (entry.status == 'pending')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _markPaid(entry);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white),
              child: const Text('Mark as Paid'),
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

  Future<void> _addTransaction() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddLedgerEntryScreen(
          userMobile: widget.userMobile,
          initialPartyType: widget.partyType,
          initialPartyId: _partyId,
          initialPartyName: _partyName,
        ),
      ),
    );
    if (mounted) _loadBalance();
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
        ));
        _loadBalance();
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
