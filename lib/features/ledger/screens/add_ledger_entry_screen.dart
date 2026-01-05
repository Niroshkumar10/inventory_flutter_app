// ./lib/features/ledger/screens/add_ledger_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ledger_service.dart';
import '../../party/services/customer_service.dart';
import '../../party/services/supplier_service.dart';
import '../../party/models/customer_model.dart';
import '../../party/models/supplier_model.dart';
import '../models/ledger_model.dart';

class AddLedgerEntryScreen extends StatefulWidget {
  final String userMobile;
  final String? initialType;
  final String? initialPartyType;
  final LedgerEntry? entryToEdit;
  
  const AddLedgerEntryScreen({
    Key? key,
    required this.userMobile,
    this.initialType,
    this.initialPartyType,
    this.entryToEdit,
  }) : super(key: key);

  @override
  State<AddLedgerEntryScreen> createState() => _AddLedgerEntryScreenState();
}

class _AddLedgerEntryScreenState extends State<AddLedgerEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final LedgerService _ledgerService;
  late final CustomerService _customerService;
  late final SupplierService _supplierService;
  
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _selectedType = 'sale';
  String _selectedPartyType = 'customer';
  String? _selectedPartyId;
  String _selectedPartyName = '';
  String _selectedPartyContact = '';
  String _selectedStatus = 'pending';
  
  bool _isLoading = false;
  List<dynamic> _parties = [];
  bool _loadingParties = true;
  
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  bool get _isEditing => widget.entryToEdit != null;

  @override
  void initState() {
    super.initState();
    _ledgerService = LedgerService(widget.userMobile);
    _customerService = CustomerService(widget.userMobile);
    _supplierService = SupplierService(widget.userMobile);
    
    // Set initial values
    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
    
    if (widget.initialPartyType != null) {
      _selectedPartyType = widget.initialPartyType!;
    }
    
    // If editing, populate fields
    if (_isEditing) {
      final entry = widget.entryToEdit!;
      _selectedType = entry.type;
      _selectedPartyType = entry.partyType;
      _selectedPartyId = entry.partyId;
      _selectedPartyName = entry.partyName;
      _selectedStatus = entry.status;
      _descriptionController.text = entry.description;
      _amountController.text = entry.amount.toStringAsFixed(2);
      _referenceController.text = entry.reference;
      _notesController.text = entry.notes;
    }
    
    // Load parties
    _loadParties();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadParties() async {
    try {
      setState(() => _loadingParties = true);
      
      if (_selectedPartyType == 'customer') {
        final customers = await _customerService.getCustomers().first;
        setState(() {
          _parties = customers;
          if (customers.isNotEmpty) {
            // Set contact info for display
            final customer = customers.firstWhere(
              (c) => c.id == _selectedPartyId,
              orElse: () => customers.first,
            );
            if (_selectedPartyId == null) {
              _selectedPartyId = customer.id;
              _selectedPartyName = customer.name;
              _selectedPartyContact = customer.mobile;
            }
          }
        });
      } else {
        final suppliers = await _supplierService.getSuppliers().first;
        setState(() {
          _parties = suppliers;
          if (suppliers.isNotEmpty) {
            final supplier = suppliers.firstWhere(
              (s) => s.id == _selectedPartyId,
              orElse: () => suppliers.first,
            );
            if (_selectedPartyId == null) {
              _selectedPartyId = supplier.id;
              _selectedPartyName = supplier.name;
              _selectedPartyContact = supplier.phone;
            }
          }
        });
      }
      
      // Auto-select if only one party exists and not editing
      if (_parties.length == 1 && !_isEditing && _selectedPartyId == null) {
        final party = _parties.first;
        _selectedPartyId = party.id;
        _selectedPartyName = party.name;
        _selectedPartyContact = _selectedPartyType == 'customer' 
            ? (party as Customer).mobile
            : (party as Supplier).phone;
      }
    } catch (e) {
      print('❌ Error loading parties: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading parties: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _loadingParties = false);
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPartyId == null || _selectedPartyId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a party')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final amount = double.tryParse(_amountController.text) ?? 0;
      
      // Determine debit/credit based on transaction type
      double debit = 0;
      double credit = 0;
      
      switch (_selectedType) {
        case 'sale':
          debit = amount; // Customer owes you
          break;
        case 'purchase':
          credit = amount; // You owe supplier
          break;
        case 'payment':
          credit = amount; // Customer pays you (reduces their balance)
          break;
        case 'receipt':
          debit = amount; // You pay supplier (reduces your balance to them)
          break;
      }
      
      LedgerEntry entry;
      
      if (_isEditing) {
        // Update existing entry
        entry = widget.entryToEdit!.copyWith(
          type: _selectedType,
          partyId: _selectedPartyId!,
          partyType: _selectedPartyType,
          partyName: _selectedPartyName,
          description: _descriptionController.text.trim(),
          debit: debit,
          credit: credit,
          reference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
          status: _selectedStatus,
        );
        
        await _ledgerService.updateLedgerEntry(entry);
      } else {
        // Create new entry
        entry = LedgerEntry.create(
          type: _selectedType,
          partyId: _selectedPartyId!,
          partyType: _selectedPartyType,
          partyName: _selectedPartyName,
          description: _descriptionController.text.trim(),
          debit: debit,
          credit: credit,
          reference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
          userMobile: widget.userMobile,
          status: _selectedStatus,
        );
        
        await _ledgerService.addLedgerEntry(entry);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Entry updated successfully' : 'Entry added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context, true); // Return success
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Entry' : 'Add Ledger Entry'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Transaction Type
              const Text(
                'Transaction Type *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
                SizedBox(
                  height: 60, // Fixed height to prevent overflow
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _typeChip('sale', 'Sale', Colors.green),
                        const SizedBox(width: 8),
                        _typeChip('purchase', 'Purchase', Colors.orange),
                        const SizedBox(width: 8),
                        _typeChip('payment', 'Payment Received', Colors.purple),
                        const SizedBox(width: 8),
                        _typeChip('receipt', 'Payment Made', Colors.red),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Party Type
              const Text(
                'Party Type *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
             const SizedBox(height: 8),
SizedBox(
  height: 40, // Fixed height
  child: Row(
    children: [
      Expanded(
        child: _partyTypeChip('customer', 'Customer', Colors.blue),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _partyTypeChip('supplier', 'Supplier', Colors.orange),
      ),
    ],
  ),
),

              
              const SizedBox(height: 20),
              
              // Party Selection
              const Text(
                'Select Party *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              
              if (_loadingParties)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Row(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(width: 16),
                      Text('Loading parties...'),
                    ],
                  ),
                )
              else if (_parties.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedPartyType == 'customer' 
                            ? Icons.person_outline 
                            : Icons.store_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No ${_selectedPartyType}s found',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please add customers/suppliers first',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
             
  DropdownButtonFormField<String>(
    value: _selectedPartyId,
    decoration: InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      hintText: 'Select party',
      filled: true,
      fillColor: Colors.white,
    ),
    isExpanded: true,
    style: const TextStyle(fontSize: 14),
    items: _parties.map<DropdownMenuItem<String>>((dynamic party) {
      final String partyName;
      final String contact;
      
      if (_selectedPartyType == 'customer') {
        final customer = party as Customer;
        partyName = customer.name;
        contact = customer.mobile;
      } else {
        final supplier = party as Supplier;
        partyName = supplier.name;
        contact = supplier.phone;
      }
      
      return DropdownMenuItem<String>(
        value: party.id,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: partyName,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const TextSpan(text: '\n'),
              TextSpan(
                text: contact,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList(),
    onChanged: (String? value) {
      setState(() {
        _selectedPartyId = value;
        if (value != null) {
          // Simple loop to find the party
          dynamic selectedParty;
          for (var party in _parties) {
            if (party.id == value) {
              selectedParty = party;
              break;
            }
          }
          
          if (selectedParty != null) {
            if (_selectedPartyType == 'customer') {
              final customer = selectedParty as Customer;
              _selectedPartyName = customer.name;
              _selectedPartyContact = customer.mobile;
            } else {
              final supplier = selectedParty as Supplier;
              _selectedPartyName = supplier.name;
              _selectedPartyContact = supplier.phone;
            }
          }
        }
      });
    },
    validator: (String? value) {
      if (value == null || value.isEmpty) {
        return 'Please select a party';
      }
      return null;
    },
  ),
              
              if (_selectedPartyId != null && _selectedPartyName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Selected: $_selectedPartyName',
                    style: const TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Status Selection
              const Text(
                'Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (value) {
                  setState(() => _selectedStatus = value!);
                },
              ),
              
              const SizedBox(height: 20),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Enter description',
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Amount
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixText: '₹ ',
                  hintText: '0.00',
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter valid amount';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Reference
              TextFormField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: 'Reference No.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Invoice/Payment number',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Notes
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: 'Additional notes',
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 24),
              
              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEditing ? Colors.blue : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Entry' : 'Add Entry',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label, Color color) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedType == type,
      onSelected: (selected) {
        setState(() => _selectedType = type);
      },
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: _selectedType == type ? color : Colors.grey,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _selectedType == type ? color : Colors.grey,
        ),
      ),
    );
  }

  Widget _partyTypeChip(String type, String label, Color color) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedPartyType == type,
      onSelected: (selected) {
        setState(() {
          _selectedPartyType = type;
          _selectedPartyId = null;
          _selectedPartyName = '';
          _selectedPartyContact = '';
          _loadParties();
        });
      },
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: _selectedPartyType == type ? color : Colors.grey,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _selectedPartyType == type ? color : Colors.grey,
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog
              await _deleteEntry();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEntry() async {
    try {
      setState(() => _isLoading = true);
      await _ledgerService.deleteLedgerEntry(widget.entryToEdit!.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context, true); // Return success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}