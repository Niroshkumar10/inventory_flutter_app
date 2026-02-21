import 'package:flutter/material.dart';
import '../services/ledger_service.dart';
import '../models/ledger_model.dart';
import 'add_ledger_entry_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _ledgerService = LedgerService(widget.userMobile);
    _loadCurrentBalance();
  }

  Future<void> _loadCurrentBalance() async {
    final balance = await _ledgerService.getPartyBalance(widget.party.id);
    if (mounted) {
      setState(() => _currentBalance = balance);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isCustomer = widget.partyType == 'customer';

    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(
          '${widget.party.name} Ledger',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Column(
        children: [
          // Balance Card
          Card(
            margin: const EdgeInsets.all(16),
            color: colorScheme.surface,
            elevation: isDark ? 4 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Balance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '₹${_currentBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _currentBalance >= 0 ? colorScheme.secondary : colorScheme.error,
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
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Party Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: colorScheme.surface,
              elevation: isDark ? 4 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCustomer 
                      ? colorScheme.secondary.withOpacity(0.2)
                      : colorScheme.tertiary.withOpacity(0.2),
                  child: Icon(
                    isCustomer ? Icons.person : Icons.store,
                    color: isCustomer ? colorScheme.secondary : colorScheme.tertiary,
                  ),
                ),
                title: Text(
                  widget.party.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  isCustomer 
                      ? widget.party.mobile 
                      : widget.party.phone,
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Transaction History
          Expanded(
            child: StreamBuilder<List<LedgerEntry>>(
              stream: _ledgerService.getLedgerEntries(
                partyId: widget.party.id,
                partyType: widget.partyType,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: colorScheme.primary),
                  );
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: colorScheme.error, size: 50),
                        const SizedBox(height: 10),
                        Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                  );
                }
                
                final entries = snapshot.data ?? [];
                
                if (entries.isEmpty) {
                  return _emptyState();
                }
                
                return RefreshIndicator(
                  onRefresh: _loadCurrentBalance,
                  color: colorScheme.primary,
                  backgroundColor: colorScheme.surface,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      return _transactionItem(entries[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionItem(LedgerEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 4 : 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.typeColor.withOpacity(0.2),
          child: Icon(entry.typeIcon, color: entry.typeColor, size: 20),
        ),
        title: Text(
          entry.description,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Chip(
              label: Text(
                entry.typeLabel,
                style: TextStyle(color: entry.typeColor, fontSize: 10),
              ),
              backgroundColor: entry.typeColor.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              side: BorderSide(color: entry.typeColor.withOpacity(0.3)),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(entry.date),
              style: TextStyle(
                fontSize: 11,
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
              '₹${entry.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: entry.isDebit() ? colorScheme.secondary : colorScheme.error,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Bal: ₹${entry.balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11,
                color: entry.balance >= 0 ? colorScheme.secondary : colorScheme.error,
              ),
            ),
          ],
        ),
        onTap: () => _showEntryDetails(entry),
      ),
    );
  }

  Widget _emptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long, 
            size: 80, 
            color: colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first transaction with ${widget.party.name}',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showEntryDetails(LedgerEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Transaction Details',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Date', _formatDate(entry.date), colorScheme),
              _detailRow('Type', entry.typeLabel, colorScheme),
              _detailRow('Description', entry.description, colorScheme),
              _detailRow('Reference', entry.reference.isNotEmpty ? entry.reference : 'N/A', colorScheme),
              _detailRow('Amount', '₹${entry.amount.toStringAsFixed(2)}', colorScheme),
              _detailRow('Balance', '₹${entry.balance.toStringAsFixed(2)}', colorScheme),
              if (entry.notes.isNotEmpty) _detailRow('Notes', entry.notes, colorScheme),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}