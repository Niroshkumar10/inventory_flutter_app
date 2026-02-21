// ./lib/features/ledger/screens/ledger_list_screen.dart
import 'package:flutter/material.dart';
import '../services/ledger_service.dart';
import '../models/ledger_model.dart';

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

  @override
  void initState() {
    super.initState();
    _ledgerService = LedgerService(widget.userMobile);
    // Set default date range to current month
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(
          'All Ledger Entries',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt, color: colorScheme.onSurface),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              style: TextStyle(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search by party or description',
                hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search, color: colorScheme.onSurface.withOpacity(0.5)),
                filled: true,
                fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                ),
              ),
              onChanged: (value) {
                setState(() => _search = value.toLowerCase());
              },
            ),
          ),
          
          // Date Filter Display
          if (_startDate != null || _endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      '${_startDate != null ? _formatDate(_startDate!) : 'Start'} - ${_endDate != null ? _formatDate(_endDate!) : 'End'}',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearFilters,
                    child: Text(
                      'Clear Filters',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: StreamBuilder<List<LedgerEntry>>(
              stream: _ledgerService.getLedgerEntries(
                partyId: widget.partyId,
                partyType: widget.partyType,
                startDate: _startDate,
                endDate: _endDate,
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
                final filteredEntries = entries.where((entry) {
                  return entry.partyName.toLowerCase().contains(_search) ||
                         entry.description.toLowerCase().contains(_search) ||
                         entry.reference.toLowerCase().contains(_search);
                }).toList();
                
                if (filteredEntries.isEmpty) {
                  return _emptyState();
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  color: colorScheme.primary,
                  backgroundColor: colorScheme.surface,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      return _ledgerEntryCard(filteredEntries[index]);
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

  Widget _ledgerEntryCard(LedgerEntry entry) {
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
          entry.partyName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    entry.typeLabel,
                    style: TextStyle(color: entry.typeColor, fontSize: 10),
                  ),
                  backgroundColor: entry.typeColor.withOpacity(0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  side: BorderSide(color: entry.typeColor.withOpacity(0.3)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
        onLongPress: () => _showActionMenu(entry),
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
            'No ledger entries found',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (_search.isNotEmpty || _startDate != null || _endDate != null)
            TextButton(
              onPressed: _clearFilters,
              child: Text(
                'Clear Filters',
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Filter Entries',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.calendar_today, color: colorScheme.primary),
              title: Text(
                'Start Date',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                _startDate != null ? _formatDate(_startDate!) : 'Not set',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: theme.copyWith(
                        colorScheme: colorScheme.copyWith(
                          primary: colorScheme.primary,
                          onPrimary: Colors.white,
                          surface: colorScheme.surface,
                          onSurface: colorScheme.onSurface,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null && mounted) {
                  setState(() => _startDate = date);
                  Navigator.pop(context);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.calendar_today, color: colorScheme.primary),
              title: Text(
                'End Date',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                _endDate != null ? _formatDate(_endDate!) : 'Not set',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: theme.copyWith(
                        colorScheme: colorScheme.copyWith(
                          primary: colorScheme.primary,
                          onPrimary: Colors.white,
                          surface: colorScheme.surface,
                          onSurface: colorScheme.onSurface,
                        ),
                      ),
                      child: child!,
                    );
                  },
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
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply Filters'),
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
    });
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
              _detailRow('Party', entry.partyName, colorScheme),
              _detailRow('Description', entry.description, colorScheme),
              _detailRow('Reference', entry.reference.isNotEmpty ? entry.reference : 'N/A', colorScheme),
              _detailRow('Debit', '₹${entry.debit.toStringAsFixed(2)}', colorScheme),
              _detailRow('Credit', '₹${entry.credit.toStringAsFixed(2)}', colorScheme),
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

  void _showActionMenu(LedgerEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit, color: colorScheme.primary, size: 20),
              ),
              title: Text(
                'Edit Entry',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                _editEntry(entry);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete, color: colorScheme.error, size: 20),
              ),
              title: Text(
                'Delete Entry',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteEntry(entry);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.copy, color: colorScheme.secondary, size: 20),
              ),
              title: Text(
                'Duplicate Entry',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                _duplicateEntry(entry);
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: colorScheme.outline),
                    foregroundColor: colorScheme.onSurface,
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

  void _editEntry(LedgerEntry entry) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Edit functionality coming soon'),
        backgroundColor: theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _deleteEntry(LedgerEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Delete Entry',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to delete this ${entry.typeLabel} entry?',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await _ledgerService.deleteLedgerEntry(entry.id);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Entry deleted successfully'),
                      backgroundColor: colorScheme.secondary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _duplicateEntry(LedgerEntry entry) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Duplicate functionality coming soon'),
        backgroundColor: theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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