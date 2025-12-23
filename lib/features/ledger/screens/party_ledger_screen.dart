import 'package:flutter/material.dart';
import '../services/ledger_service.dart';
import '../models/ledger_model.dart';
import 'add_ledger_entry_screen.dart';

class PartyLedgerScreen extends StatefulWidget {
  final String userMobile;
  final dynamic party;
  final String partyType;
  
  const PartyLedgerScreen({
    Key? key,
    required this.userMobile,
    required this.party,
    required this.partyType,
  }) : super(key: key);

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
    setState(() => _currentBalance = balance);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.party.name} Ledger'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTransaction,
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance Card
          Card(
            margin: const EdgeInsets.all(16),
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
                      const Text(
                        'Current Balance',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₹${_currentBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _currentBalance >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.partyType == 'customer'
                        ? (_currentBalance >= 0
                            ? 'Customer owes you'
                            : 'You owe customer')
                        : (_currentBalance >= 0
                            ? 'You owe supplier'
                            : 'Supplier owes you'),
                    style: TextStyle(
                      color: Colors.grey[600],
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
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: widget.partyType == 'customer' 
                      ? Colors.blue.shade100 
                      : Colors.orange.shade100,
                  child: Icon(
                    widget.partyType == 'customer' ? Icons.person : Icons.store,
                    color: widget.partyType == 'customer' ? Colors.blue : Colors.orange,
                  ),
                ),
                title: Text(
                  widget.party.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  widget.partyType == 'customer' 
                      ? widget.party.mobile 
                      : widget.party.phone,
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
                  return const Center(child: CircularProgressIndicator());
                }
                
                final entries = snapshot.data ?? [];
                
                if (entries.isEmpty) {
                  return _emptyState();
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    return _transactionItem(entries[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionItem(LedgerEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.typeColor.withOpacity(0.2),
          child: Icon(entry.typeIcon, color: entry.typeColor, size: 20),
        ),
        title: Text(
          entry.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Chip(
              label: Text(entry.typeLabel),
              backgroundColor: entry.typeColor.withOpacity(0.1),
              labelStyle: TextStyle(color: entry.typeColor, fontSize: 10),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
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
            'No transactions yet',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first transaction with ${widget.party.name}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _addTransaction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddLedgerEntryScreen(
        userMobile: widget.userMobile,
        initialPartyType: widget.partyType,
      ),
    ).then((_) {
      _loadCurrentBalance(); // Refresh balance
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
              _detailRow('Description', entry.description),
              _detailRow('Reference', entry.reference.isNotEmpty ? entry.reference : 'N/A'),
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