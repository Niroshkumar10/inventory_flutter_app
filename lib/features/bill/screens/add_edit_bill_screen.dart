// lib/features/bill/screens/add_edit_bill_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/bill_service.dart';
import '../models/bill_model.dart';
import '../../party/services/supplier_service.dart';
import '../../party/models/supplier_model.dart';
import '../../party/services/customer_service.dart';
import '../../party/models/customer_model.dart';
import '../../inventory/services/inventory_repo_service.dart';
import '../../inventory/models/inventory_item_model.dart';

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
  
  // ITEM FIELD CONTROLLERS
  final List<TextEditingController> _descControllers = [];
  final List<TextEditingController> _qtyControllers = [];
  final List<TextEditingController> _priceControllers = [];
  
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
  
  // INVENTORY INTEGRATION FIELDS
  List<InventoryItem> _inventoryItems = [];
  List<String> _categories = [];
  String? _selectedCategory;
  List<InventoryItem> _filteredItems = [];
  bool _isSelectingFromInventory = false;
  final TextEditingController _searchController = TextEditingController();
  
  // Add InventoryService variable
  late InventoryService _inventoryService;

  @override
  void initState() {
    super.initState();
    // Initialize inventory service from Provider
    _inventoryService = Provider.of<InventoryService>(context, listen: false);
    _initializeData();
    _loadSuppliersAndCustomers();
    _loadInventoryData();
    
    // Initialize search controller listener
    _searchController.addListener(() {
      _filterItems();
    });
  }

  Future<void> _initializeData() async {
    if (widget.billToEdit != null) {
      _loadBillData(widget.billToEdit!);
    } else {
      _invoiceNumber = await widget.billService.getNextInvoiceNumber(widget.type);
      _addEmptyItem();
    }
  }

  Future<void> _loadInventoryData() async {
    try {
      _categories = await _inventoryService.getCategories();
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
      
      _inventoryItems = await _inventoryService.getAllInventoryItems();
      _filterItems();
      
      if (mounted) setState(() {});
    } catch (e) {
      print('❌ Error loading inventory data: $e');
    }
  }

  /// Handle inventory updates for NEW bills
  Future<void> _handleInventoryUpdatesForNewBill(Bill bill) async {
    print('🔄 Handling inventory updates for new ${bill.type} bill');
    print('  Invoice: ${bill.invoiceNumber}');
    print('  Total items: ${bill.items.length}');
    
    for (int i = 0; i < bill.items.length; i++) {
      final item = bill.items[i];
      print('  Item ${i + 1}: ${item.description}');
      print('    Quantity: ${item.quantity}');
      print('    Inventory ID: ${item.inventoryItemId}');
      print('    Unit: ${item.unit}');
      
      if (item.inventoryItemId != null && item.inventoryItemId!.isNotEmpty) {
        try {
          final adjustment = bill.type == 'sales' ? -item.quantity : item.quantity;
          print('    Adjustment: $adjustment (${bill.type == 'sales' ? 'decrease' : 'increase'})');
          
          await _inventoryService.adjustStock(
            item.inventoryItemId!,
            adjustment.toInt(),
            '${bill.type == 'sales' ? 'Sold' : 'Purchased'} ${item.quantity} in bill ${bill.invoiceNumber}',
          );
          
          print('    ✅ Stock update SUCCESS');
          
          // Verify the update worked
          final updatedItem = await _inventoryService.getInventoryItem(item.inventoryItemId!);
          print('    Verified stock: ${updatedItem.quantity}');
          
        } catch (e) {
          print('    ❌ Stock update FAILED: $e');
          print('    Stack trace: ${e.toString()}');
        }
      } else {
        print('    ⚠️ No inventoryItemId - SKIPPING stock update');
        print('    This means the item was not selected from inventory');
      }
    }
  }

  /// Handle inventory updates for EDITING bills
  Future<void> _handleInventoryUpdatesForEdit(Bill oldBill, Bill newBill) async {
    print('🔄 Handling inventory updates for edited bill');
    print('  Old bill type: ${oldBill.type}, New bill type: ${newBill.type}');
    
    // Track items by inventoryId to calculate differences
    final Map<String, int> oldQuantities = {};
    final Map<String, int> newQuantities = {};
    
    // Collect old quantities
    for (final item in oldBill.items) {
      if (item.inventoryItemId != null && item.inventoryItemId!.isNotEmpty) {
        oldQuantities[item.inventoryItemId!] = item.quantity.toInt();
      }
    }
    
    // Collect new quantities
    for (final item in newBill.items) {
      if (item.inventoryItemId != null && item.inventoryItemId!.isNotEmpty) {
        newQuantities[item.inventoryItemId!] = item.quantity.toInt();
      }
    }
    
    // Calculate adjustments for each inventory item
    final allItemIds = {
      ...oldQuantities.keys,
      ...newQuantities.keys,
    };
    
    for (final itemId in allItemIds) {
      final oldQty = oldQuantities[itemId] ?? 0;
      final newQty = newQuantities[itemId] ?? 0;
      final difference = newQty - oldQty;
      
      if (difference != 0) {
        try {
          // Determine adjustment based on bill type
          int adjustment = difference;
          
          if (newBill.type == 'sales') {
            // For sales: if quantity increased, decrease more stock; if decreased, add back stock
            adjustment = -difference;
          }
          // For purchases: if quantity increased, increase more stock; if decreased, decrease stock
          
          print('  📊 Adjusting stock for item $itemId: $oldQty → $newQty (diff: $difference, adj: $adjustment)');
          
          await _inventoryService.adjustStock(
            itemId,
            adjustment,
            'Updated from $oldQty to $newQty in bill ${newBill.invoiceNumber}',
          );
          
          print('  ✅ Stock adjustment completed for item $itemId');
        } catch (e) {
          print('  ❌ Error adjusting stock for item $itemId: $e');
        }
      } else {
        print('  ⏭️ No quantity change for item $itemId, skipping update');
      }
    }
  }

  void _filterItems() {
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredItems = _inventoryItems.where((item) {
          return item.name.toLowerCase().contains(query) ||
                 item.sku.toLowerCase().contains(query) ||
                 item.category.toLowerCase().contains(query);
        }).toList();
      });
    } else if (_selectedCategory != null && _selectedCategory != 'All') {
      setState(() {
        _filteredItems = _inventoryItems
            .where((item) => item.category == _selectedCategory)
            .toList();
      });
    } else {
      setState(() {
        _filteredItems = List.from(_inventoryItems);
      });
    }
  }

  Future<void> _loadSuppliersAndCustomers() async {
    try {
      if (widget.type == 'purchase') {
        final supplierService = SupplierService(widget.userMobile);
        _suppliers = await supplierService.getSuppliers().first;
        _supplierNames = _suppliers.map((s) => s.name).toList();
        print('✅ Loaded ${_suppliers.length} suppliers');
      } else if (widget.type == 'sales') {
        final customerService = CustomerService(widget.userMobile);
        _customers = await customerService.getCustomers().first;
        _customerNames = _customers.map((c) => c.name).toList();
        print('✅ Loaded ${_customers.length} customers');
      }
      
      if (mounted) setState(() {});
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
    
    // Initialize controllers for existing items
    _initControllersFromItems();
    _calculateTotals();
  }

  void _initControllersFromItems() {
    // Clear existing controllers
    for (final c in _descControllers) {
      c.dispose();
    }
    for (final c in _qtyControllers) {
      c.dispose();
    }
    for (final c in _priceControllers) {
      c.dispose();
    }
    
    _descControllers.clear();
    _qtyControllers.clear();
    _priceControllers.clear();
    
    // Create new controllers for each item
    for (final item in _items) {
      _descControllers.add(TextEditingController(text: item.description));
      _qtyControllers.add(TextEditingController(text: item.quantity.toString()));
      _priceControllers.add(TextEditingController(text: item.price.toStringAsFixed(2)));
    }
  }

  void _calculateTotals() {
    _subtotal = _items.fold(0.0, (sum, item) {
      return sum + (item.quantity * item.price);
    });
    
    final gstRate = double.tryParse(_gstRateController.text) ?? 0.0;
    _gstAmount = _isGST ? (_subtotal * gstRate / 100) : 0.0;
    _totalAmount = _subtotal + _gstAmount;
    final amountPaid = double.tryParse(_amountPaidController.text) ?? 0.0;
    _amountDue = _totalAmount - amountPaid;
    
    if (mounted) setState(() {});
  }

  void _onPartySelected(String? value) {
    if (value == null || value.isEmpty) return;
    
    setState(() {
      _partyNameController.text = value;
    });
    
    if (widget.type == 'purchase') {
      for (final supplier in _suppliers) {
        if (supplier.name == value) {
          _partyPhoneController.text = supplier.phone;
          _partyAddressController.text = supplier.address;
          break;
        }
      }
    } else if (widget.type == 'sales') {
      for (final customer in _customers) {
        if (customer.name == value) {
          _partyPhoneController.text = customer.mobile;
          _partyAddressController.text = customer.address;
          break;
        }
      }
    }
  }

  void _showAddPartyDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final partyType = widget.type == 'sales' ? 'Customer' : 'Supplier';
    
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final phoneController = TextEditingController();
        final addressController = TextEditingController();
        
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Add New $partyType',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: '$partyType Name *',
                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Address',
                    labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
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
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please enter name'),
                      backgroundColor: colorScheme.error,
                    ),
                  );
                  return;
                }
                
                try {
                  if (widget.type == 'purchase') {
                    final supplierService = SupplierService(widget.userMobile);
                    final newSupplier = Supplier.create(
                      name: nameController.text,
                      phone: phoneController.text,
                      userMobile: widget.userMobile,
                      address: addressController.text,
                      email: '',
                    );
                    await supplierService.addSupplier(newSupplier);
                    _suppliers = await supplierService.getSuppliers().first;
                    _supplierNames = _suppliers.map((s) => s.name).toList();
                  } else if (widget.type == 'sales') {
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
                    _customers = await customerService.getCustomers().first;
                    _customerNames = _customers.map((c) => c.name).toList();
                  }
                  
                  _onPartySelected(nameController.text);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$partyType added successfully'),
                      backgroundColor: colorScheme.secondary,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding $partyType: $e'),
                      backgroundColor: colorScheme.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showInventorySelectionDialog(int itemIndex) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: EdgeInsets.all(16),
              backgroundColor: colorScheme.surface,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Select Item from Inventory',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Search items...',
                          hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                          prefixIcon: Icon(Icons.search, color: colorScheme.onSurface.withOpacity(0.5)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colorScheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                        ),
                        onChanged: (value) {
                          _filterItems();
                        },
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        dropdownColor: colorScheme.surface,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Filter by Category',
                          labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colorScheme.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colorScheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'All', 
                            child: Text('All Categories', style: TextStyle(color: colorScheme.onSurface)),
                          ),
                          ..._categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category, style: TextStyle(color: colorScheme.onSurface)),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                            _filterItems();
                          });
                        },
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    Expanded(
                      child: _filteredItems.isEmpty
                          ? Center(
                              child: Text(
                                'No items found',
                                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                              ),
                            )
                          : Container(
                              color: colorScheme.background,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _filteredItems.length,
                                itemBuilder: (context, index) {
                                  final inventoryItem = _filteredItems[index];
                                  return Card(
                                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    color: colorScheme.surface,
                                    child: ListTile(
                                      title: Text(
                                        inventoryItem.name,
                                        style: TextStyle(color: colorScheme.onSurface),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Selling Price: ₹${inventoryItem.price.toStringAsFixed(2)}',
                                            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                                          ),
                                          Text(
                                            'Stock: ${inventoryItem.quantity} ${inventoryItem.unit}',
                                            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                                          ),
                                          Text(
                                            'Category: ${inventoryItem.category}',
                                            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                                          ),
                                        ],
                                      ),
                                      trailing: ElevatedButton(
                                        onPressed: () {
                                          _addInventoryItemToBill(itemIndex, inventoryItem);
                                          Navigator.pop(context);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorScheme.primary,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text('Select'),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addInventoryItemToBill(int itemIndex, InventoryItem inventoryItem) {
    print('🔄 Adding inventory item to bill at index $itemIndex');
    print('  Item name: ${inventoryItem.name}');
    print('  Inventory ID: ${inventoryItem.id}');
    print('  Unit: ${inventoryItem.unit}');
    print('  Price: ${inventoryItem.price}');
    
    // Create a new BillItem with ALL properties
    final newBillItem = BillItem.create(
      description: inventoryItem.name,
      quantity: 1.0,
      price: inventoryItem.price,
      inventoryItemId: inventoryItem.id,
      unit: inventoryItem.unit,
      category: inventoryItem.category,
      name: inventoryItem.name,
    );
    
    print('  Created new BillItem:');
    print('    Inventory ID in newBillItem: ${newBillItem.inventoryItemId}');
    print('    Unit in newBillItem: ${newBillItem.unit}');
    
    // Update the items array FIRST
    final List<BillItem> updatedItems = List.from(_items);
    updatedItems[itemIndex] = newBillItem;
    
    setState(() {
      // Update the main items array
      _items = updatedItems;
      
      // Update controllers
      _descControllers[itemIndex].text = inventoryItem.name;
      _qtyControllers[itemIndex].text = '1';
      _priceControllers[itemIndex].text = inventoryItem.price.toStringAsFixed(2);
      
      _calculateTotals();
    });
    
    // Verify after setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('✅ Verification after setState:');
      print('  Description in _items: ${_items[itemIndex].description}');
      print('  Inventory ID in _items: ${_items[itemIndex].inventoryItemId}');
      print('  Unit in _items: ${_items[itemIndex].unit}');
      print('  Price in _items: ${_items[itemIndex].price}');
    });
  }

  Future<InventoryItem?> _getInventoryItemById(String id) async {
    try {
      return await _inventoryService.getInventoryItem(id);
    } catch (e) {
      print('❌ Error getting inventory item: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final partyList = widget.type == 'sales' ? _customerNames : _supplierNames;
    final partyType = widget.type == 'sales' ? 'Customer' : 'Supplier';
    final iconColor = widget.type == 'sales' ? colorScheme.secondary : colorScheme.tertiary;
    final icon = widget.type == 'sales' ? Icons.person : Icons.local_shipping_outlined;
    
    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(
          widget.billToEdit != null 
            ? 'Edit ${widget.type == 'sales' ? 'Sales' : 'Purchase'}'
            : 'New ${widget.type == 'sales' ? 'Sales' : 'Purchase'}',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: colorScheme.onSurface),
            onPressed: _isLoading ? null : _saveBill,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_invoiceNumber != null)
                      Card(
                        color: (widget.type == 'sales' 
                          ? colorScheme.secondary 
                          : colorScheme.tertiary).withOpacity(0.1),
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
                    
                    Text(
                      'Party Details',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Enhanced dropdown with mobile-optimized styling
                    Container(
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.outline,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _partyNameController.text.isNotEmpty && 
                                partyList.contains(_partyNameController.text)
                                ? _partyNameController.text 
                                : null,
                          isExpanded: true,
                          dropdownColor: colorScheme.surface,
                          hint: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Select $partyType',
                              style: TextStyle(
                                fontSize: 15,
                                color: colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ),
                          icon: Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _partyNameController.text.isNotEmpty 
                                  ? colorScheme.primary
                                  : colorScheme.onSurface.withOpacity(0.5),
                              size: 20,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                          items: [
                            // Placeholder item
                            DropdownMenuItem<String>(
                              value: null,
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 48),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.help_outline_rounded,
                                      size: 18,
                                      color: colorScheme.onSurface.withOpacity(0.4),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Select $partyType',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Party list items
                            ...partyList.map((name) {
                              final bool isSelected = _partyNameController.text == name;
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Container(
                                  constraints: const BoxConstraints(minHeight: 48),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        partyType.toLowerCase() == 'customer' 
                                            ? Icons.person_outline_rounded
                                            : Icons.store_outlined,
                                        size: 18,
                                        color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      
                                      if (isSelected)
                                        Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            
                            // Add New Party option
                            DropdownMenuItem<String>(
                              value: 'new',
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 48),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: colorScheme.outline),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 16,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Add New $partyType',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16,
                                      color: colorScheme.primary.withOpacity(0.7),
                                    ),
                                  ],
                                ),
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
                            prefixIcon: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(
                                icon, 
                                color: iconColor,
                                size: 20,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            labelText: '$partyType Name *',
                            labelStyle: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                            floatingLabelBehavior: FloatingLabelBehavior.auto,
                            floatingLabelStyle: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          elevation: isDark ? 8 : 4,
                          borderRadius: BorderRadius.circular(12),
                          menuMaxHeight: 400,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _partyPhoneController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: widget.type == 'sales' ? 'Customer Mobile' : 'Supplier Phone',
                        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                        ),
                        prefixIcon: Icon(Icons.phone, color: colorScheme.primary),
                        filled: true,
                        fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _partyAddressController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: widget.type == 'sales' ? 'Customer Address' : 'Supplier Address',
                        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                        ),
                        prefixIcon: Icon(Icons.location_on, color: colorScheme.primary),
                        filled: true,
                        fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                      ),
                      maxLines: 2,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Card(
                      color: colorScheme.surface,
                      elevation: isDark ? 4 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Icon(Icons.receipt, color: colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              'GST Invoice',
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                            const Spacer(),
                            Switch(
                              value: _isGST,
                              onChanged: (value) {
                                setState(() {
                                  _isGST = value;
                                  _calculateTotals();
                                });
                              },
                              activeColor: colorScheme.primary,
                              activeTrackColor: colorScheme.primary.withOpacity(0.5),
                              inactiveThumbColor: colorScheme.onSurface.withOpacity(0.5),
                              inactiveTrackColor: colorScheme.onSurface.withOpacity(0.1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _isSelectingFromInventory = !_isSelectingFromInventory;
                                });
                              },
                              icon: Icon(
                                _isSelectingFromInventory ? Icons.list : Icons.inventory,
                                color: _isSelectingFromInventory ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
                              ),
                              tooltip: _isSelectingFromInventory 
                                  ? 'Manual Entry' 
                                  : 'Select from Inventory',
                            ),
                            IconButton(
                              onPressed: _addItem,
                              icon: Icon(Icons.add_circle, color: colorScheme.primary),
                              tooltip: 'Add Item',
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        return _buildItemRow(index);
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Card(
                      color: colorScheme.primary.withOpacity(0.1),
                      elevation: isDark ? 4 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildTotalRow('Subtotal:', _subtotal),
                            if (_isGST) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'GST Rate (%):',
                                    style: TextStyle(color: colorScheme.onSurface),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      controller: _gstRateController,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(color: colorScheme.onSurface),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true),
                                      decoration: InputDecoration(
                                        border: UnderlineInputBorder(
                                          borderSide: BorderSide(color: colorScheme.outline),
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(color: colorScheme.outline),
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                                        ),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (value) => _calculateTotals(),
                                    ),
                                  ),
                                ],
                              ),
                              _buildTotalRow('GST Amount:', _gstAmount),
                            ],
                            Divider(color: colorScheme.outline),
                            _buildTotalRow('Total Amount:', _totalAmount, isTotal: true),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _amountPaidController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Amount Paid',
                        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                        ),
                        prefixIcon: Icon(Icons.payments, color: colorScheme.primary),
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(color: colorScheme.onSurface),
                        filled: true,
                        fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (value) => _calculateTotals(),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Card(
                      color: colorScheme.surface,
                      elevation: isDark ? 4 : 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Amount Due:',
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '₹${_amountDue.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _amountDue > 0 ? colorScheme.error : colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    TextFormField(
                      controller: _notesController,
                      style: TextStyle(color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                        ),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveBill,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: Text(
                          _isLoading ? 'Saving...' : 'Save Transaction',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: isDark ? 4 : 2,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final item = _items[index];
    final isFromInventory = item.inventoryItemId != null && item.inventoryItemId!.isNotEmpty;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      color: colorScheme.surface,
      elevation: isDark ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _descControllers[index],
                    readOnly: isFromInventory,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      suffixIcon: isFromInventory
                          ? Tooltip(
                              message: 'From Inventory',
                              child: Icon(Icons.inventory, color: colorScheme.secondary, size: 16),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                    ),
                    onChanged: (value) {
                      if (!isFromInventory) {
                        setState(() {
                          _items[index] = item.copyWith(description: value);
                        });
                        _calculateTotals();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                
                if (_isSelectingFromInventory && !isFromInventory)
                  IconButton(
                    onPressed: () => _showInventorySelectionDialog(index),
                    icon: Icon(Icons.search, color: colorScheme.primary),
                    tooltip: 'Select from Inventory',
                  ),
                
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
                    controller: _qtyControllers[index],
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      filled: true,
                      fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final qty = double.tryParse(value) ?? 1.0;
                      setState(() {
                        _items[index] = item.copyWith(quantity: qty);
                      });
                      _calculateTotals();
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                Expanded(
                  child: TextFormField(
                    controller: _priceControllers[index],
                    readOnly: isFromInventory,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Price',
                      labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(color: colorScheme.onSurface),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      suffixIcon: isFromInventory
                          ? Tooltip(
                              message: 'Price from inventory',
                              child: Icon(Icons.lock, color: colorScheme.primary, size: 16),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: isFromInventory ? null : (value) {
                      final price = double.tryParse(value) ?? 0.0;
                      setState(() {
                        _items[index] = item.copyWith(price: price);
                      });
                      _calculateTotals();
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                if (item.unit != null && item.unit!.isNotEmpty)
                  Expanded(
                    child: Card(
                      color: colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          item.unit!,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(width: 8),
                
                Expanded(
                  child: Card(
                    color: colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        '₹${(item.quantity * item.price).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            if (isFromInventory)
              FutureBuilder<InventoryItem?>(
                future: _getInventoryItemById(item.inventoryItemId!),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final inventoryItem = snapshot.data!;
                    if (item.quantity > inventoryItem.quantity) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '⚠️ Insufficient stock! Available: ${inventoryItem.quantity}',
                          style: TextStyle(color: colorScheme.error, fontSize: 12),
                        ),
                      );
                    } else if (inventoryItem.quantity < 10) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '⚠️ Low stock! Available: ${inventoryItem.quantity}',
                          style: TextStyle(color: colorScheme.tertiary, fontSize: 12),
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        ),
      ),
    );
  }
 
  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Future<void> _saveBill() async {
    print('💾 Saving bill...');
    print('  Bill type: ${widget.type}');
    print('  Is edit mode: ${widget.billToEdit != null}');

    if (widget.billToEdit != null) {
      print('  Bill ID: ${widget.billToEdit!.id}');
      print('  Original Invoice Number: ${widget.billToEdit!.invoiceNumber}');
    }
    
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }
    
    // Validate party name
    if (_partyNameController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a ${widget.type == 'sales' ? 'customer' : 'supplier'}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }
    
    // Validate items
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.description.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enter item description'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
      if (item.price <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Item price must be greater than 0'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
      if (item.quantity <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Item quantity must be greater than 0'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }
    }
    
    // Validate inventory stock for sales bills
    if (widget.type == 'sales') {
      bool hasInsufficientStock = false;
      String errorMessage = '';
      String errorItemName = '';
      
      for (final item in _items) {
        // Only check inventory if item has a valid inventoryItemId
        if (item.inventoryItemId != null && item.inventoryItemId!.isNotEmpty) {
          try {
            final inventoryItem = await _inventoryService.getInventoryItem(item.inventoryItemId!);
            
            if (item.quantity > inventoryItem.quantity) {
              hasInsufficientStock = true;
              errorMessage = 'Insufficient stock for ${inventoryItem.name}. '
                  'Available: ${inventoryItem.quantity}, Requested: ${item.quantity}';
              errorItemName = inventoryItem.name;
              break;
            }
          } catch (e) {
            print('⚠️ Error checking inventory stock for item ${item.inventoryItemId}: $e');
            // Don't fail if we can't check inventory, just log it
          }
        }
      }
      
      if (hasInsufficientStock) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }
    
    // Check if widget is still mounted
    if (!mounted) {
      print('⚠️ Widget is disposed, skipping save');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // DEBUG: Log current items before processing
      print('🔄 Processing items before creating bill:');
      for (int i = 0; i < _items.length; i++) {
        final item = _items[i];
        print('  Item $i: ${item.description}');
        print('    Inventory ID from UI: ${item.inventoryItemId}');
        print('    Unit from UI: ${item.unit}');
      }
      
      // Process items - preserve the inventoryItemId from the original items
      final processedItems = _items.map((item) {
        return BillItem.create(
          description: item.description,
          quantity: item.quantity,
          price: item.price,
          inventoryItemId: item.inventoryItemId ?? '',
          unit: item.unit ?? '',
          category: item.category ?? '',
          name: item.name ?? item.description,
        );
      }).toList();
      
      // DEBUG: Log processed items
      print('✅ Processed items for bill:');
      for (int i = 0; i < processedItems.length; i++) {
        final item = processedItems[i];
        print('  Item $i: ${item.description}');
        print('    Inventory ID: ${item.inventoryItemId}');
        print('    Unit: ${item.unit}');
      }
      
      // Use the factory method to create the bill
      final bill = Bill.create(
        type: widget.type,
        invoiceNumber: _invoiceNumber!,
        partyName: _partyNameController.text,
        userMobile: widget.userMobile,
        partyPhone: _partyPhoneController.text,
        partyAddress: _partyAddressController.text,
        items: processedItems,
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
      
      print('📋 Bill created successfully:');
      print('  Type: ${bill.type}');
      print('  Invoice: ${bill.invoiceNumber}');
      print('  Party: ${bill.partyName}');
      print('  Items: ${bill.items.length}');
      
      // Log item details for debugging
      for (int i = 0; i < bill.items.length; i++) {
        final item = bill.items[i];
        print('    Item ${i + 1}: ${item.description}');
        print('      Qty: ${item.quantity}, Price: ${item.price}');
        print('      Inventory ID: "${item.inventoryItemId}"');
        print('      Unit: "${item.unit}"');
        print('      Has inventory ID: ${item.inventoryItemId != null && item.inventoryItemId!.isNotEmpty}');
      }
      
      print('  Subtotal: $_subtotal');
      print('  GST: $_gstAmount');
      print('  Total: $_totalAmount');
      
      if (widget.billToEdit != null) {
        print('✏️ Updating existing bill...');
        print('  Original ID: ${widget.billToEdit!.id}');
        
        final updatedBill = bill.copyWith(id: widget.billToEdit!.id);
        print('  Updated bill ID: ${updatedBill.id}');
        
        try {
          await widget.billService.updateBill(updatedBill);
          print('✅ Bill updated successfully in database');
          
          // Update inventory stock for edited bills
          await _handleInventoryUpdatesForEdit(widget.billToEdit!, updatedBill);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Transaction updated successfully'),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e, stackTrace) {
          print('❌ Error in updateBill: $e');
          print('Stack trace: $stackTrace');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update transaction: ${e.toString()}'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      } else {
        print('➕ Adding new bill to database...');
        try {
          await widget.billService.addBill(bill);
          print('✅ Bill added successfully to database');
          
          // Handle inventory stock updates for BOTH sales and purchases
          await _handleInventoryUpdatesForNewBill(bill);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Transaction saved successfully'),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e, stackTrace) {
          print('❌ Error adding bill to database: $e');
          print('Stack trace: $stackTrace');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save transaction: ${e.toString()}'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
      
      // Check if still mounted before navigating
      if (mounted) {
        print('✅ Navigating back...');
        Navigator.pop(context);
      } else {
        print('⚠️ Widget was disposed before navigation');
      }
      
    } catch (e, stackTrace) {
      print('❌ Unexpected error in saveBill process: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transaction: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Check if mounted before setState
      if (mounted) {
        setState(() => _isLoading = false);
      } else {
        print('⚠️ Widget disposed, cannot update loading state');
      }
    }
  }
  
  void _addItem() {
    setState(() {
      _items.add(BillItem.create(
        description: '',
        quantity: 1.0,
        price: 0.0,
        inventoryItemId: '',
        unit: '',
      ));
      
      _descControllers.add(TextEditingController());
      _qtyControllers.add(TextEditingController(text: '1'));
      _priceControllers.add(TextEditingController(text: '0.00'));
      
      _calculateTotals();
    });
  }

  void _removeItem(int index) {
    if (_items.length > 1) {
      setState(() {
        _items.removeAt(index);
        
        _descControllers[index].dispose();
        _qtyControllers[index].dispose();
        _priceControllers[index].dispose();
        
        _descControllers.removeAt(index);
        _qtyControllers.removeAt(index);
        _priceControllers.removeAt(index);
        
        _calculateTotals();
      });
    }
  }

  void _addEmptyItem() {
    setState(() {
      _items.add(BillItem.create(
        description: '',
        quantity: 1.0,
        price: 0.0,
        inventoryItemId: '',
        unit: '',
      ));
      
      _descControllers.add(TextEditingController());
      _qtyControllers.add(TextEditingController(text: '1'));
      _priceControllers.add(TextEditingController(text: '0.00'));
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTotals();
    });
  }

  @override
  void dispose() {
    for (final c in _descControllers) {
      c.dispose();
    }
    for (final c in _qtyControllers) {
      c.dispose();
    }
    for (final c in _priceControllers) {
      c.dispose();
    }
    
    _partyNameController.dispose();
    _partyPhoneController.dispose();
    _partyAddressController.dispose();
    _gstRateController.dispose();
    _amountPaidController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}