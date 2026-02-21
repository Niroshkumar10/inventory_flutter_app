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
    super.key,
    required this.userMobile,
    this.initialType,
    this.initialPartyType,
    this.entryToEdit,
  });

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading parties: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingParties = false);
      }
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPartyId == null || _selectedPartyId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a party'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Entry updated successfully' : 'Entry added successfully'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        Navigator.pop(context, true); // Return success
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Entry' : 'Add Ledger Entry',
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete, color: colorScheme.error),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction Type Card
              _buildSectionCard(
                icon: Icons.swap_horiz,
                title: 'Transaction Type',
                color: colorScheme.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select transaction type',
                      style: TextStyle(
                        fontSize: 13, 
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTypeChip('sale', 'Sale', Icons.trending_up, colorScheme.secondary),
                          const SizedBox(width: 10),
                          _buildTypeChip('purchase', 'Purchase', Icons.shopping_cart, colorScheme.tertiary),
                          const SizedBox(width: 10),
                          _buildTypeChip('payment', 'Received', Icons.download, Colors.purple),
                          const SizedBox(width: 10),
                          _buildTypeChip('receipt', 'Paid', Icons.upload, colorScheme.error),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Party Type Card
              _buildSectionCard(
                icon: Icons.people,
                title: 'Party Type',
                color: Colors.teal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select party type',
                      style: TextStyle(
                        fontSize: 13, 
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPartyTypeChip('customer', 'Customer', Icons.person, colorScheme.secondary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPartyTypeChip('supplier', 'Supplier', Icons.store, colorScheme.tertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Party Selection Card
              _buildSectionCard(
                icon: Icons.list,
                title: 'Select Party',
                color: Colors.purple,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose from your list',
                      style: TextStyle(
                        fontSize: 13, 
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_loadingParties)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Loading parties...',
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ],
                        ),
                      )
                    else if (_parties.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _selectedPartyType == 'customer' 
                                  ? Icons.person_outline 
                                  : Icons.store_outlined,
                              size: 48,
                              color: colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No ${_selectedPartyType}s found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please add customers/suppliers first',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      // Enhanced Dropdown with mobile-optimized styling
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.outline,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedPartyId,
                            isExpanded: true,
                            hint: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 20,
                                    color: colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Select ${_selectedPartyType == 'customer' ? 'Customer' : 'Supplier'}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: colorScheme.onSurface.withOpacity(0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            icon: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: _selectedPartyId != null 
                                    ? Colors.purple
                                    : colorScheme.onSurface.withOpacity(0.5),
                                size: 24,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            items: _parties.map<DropdownMenuItem<String>>((dynamic party) {
                              final String partyName;
                              final String contact;
                              final bool isSelected = _selectedPartyId == party.id;
                              
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
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 32),
                                  child: Row(
                                    children: [
                                      // Party icon
                                      Container(
                                        width: 24,
                                        height: 24,
                                        margin: const EdgeInsets.only(right: 8),
                                        child: Icon(
                                          _selectedPartyType == 'customer'
                                              ? Icons.person_outline_rounded
                                              : Icons.store_outlined,
                                          size: 18,
                                          color: isSelected 
                                              ? Colors.purple
                                              : colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                      
                                      // Party name - single line only
                                      Expanded(
                                        child: Text(
                                          partyName,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            fontSize: 14,
                                            color: isSelected ? Colors.purple : colorScheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      
                                      // Contact as simple text
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          contact,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                      
                                      // Selection checkmark
                                      if (isSelected)
                                        Container(
                                          margin: const EdgeInsets.only(left: 4),
                                          child: Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: Colors.purple,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              setState(() {
                                _selectedPartyId = value;
                                if (value != null) {
                                  for (var party in _parties) {
                                    if (party.id == value) {
                                      if (_selectedPartyType == 'customer') {
                                        final customer = party as Customer;
                                        _selectedPartyName = customer.name;
                                        _selectedPartyContact = customer.mobile;
                                      } else {
                                        final supplier = party as Supplier;
                                        _selectedPartyName = supplier.name;
                                        _selectedPartyContact = supplier.phone;
                                      }
                                      break;
                                    }
                                  }
                                }
                              });
                            },
                            dropdownColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                            elevation: isDark ? 8 : 4,
                            borderRadius: BorderRadius.circular(12),
                            menuMaxHeight: 400,
                          ),
                        ),
                      ),
                    
                    if (_selectedPartyId != null && _selectedPartyName.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.purple, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected: $_selectedPartyName',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.purple,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_selectedPartyContact.isNotEmpty)
                                    Text(
                                      _selectedPartyContact,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.purple.withOpacity(0.8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Transaction Details Card
              _buildSectionCard(
                icon: Icons.receipt,
                title: 'Transaction Details',
                color: colorScheme.secondary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.outline,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withOpacity(0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedStatus,
                              isExpanded: true,
                              hint: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Select Status',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                ),
                              ),
                              icon: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _selectedStatus != null 
                                      ? colorScheme.secondary
                                      : colorScheme.onSurface.withOpacity(0.5),
                                  size: 24,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              items: const [
                                DropdownMenuItem(
                                  value: 'pending',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.pending_actions_rounded,
                                        size: 18,
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Pending',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'paid',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Paid',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'cancelled',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.cancel_rounded,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Cancelled',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedStatus = value!);
                              },
                              dropdownColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                              elevation: isDark ? 8 : 4,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Description
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _descriptionController,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Enter description',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: colorScheme.secondary, width: 1.5),
                            ),
                            filled: true,
                            fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: Icon(
                              Icons.description_outlined,
                              size: 20,
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter description';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _amountController,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: colorScheme.secondary, width: 1.5),
                            ),
                            filled: true,
                            fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: Icon(
                              Icons.currency_rupee,
                              size: 20,
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Reference
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reference No.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _referenceController,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Invoice/Payment number',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: colorScheme.secondary, width: 1.5),
                            ),
                            filled: true,
                            fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: Icon(
                              Icons.numbers,
                              size: 20,
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Notes
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _notesController,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Additional notes',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurface.withOpacity(0.4),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: colorScheme.secondary, width: 1.5),
                            ),
                            filled: true,
                            fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: Icon(
                              Icons.note_outlined,
                              size: 20,
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditing ? colorScheme.primary : colorScheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: isDark ? 4 : 2,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Update Entry' : 'Add Entry',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedType == type;
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? color : colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedType = type);
      },
      backgroundColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
      selectedColor: color.withOpacity(0.15),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : colorScheme.onSurface.withOpacity(0.7),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(
          color: isSelected ? color : colorScheme.outline,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildPartyTypeChip(String type, String label, IconData icon, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _selectedPartyType == type;
    
    return FilterChip(
      label: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: isSelected ? color : colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPartyType = type;
          _selectedPartyId = null;
          _selectedPartyName = '';
          _selectedPartyContact = '';
          _loadParties();
        });
      },
      backgroundColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
      selectedColor: color.withOpacity(0.15),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: isSelected ? color : colorScheme.onSurface.withOpacity(0.7),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(
          color: isSelected ? color : colorScheme.outline,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  void _confirmDelete() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete, color: colorScheme.error, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete Entry',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete this entry?',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: colorScheme.outline),
                        foregroundColor: colorScheme.onSurface,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // Close confirmation dialog
                        await _deleteEntry();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: theme.brightness == Brightness.dark ? 4 : 2,
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEntry() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    try {
      setState(() => _isLoading = true);
      await _ledgerService.deleteLedgerEntry(widget.entryToEdit!.id);
      
      if (mounted) {
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
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}