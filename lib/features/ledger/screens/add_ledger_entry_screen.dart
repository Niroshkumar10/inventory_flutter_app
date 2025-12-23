import 'package:flutter/material.dart';
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
  
  bool _isLoading = false;
  List<dynamic> _parties = [];
  bool _loadingParties = true;
  
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
        setState(() => _parties = customers);
      } else {
        final suppliers = await _supplierService.getSuppliers().first;
        setState(() => _parties = suppliers);
      }
      
      // Auto-select if only one party exists and not editing
      if (_parties.length == 1 && !_isEditing && _selectedPartyId == null) {
        final party = _parties.first;
        _selectedPartyId = party.id;
        _selectedPartyName = party.name;
      }
    } catch (e) {
      print('❌ Error loading parties: $e');
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
        );
        
        await _ledgerService.addLedgerEntry(entry);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Entry updated' : 'Entry added'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
      
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
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Edit Entry' : 'Add Ledger Entry',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Transaction Type
              const Text(
                'Transaction Type',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _typeChip('sale', 'Sale', Colors.green),
                  _typeChip('purchase', 'Purchase', Colors.red),
                  _typeChip('payment', 'Payment Received', Colors.blue),
                  _typeChip('receipt', 'Payment Made', Colors.orange),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Party Type
              const Text(
                'Party Type',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _partyTypeChip('customer', 'Customer'),
                  _partyTypeChip('supplier', 'Supplier'),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Party Selection
              const Text(
                'Select Party',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              
              if (_loadingParties)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_parties.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No parties found. Add customers/suppliers first.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedPartyId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select party',
                  ),
                  items: _parties.map<DropdownMenuItem<String>>((party) {
                    return DropdownMenuItem(
                      value: party.id,
                      child: Text(party.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPartyId = value;
                      if (value != null) {
                        // Find the selected party
                        final selectedParty = _parties.firstWhere(
                          (party) => party.id == value,
                          orElse: () => null,
                        );
                        if (selectedParty != null) {
                          _selectedPartyName = selectedParty.name;
                        }
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a party';
                    }
                    return null;
                  },
                ),
              
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter description',
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
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                  hintText: '0.00',
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
                decoration: const InputDecoration(
                  labelText: 'Reference No.',
                  border: OutlineInputBorder(),
                  hintText: 'Invoice/Payment number',
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  hintText: 'Additional notes',
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
                        style: const TextStyle(fontSize: 16),
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

  Widget _partyTypeChip(String type, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedPartyType == type,
      onSelected: (selected) {
        setState(() {
          _selectedPartyType = type;
          _selectedPartyId = null;
          _selectedPartyName = '';
          _loadParties();
        });
      },
      selectedColor: type == 'customer' ? Colors.blue.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
      labelStyle: TextStyle(
        color: _selectedPartyType == type 
            ? (type == 'customer' ? Colors.blue : Colors.orange)
            : Colors.grey,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _selectedPartyType == type 
              ? (type == 'customer' ? Colors.blue : Colors.orange)
              : Colors.grey,
        ),
      ),
    );
  }
}