import 'package:flutter/material.dart';
import '../services/ledger_service.dart';
import '../models/ledger_model.dart';

class LedgerListScreen extends StatefulWidget {
  final String userMobile;
  final String? partyId;
  final String? partyType;
  
  const LedgerListScreen({
    Key? key,
    required this.userMobile,
    this.partyId,
    this.partyType,
  }) : super(key: key);

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Ledger Entries'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by party or description',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
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
                      '${_startDate?.toString().split(' ')[0] ?? 'Start'} - ${_endDate?.toString().split(' ')[0] ?? 'End'}',
                    ),
                    backgroundColor: Colors.blue.shade100,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear Filters'),
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
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 50),
                        const SizedBox(height: 10),
                        Text('Error: ${snapshot.error}'),
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
                
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredEntries.length,
                  itemBuilder: (context, index) {
                    return _ledgerEntryCard(filteredEntries[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerEntryCard(LedgerEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.typeColor.withOpacity(0.2),
          child: Icon(entry.typeIcon, color: entry.typeColor, size: 20),
        ),
        title: Text(
          entry.partyName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(entry.typeLabel),
                  backgroundColor: entry.typeColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: entry.typeColor, fontSize: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.description,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.date.toString().split(' ')[0],
              style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                color: entry.isDebit() ? Colors.green : Colors.red,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Bal: ₹${entry.balance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11,
                color: entry.balance >= 0 ? Colors.green : Colors.red,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'No ledger entries found',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_search.isNotEmpty || _startDate != null || _endDate != null)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear Filters'),
            ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Filter Entries'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Start Date'),
              subtitle: Text(_startDate?.toString().split(' ')[0] ?? 'Not set'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() => _startDate = date);
                }
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('End Date'),
              subtitle: Text(_endDate?.toString().split(' ')[0] ?? 'Not set'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  setState(() => _endDate = date);
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Date', entry.date.toString().split(' ')[0]),
              _detailRow('Type', entry.typeLabel),
              _detailRow('Party', entry.partyName),
              _detailRow('Description', entry.description),
              _detailRow('Reference', entry.reference.isNotEmpty ? entry.reference : 'N/A'),
              _detailRow('Debit', '₹${entry.debit.toStringAsFixed(2)}'),
              _detailRow('Credit', '₹${entry.credit.toStringAsFixed(2)}'),
              _detailRow('Amount', '₹${entry.amount.toStringAsFixed(2)}'),
              _detailRow('Balance', '₹${entry.balance.toStringAsFixed(2)}'),
              if (entry.notes.isNotEmpty) _detailRow('Notes', entry.notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showActionMenu(LedgerEntry entry) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('Edit Entry'),
            onTap: () {
              Navigator.pop(context);
              _editEntry(entry);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Entry'),
            onTap: () {
              Navigator.pop(context);
              _deleteEntry(entry);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy, color: Colors.green),
            title: const Text('Duplicate Entry'),
            onTap: () {
              Navigator.pop(context);
              _duplicateEntry(entry);
            },
          ),
        ],
      ),
    );
  }

  void _editEntry(LedgerEntry entry) {
    // TODO: Implement edit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon')),
    );
  }

  void _deleteEntry(LedgerEntry entry) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Are you sure you want to delete this ${entry.typeLabel} entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _ledgerService.deleteLedgerEntry(entry.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Entry deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _duplicateEntry(LedgerEntry entry) {
    // TODO: Implement duplicate functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Duplicate functionality coming soon')),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}