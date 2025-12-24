import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/inventory_item_model.dart';


class AddEditItemScreen extends StatefulWidget {
  final InventoryService inventoryService;
  final InventoryItem? item;
  final String userMobile;
  final String? initialCategory; // ADD THIS
  
  const AddEditItemScreen({
    Key? key,
    required this.inventoryService,
    this.item,
    required this.userMobile,
    this.initialCategory, // ADD THIS
  }) : super(key: key); 

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _skuController;
  late TextEditingController _categoryController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _quantityController;
  late TextEditingController _lowStockController;
  late TextEditingController _unitController;
  late TextEditingController _locationController;
  late TextEditingController _supplierController;

  bool _isLoading = false;
  bool _skuChecking = false;
  String? _skuError;
  List<String> _categories = [];
  List<String> _suppliers = []; // Add this for suppliers list
  Map<String, String> _supplierMap = {}; // Map supplier ID to name

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    print('🚀 Edit mode: ${widget.item != null}');
  if (item != null) {
    print('📦 Editing item: ${item.name}');
    print('📦 Item ID: ${item.id}');
    print('📦 Item SKU: ${item.sku}');
    print('📦 Item Price: ${item.price}');
    print('📦 Item Cost: ${item.cost}');
    print('📦 Item Quantity: ${item.quantity}');
    print('📦 Item Category: ${item.category}');
    print('📦 Item Supplier: ${item.supplierId}');
    print('📦 Item Supplier Name: ${item.supplierName}');
  }
    
    // Initialize controllers with item data or defaults
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _skuController = TextEditingController(text: item?.sku ?? '');
    
    // Use initialCategory if provided, otherwise use item's category or empty
    if (widget.initialCategory != null) {
      _categoryController = TextEditingController(text: widget.initialCategory!);
    } else {
      _categoryController = TextEditingController(text: item?.category ?? '');
    }
    
    // Initialize price and cost with proper formatting
    _priceController = TextEditingController(text: item?.price.toString() ?? '');
    _costController = TextEditingController(text: item?.cost.toString() ?? '');
    _quantityController = TextEditingController(text: item?.quantity.toString() ?? '0');
    _lowStockController = TextEditingController(text: item?.lowStockThreshold.toString() ?? '10');
    _unitController = TextEditingController(text: item?.unit ?? 'pcs');
    _locationController = TextEditingController(text: item?.location ?? '');
    _supplierController = TextEditingController(text: item?.supplierId ?? '');

  print('📝 Controller values:');
  print('  Name: ${_nameController.text}');
  print('  Category: ${_categoryController.text}');
  print('  Supplier: ${_supplierController.text}');
  print('  Price: ${_priceController.text}');
  print('  Cost: ${_costController.text}');
    // Load categories and suppliers for dropdown
    _loadCategories();
    _loadSuppliers();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await widget.inventoryService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      // Assuming you have a method to get suppliers from your service
      // If not, you'll need to add it to InventoryService
      final suppliers = await widget.inventoryService.getSuppliers();
      setState(() {
        _suppliers = suppliers;
        // You might want to create a map of supplier IDs to names
        // This depends on your data structure
      });
    } catch (e) {
      print('Error loading suppliers: $e');
    }
  }

  Future<void> _checkSku() async {
    if (_skuController.text.isEmpty) return;
    
    setState(() {
      _skuChecking = true;
      _skuError = null;
    });

    try {
      final exists = await widget.inventoryService.skuExists(
        _skuController.text,
        excludeId: widget.item?.id,
      );
      
      if (exists && mounted) {
        setState(() {
          _skuError = 'SKU already exists';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _skuError = 'Error checking SKU';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _skuChecking = false;
        });
      }
    }
  }

