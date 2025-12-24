// lib/features/bill/screens/add_edit_bill_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/bill_service.dart';
import '../models/bill_model.dart';
import '../../party/services/supplier_service.dart'; // Import supplier service
import '../../party/models/supplier_model.dart'; // Import supplier model
import '../../party/services/customer_service.dart'; // Import customer service
import '../../party/models/customer_model.dart'; // Import customer model

class AddEditBillScreen extends StatefulWidget {
  final String type; // 'sales' or 'purchase'
  final String userMobile;
  final Bill? billToEdit;
  final BillService billService;

  const AddEditBillScreen({
    super.key,
    required this.type,
    required this.userMobile,
    this.billToEdit,
    required this.billService,
  });

  @override
  State<AddEditBillScreen> createState() => _AddEditBillScreenState();
}

class _AddEditBillScreenState extends State<AddEditBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _partyNameController = TextEditingController();
  final _partyPhoneController = TextEditingController();
  final _partyAddressController = TextEditingController();
  final _gstRateController = TextEditingController(text: '18');
  final _amountPaidController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  
  bool _isGST = true;
  List<BillItem> _items = [];
  double _subtotal = 0.0;
  double _gstAmount = 0.0;
  double _totalAmount = 0.0;
  double _amountDue = 0.0;
  
  bool _isLoading = false;
  String? _invoiceNumber;
  
  // Lists for suppliers and customers
  List<Supplier> _suppliers = [];
  List<Customer> _customers = [];
  List<String> _supplierNames = [];
  List<String> _customerNames = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadSuppliersAndCustomers();
  }

  Future<void> _initializeData() async {
    if (widget.billToEdit != null) {
      // Editing existing bill
      _loadBillData(widget.billToEdit!);
    } else {
      // Creating new bill
      _invoiceNumber = await widget.billService.getNextInvoiceNumber(widget.type);
      // Add one empty item
      _items.add(BillItem(
        description: '',
        quantity: 1,
        price: 0.0,
        total: 0.0,
      ));
      _calculateTotals();
    }
  }

  Future<void> _loadSuppliersAndCustomers() async {
    try {
      if (widget.type == 'purchase') {
        // Load suppliers for purchase bills
        final supplierService = SupplierService(widget.userMobile);
        _suppliers = await supplierService.getSuppliers().first;
        _supplierNames = _suppliers.map((s) => s.name).toList();
        print('✅ Loaded ${_suppliers.length} suppliers');
      } else if (widget.type == 'sales') {
        // Load customers for sales bills
        final customerService = CustomerService(widget.userMobile);
        _customers = await customerService.getCustomers().first;
        _customerNames = _customers.map((c) => c.name).toList();
        print('✅ Loaded ${_customers.length} customers');
      }
      
      setState(() {});
    } catch (e) {
      print('❌ Error loading party data: $e');
    }
  }

  void _loadBillData(Bill bill) {
    _invoiceNumber = bill.invoiceNumber;
    _partyNameController.text = bill.partyName;
    _partyPhoneController.text = bill.partyPhone;
    _partyAddressController.text = bill.partyAddress;
    _isGST = bill.isGST;
    _gstRateController.text = bill.gstRate.toString();
    _amountPaidController.text = bill.amountPaid.toString();
    _notesController.text = bill.notes;
    _items = List.from(bill.items);
    _calculateTotals();
  }

  void _calculateTotals() {
    _subtotal = _items.fold(0.0, (sum, item) => sum + (item.quantity * item.price));
    final gstRate = double.tryParse(_gstRateController.text) ?? 0.0;
    _gstAmount = _isGST ? (_subtotal * gstRate / 100) : 0.0;
    _totalAmount = _subtotal + _gstAmount;
    final amountPaid = double.tryParse(_amountPaidController.text) ?? 0.0;
    _amountDue = _totalAmount - amountPaid;
    
    if (mounted) {
      setState(() {});
    }
  }

  // Helper method to find party details when selected from dropdown
  void _onPartySelected(String? value) {
    if (value == null || value.isEmpty) return;
    
    setState(() {
      _partyNameController.text = value;
    });
    
    // Try to find and populate phone and address
    if (widget.type == 'purchase') {
      // Find supplier details
      for (final supplier in _suppliers) {
        if (supplier.name == value) {
          _partyPhoneController.text = supplier.phone;
          _partyAddressController.text = supplier.address;
          break;
        }
      }
    } else if (widget.type == 'sales') {
      // Find customer details using your Customer model
      for (final customer in _customers) {
        if (customer.name == value) {
          _partyPhoneController.text = customer.mobile; // Note: Your model uses 'mobile' not 'phone'
          _partyAddressController.text = customer.address;
          break;
        }
      }
    }
  }

  // Method to show dialog for adding new party
  void _showAddPartyDialog() {
    final partyType = widget.type == 'sales' ? 'Customer' : 'Supplier';
    
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final phoneController = TextEditingController();
        final addressController = TextEditingController();
        
        return AlertDialog(
          title: Text('Add New $partyType'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '$partyType Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter name')),
                  );
                  return;
                }
                
                try {
                  if (widget.type == 'purchase') {
                    // Add new supplier
                    final supplierService = SupplierService(widget.userMobile);
                    final newSupplier = Supplier.create(
                      name: nameController.text,
                      phone: phoneController.text,
                      userMobile: widget.userMobile,
                      address: addressController.text,
                      email: '',
                    );
                    await supplierService.addSupplier(newSupplier);
                    
                    // Reload suppliers
                    _suppliers = await supplierService.getSuppliers().first;
                    _supplierNames = _suppliers.map((s) => s.name).toList();
                  } else if (widget.type == 'sales') {
                    // Add new customer
                    final customerService = CustomerService(widget.userMobile);
                    final newCustomer = Customer(
                      id: '',
                      name: nameController.text,
                      mobile: phoneController.text,
                      address: addressController.text,
                      userMobile: widget.userMobile,
                      createdAt: DateTime.now(),
                    );
                    await customerService.addCustomer(newCustomer);
                    
                    // Reload customers
                    _customers = await customerService.getCustomers().first;
                    _customerNames = _customers.map((c) => c.name).toList();
                  }
                  
                  // Update dropdown and select the new party
                  _onPartySelected(nameController.text);
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$partyType added successfully'),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding $partyType: $e'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ... keep all other methods (_addItem, _removeItem, _saveBill) the same ...

  @override
  Widget build(BuildContext context) {
    final partyList = widget.type == 'sales' ? _customerNames : _supplierNames;
    final partyType = widget.type == 'sales' ? 'Customer' : 'Supplier';
    final iconColor = widget.type == 'sales' ? Colors.green : Colors.orange;
    final icon = widget.type == 'sales' ? Icons.person : Icons.local_shipping_outlined;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.billToEdit != null 
            ? 'Edit ${widget.type == 'sales' ? 'Sales' : 'Purchase'}'
            : 'New ${widget.type == 'sales' ? 'Sales' : 'Purchase'}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveBill,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with invoice number
                    if (_invoiceNumber != null)
                      Card(
                        color: widget.type == 'sales' 
                          ? Colors.green.shade50 
                          : Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Icon(
                                widget.type == 'sales' ? Icons.shopping_cart : Icons.inventory,
                                color: iconColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _invoiceNumber!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: iconColor,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  widget.type == 'sales' ? 'SALES' : 'PURCHASE',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: iconColor.withOpacity(0.2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Party Details
                    const Text(
                      'Party Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Party Name Dropdown
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _partyNameController.text.isNotEmpty && 
                                partyList.contains(_partyNameController.text)
                                ? _partyNameController.text 
                                : null,
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                'Select $partyType',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                            ...partyList.map((name) {
                              return DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              );
                            }).toList(),
                            DropdownMenuItem(
                              value: 'new',
                              child: Row(
                                children: [
                                  Icon(Icons.add, size: 16, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add New $partyType',
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == 'new') {
                              _showAddPartyDialog();
                            } else {
                              _onPartySelected(value);
                            }
                          },
                          decoration: InputDecoration(
                            prefixIcon: Icon(icon, color: iconColor),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: InputBorder.none,
                            labelText: '$partyType Name *',
                          ),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          isExpanded: true,
                          validator: (value) {
                            if (value == null || value.isEmpty || value == 'Select $partyType') {
                              return 'Please select a $partyType';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _partyPhoneController,
                      decoration: InputDecoration(
                        labelText: widget.type == 'sales' ? 'Customer Mobile' : 'Supplier Phone',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _partyAddressController,
                      decoration: InputDecoration(
                        labelText: widget.type == 'sales' ? 'Customer Address' : 'Supplier Address',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                      maxLines: 2,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // GST Switch
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt, color: Colors.blue),
                            const SizedBox(width: 12),
                            const Text('GST Invoice'),
                            const Spacer(),
                            Switch(
                              value: _isGST,
                              onChanged: (value) {
                                setState(() {
                                  _isGST = value;
                                  _calculateTotals();
                                });
                              },
                              activeColor: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Items Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add_circle, color: Colors.blue),
                          tooltip: 'Add Item',
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Items List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        return _buildItemRow(index);
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Totals Section
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildTotalRow('Subtotal:', _subtotal),
                            if (_isGST) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('GST Rate (%):'),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      controller: _gstRateController,
                                      textAlign: TextAlign.right,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        border: UnderlineInputBorder(),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (value) => _calculateTotals(),
                                    ),
                                  ),
                                ],
                              ),
                              _buildTotalRow('GST Amount:', _gstAmount),
                            ],
                            const Divider(),
                            _buildTotalRow('Total Amount:', _totalAmount, isTotal: true),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Payment Section
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _amountPaidController,
                      decoration: const InputDecoration(
                        labelText: 'Amount Paid',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments),
                        prefixText: '₹ ',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) => _calculateTotals(),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Amount Due:',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              '₹${_amountDue.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _amountDue > 0 ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveBill,
                        icon: const Icon(Icons.save),
                        label: Text(
                          _isLoading ? 'Saving...' : 'Save Transaction',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.description,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _items[index] = item.copyWith(description: value);
                        _calculateTotals();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (_items.length > 1)
                  IconButton(
                    onPressed: () => _removeItem(index),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Remove Item',
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.quantity.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final qty = int.tryParse(value) ?? 1;
                      setState(() {
                        _items[index] = item.copyWith(quantity: qty);
                        _calculateTotals();
                      });
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                Expanded(
                  child: TextFormField(
                    initialValue: item.price.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      final price = double.tryParse(value) ?? 0.0;
                      setState(() {
                        _items[index] = item.copyWith(price: price);
                        _calculateTotals();
                      });
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                Expanded(
                  child: Card(
                    color: Colors.grey.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        '₹${(item.quantity * item.price).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Colors.blue.shade900 : Colors.blue.shade700,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? Colors.blue : Colors.blue.shade900,
          ),
        ),
      ],
    );
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate items
    for (final item in _items) {
      if (item.description.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter item description')),
        );
        return;
      }
      if (item.price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item price must be greater than 0')),
        );
        return;
      }
    }
    
    setState(() => _isLoading = true);
    
    try {
      final bill = Bill.create(
        type: widget.type,
        invoiceNumber: _invoiceNumber!,
        partyName: _partyNameController.text,
        userMobile: widget.userMobile,
        partyPhone: _partyPhoneController.text,
        partyAddress: _partyAddressController.text,
        items: _items,
        subtotal: _subtotal,
        gstRate: double.tryParse(_gstRateController.text) ?? 0.0,
        gstAmount: _gstAmount,
        totalAmount: _totalAmount,
        amountPaid: double.tryParse(_amountPaidController.text) ?? 0.0,
        amountDue: _amountDue,
        paymentStatus: _amountDue <= 0 ? 'paid' : (_amountDue < _totalAmount ? 'partial' : 'due'),
        isGST: _isGST,
        notes: _notesController.text,
      );
      
      if (widget.billToEdit != null) {
        // Update existing bill
        final updatedBill = bill.copyWith(id: widget.billToEdit!.id);
        await widget.billService.updateBill(updatedBill);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated successfully')),
        );
      } else {
        // Add new bill
        await widget.billService.addBill(bill);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved successfully')),
        );
      }
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addItem() {
    setState(() {
      _items.add(BillItem(
        description: '',
        quantity: 1,
        price: 0.0,
        total: 0.0,
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
        _calculateTotals();
      });
    }
  }

  @override
  void dispose() {
    _partyNameController.dispose();
    _partyPhoneController.dispose();
    _partyAddressController.dispose();
    _gstRateController.dispose();
    _amountPaidController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}