Future<void> _saveItem() async {
  // Add debug print
  print('💾 Saving item...');
  print('  Is edit mode: ${widget.item != null}');
  if (widget.item != null) {
    print('  Item ID: ${widget.item!.id}');
  }
  
  setState(() => _isLoading = true);
  
  try {
    // Parse values with defaults for empty fields
    final name = _nameController.text.trim();
    final sku = _skuController.text.trim();
    final category = _categoryController.text.trim();
    final unit = _unitController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final supplierName = _supplierController.text.trim();
    
    // Use 0.0 as default for numeric fields if empty
    final price = _priceController.text.isNotEmpty 
        ? double.tryParse(_priceController.text) ?? 0.0 
        : 0.0;
    final cost = _costController.text.isNotEmpty 
        ? double.tryParse(_costController.text) ?? 0.0 
        : 0.0;
    final quantity = _quantityController.text.isNotEmpty 
        ? int.tryParse(_quantityController.text) ?? 0 
        : 0;
    final lowStockThreshold = _lowStockController.text.isNotEmpty 
        ? int.tryParse(_lowStockController.text) ?? 10 
        : 10;

    // Debug the parsed values
    print('📋 Parsed values:');
    print('  Name: $name');
    print('  SKU: $sku');
    print('  Category: $category');
    print('  Price: $price');
    print('  Cost: $cost');
    print('  Quantity: $quantity');
    print('  Supplier: $supplierName');
    
    // Get supplier ID if supplier name is selected
    String? supplierId;
    if (supplierName.isNotEmpty) {
      try {
        final supplierDetails = await widget.inventoryService.getSupplierDetails(supplierName);
        supplierId = supplierDetails?['id'] as String?;
      } catch (e) {
        print('⚠️ Could not find supplier ID for name: $supplierName');
      }
    }

    final item = InventoryItem(
      id: widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.isNotEmpty ? name : 'New Product',
      description: description,
      sku: sku.isNotEmpty ? sku : 'SKU${DateTime.now().millisecondsSinceEpoch}',
      category: category.isNotEmpty ? category : 'Uncategorized',
      price: price,
      cost: cost,
      quantity: quantity,
      lowStockThreshold: lowStockThreshold,
      unit: unit.isNotEmpty ? unit : 'pcs',
      location: location.isNotEmpty ? location : null,
      supplierId: supplierId ?? widget.item?.supplierId,
      supplierName: supplierName.isNotEmpty ? supplierName : null,
      userMobile: widget.userMobile,
    );

    if (widget.item == null) {
      // Add new item
      print('➕ Adding new item...');
      final id = await widget.inventoryService.addInventoryItem(item);
      print('✅ Item added with ID: $id');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      // Update existing item
      print('✏️ Updating existing item with ID: ${widget.item!.id}');
      await widget.inventoryService.updateInventoryItem(item);
      print('✅ Item updated successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }

    Navigator.pop(context, true); // Pass true to indicate success
  } catch (e, stackTrace) {
    print('❌ Error saving item: $e');
    print('Stack trace: $stackTrace');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add New Item' : 'Edit Item'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name
                        _buildInputSection(
                          title: 'Product Information',
                          children: [
                            _buildInputField(
                              controller: _nameController,
                              label: 'Product Name',
                              icon: Icons.shopping_bag_outlined,
                              hintText: 'Enter product name',
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              controller: _descriptionController,
                              label: 'Description (Optional)',
                              icon: Icons.description_outlined,
                              hintText: 'Enter description',
                              maxLines: 2,
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // SKU & Category
                        _buildInputSection(
                          title: 'Identification',
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    controller: _skuController,
                                    label: 'SKU Code',
                                    icon: Icons.tag_outlined,
                                    hintText: 'Enter SKU',
                                    errorText: _skuError,
                                    suffixIcon: _skuChecking
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : null,
                                    onChanged: (value) => _checkSku(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCategoryDropdown(),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Pricing - CHANGED TO INDIAN RUPEES
                        _buildInputSection(
                          title: 'Pricing',
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    controller: _priceController,
                                    label: 'Selling Price',
                                    icon: Icons.currency_rupee, // Changed to Indian Rupee icon
                                    hintText: '0.00',
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInputField(
                                    controller: _costController,
                                    label: 'Cost Price',
                                    icon: Icons.currency_rupee, // Changed to Indian Rupee icon
                                    hintText: '0.00',
                                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Stock Information
                        _buildInputSection(
                          title: 'Stock Information',
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    controller: _quantityController,
                                    label: 'Current Stock',
                                    icon: Icons.inventory_outlined,
                                    hintText: '0',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInputField(
                                    controller: _lowStockController,
                                    label: 'Reorder Level',
                                    icon: Icons.warning_outlined,
                                    hintText: '10',
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    controller: _unitController,
                                    label: 'Unit',
                                    icon: Icons.square_foot_outlined,
                                    hintText: 'pcs, kg, etc.',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInputField(
                                    controller: _locationController,
                                    label: 'Location (Optional)',
                                    icon: Icons.location_on_outlined,
                                    hintText: 'Storage location',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Supplier Information - CHANGED TO DROPDOWN
                        _buildInputSection(
                          title: 'Supplier Information (Optional)',
                          children: [
                            _buildSupplierDropdown(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Bottom Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.item == null ? 'Add Item' : 'Save Changes',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _categoryController.text.isNotEmpty && _categories.contains(_categoryController.text)
                  ? _categoryController.text
                  : null,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Select Category', style: TextStyle(color: Colors.grey)),
                ),
                ..._categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                const DropdownMenuItem(
                  value: 'new',
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Add New Category', style: TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == 'new') {
                  _showAddCategoryDialog();
                } else if (value != null) {
                  setState(() {
                    _categoryController.text = value;
                  });
                } else {
                  setState(() {
                    _categoryController.text = '';
                  });
                }
              },
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: InputBorder.none,
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }
  // ADD THIS NEW WIDGET FOR SUPPLIER DROPDOWN
// In your _buildSupplierDropdown() method, change lines 574-581 to:

Widget _buildSupplierDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supplier',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _supplierController.text.isNotEmpty && _suppliers.contains(_supplierController.text) 
                  ? _supplierController.text 
                  : null,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Select Supplier', style: TextStyle(color: Colors.grey)),
                ),
                ..._suppliers.map((supplier) {
                  return DropdownMenuItem(
                    value: supplier,
                    child: Text(supplier),
                  );
                }).toList(),
                const DropdownMenuItem(
                  value: 'new',
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Add New Supplier', style: TextStyle(color: Colors.blue)),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == 'new') {
                  _showAddSupplierDialog();
                } else if (value != null) {
                  setState(() {
                    _supplierController.text = value;
                  });
                } else {
                  setState(() {
                    _supplierController.text = '';
                  });
                }
              },
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.local_shipping_outlined, color: Colors.blue[400]),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: InputBorder.none,
              ),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              isExpanded: true,
              validator: (value) {
                return null; // Optional: Add validation if needed
              },
            ),
          ),
        ),
      ],
    );
  }
  void _showAddCategoryDialog() {
    final categoryController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Category'),
          content: TextField(
            controller: categoryController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter category name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (categoryController.text.trim().isNotEmpty) {
                  try {
                    await widget.inventoryService.addCategory(categoryController.text.trim());
                    setState(() {
                      _categories.add(categoryController.text.trim());
                      _categoryController.text = categoryController.text.trim();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Category added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding category: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // ADD THIS METHOD FOR ADDING NEW SUPPLIER
  void _showAddSupplierDialog() {
    final supplierController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Supplier'),
          content: TextField(
            controller: supplierController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter supplier name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (supplierController.text.trim().isNotEmpty) {
                  try {
                    // Assuming you have a method to add supplier
                    // You'll need to add this to your InventoryService
                    await widget.inventoryService.addSupplier(supplierController.text.trim());
                    setState(() {
                      _suppliers.add(supplierController.text.trim());
                      _supplierController.text = supplierController.text.trim();
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Supplier added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding supplier: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    String? errorText,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: Colors.blue.shade400),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
            errorText: errorText,
            errorStyle: const TextStyle(fontSize: 12),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
        ),
      ],
    );
  }
}