import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/inventory_item_model.dart';

class AddEditItemScreen extends StatefulWidget {
  final InventoryService inventoryService;
  final InventoryItem? item;
  final String userMobile;
  final String? initialCategory;
  
  const AddEditItemScreen({
    super.key,
    required this.inventoryService,
    this.item,
    required this.userMobile,
    this.initialCategory,
  }); 

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
  List<String> _suppliers = [];
  final Map<String, String> _supplierMap = {};

  // Validation error messages
  String? _nameError;
  String? _priceError;
  String? _costError;
  String? _quantityError;
  String? _lowStockError;
  String? _unitError;
  String? _categoryError;
  String? _skuValidationError;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    
    // Initialize controllers
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _skuController = TextEditingController(text: item?.sku ?? '');
    
    if (widget.initialCategory != null) {
      _categoryController = TextEditingController(text: widget.initialCategory!);
    } else {
      _categoryController = TextEditingController(text: item?.category ?? '');
    }
    
    _priceController = TextEditingController(text: item?.price.toString() ?? '');
    _costController = TextEditingController(text: item?.cost.toString() ?? '');
    _quantityController = TextEditingController(text: item?.quantity.toString() ?? '0');
    _lowStockController = TextEditingController(text: item?.lowStockThreshold.toString() ?? '10');
    _unitController = TextEditingController(text: item?.unit ?? 'pcs');
    _locationController = TextEditingController(text: item?.location ?? '');
    _supplierController = TextEditingController(text: item?.supplierId ?? '');

    // Load categories and suppliers
    _loadCategories();
    _loadSuppliers();
  }

  // ============ VALIDATION METHODS ============
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Product name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 100) {
      return 'Name must be less than 100 characters';
    }
    return null;
  }

  String? _validateSKU(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'SKU is required';
    }
    if (value.trim().length < 3) {
      return 'SKU must be at least 3 characters';
    }
    if (value.trim().length > 50) {
      return 'SKU must be less than 50 characters';
    }
    // Check for valid SKU format (alphanumeric with optional dashes/underscores)
    if (!RegExp(r'^[a-zA-Z0-9\-_]+$').hasMatch(value.trim())) {
      return 'SKU can only contain letters, numbers, dashes, and underscores';
    }
    return null;
  }

  String? _validateCategory(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Category is required';
    }
    if (value.trim().length < 2) {
      return 'Category must be at least 2 characters';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Selling price is required';
    }
    final price = double.tryParse(value);
    if (price == null) {
      return 'Enter a valid number';
    }
    if (price < 0) {
      return 'Price cannot be negative';
    }
    if (price > 10000000) {
      return 'Price is too high';
    }
    return null;
  }

  String? _validateCost(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Cost is optional
    }
    final cost = double.tryParse(value);
    if (cost == null) {
      return 'Enter a valid number';
    }
    if (cost < 0) {
      return 'Cost cannot be negative';
    }
    if (cost > 10000000) {
      return 'Cost is too high';
    }
    return null;
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Quantity is required';
    }
    final quantity = int.tryParse(value);
    if (quantity == null) {
      return 'Enter a valid number';
    }
    if (quantity < 0) {
      return 'Quantity cannot be negative';
    }
    if (quantity > 1000000) {
      return 'Quantity is too high';
    }
    return null;
  }

  String? _validateLowStock(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Reorder level is required';
    }
    final lowStock = int.tryParse(value);
    if (lowStock == null) {
      return 'Enter a valid number';
    }
    if (lowStock < 0) {
      return 'Cannot be negative';
    }
    return null;
  }

  String? _validateUnit(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Unit is required';
    }
    if (value.trim().length > 20) {
      return 'Unit must be less than 20 characters';
    }
    return null;
  }

  // ============ LOAD METHODS ============
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
      final suppliers = await widget.inventoryService.getSuppliers();
      setState(() {
        _suppliers = suppliers;
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
        _skuController.text.trim(),
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

  // ============ SAVE METHOD WITH VALIDATION ============
  Future<void> _saveItem() async {
    // Clear previous errors
    setState(() {
      _nameError = null;
      _skuValidationError = null;
      _categoryError = null;
      _priceError = null;
      _costError = null;
      _quantityError = null;
      _lowStockError = null;
      _unitError = null;
    });

    // Validate all fields
    final nameValidation = _validateName(_nameController.text);
    final skuValidation = _validateSKU(_skuController.text);
    final categoryValidation = _validateCategory(_categoryController.text);
    final priceValidation = _validatePrice(_priceController.text);
    final costValidation = _validateCost(_costController.text);
    final quantityValidation = _validateQuantity(_quantityController.text);
    final lowStockValidation = _validateLowStock(_lowStockController.text);
    final unitValidation = _validateUnit(_unitController.text);

    // Check for SKU uniqueness
    if (_skuError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_skuError!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Set validation errors
    bool hasErrors = false;
    if (nameValidation != null) {
      setState(() => _nameError = nameValidation);
      hasErrors = true;
    }
    if (skuValidation != null) {
      setState(() => _skuValidationError = skuValidation);
      hasErrors = true;
    }
    if (categoryValidation != null) {
      setState(() => _categoryError = categoryValidation);
      hasErrors = true;
    }
    if (priceValidation != null) {
      setState(() => _priceError = priceValidation);
      hasErrors = true;
    }
    if (costValidation != null) {
      setState(() => _costError = costValidation);
      hasErrors = true;
    }
    if (quantityValidation != null) {
      setState(() => _quantityError = quantityValidation);
      hasErrors = true;
    }
    if (lowStockValidation != null) {
      setState(() => _lowStockError = lowStockValidation);
      hasErrors = true;
    }
    if (unitValidation != null) {
      setState(() => _unitError = unitValidation);
      hasErrors = true;
    }

    if (hasErrors) {
      // Scroll to first error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fix all errors before saving'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Parse values
      final name = _nameController.text.trim();
      final sku = _skuController.text.trim();
      final category = _categoryController.text.trim();
      final unit = _unitController.text.trim();
      final description = _descriptionController.text.trim();
      final location = _locationController.text.trim();
      final supplierName = _supplierController.text.trim();
      
      final price = double.parse(_priceController.text);
      final cost = _costController.text.isNotEmpty ? double.parse(_costController.text) : 0.0;
      final quantity = int.parse(_quantityController.text);
      final lowStockThreshold = int.parse(_lowStockController.text);

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
        name: name,
        description: description,
        sku: sku,
        category: category,
        price: price,
        cost: cost,
        quantity: quantity,
        lowStockThreshold: lowStockThreshold,
        unit: unit,
        location: location.isNotEmpty ? location : null,
        supplierId: supplierId ?? widget.item?.supplierId,
        supplierName: supplierName.isNotEmpty ? supplierName : null,
        userMobile: widget.userMobile,
      );

      if (widget.item == null) {
        // Add new item
        final id = await widget.inventoryService.addInventoryItem(item);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Item added successfully'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        // Update existing item
        await widget.inventoryService.updateInventoryItem(item);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Item updated successfully'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      print('❌ Error saving item: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============ BUILD METHOD ============
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item == null ? 'Add New Item' : 'Edit Item',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 24.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Information Section
                        _buildSectionHeader(
                          title: 'Product Information',
                          required: true,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildInputField(
                          controller: _nameController,
                          label: 'Product Name',
                          icon: Icons.shopping_bag_outlined,
                          hintText: 'Enter product name (e.g., iPhone 14 Pro)',
                          errorText: _nameError,
                          onChanged: (value) {
                            if (_nameError != null) {
                              setState(() => _nameError = null);
                            }
                          },
                        ),
                        
                        const SizedBox(height: 24),
                        
                        _buildInputField(
                          controller: _descriptionController,
                          label: 'Description',
                          icon: Icons.description_outlined,
                          hintText: 'Enter description (optional)',
                          maxLines: 3,
                          optional: true,
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Identification Section
                        _buildSectionHeader(
                          title: 'Identification',
                          required: true,
                        ),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _skuController,
                                label: 'SKU Code',
                                icon: Icons.tag_outlined,
                                hintText: 'Enter unique SKU',
                                errorText: _skuValidationError ?? _skuError,
                                suffixIcon: _skuChecking
                                    ? Padding(
                                        padding: const EdgeInsets.only(right: 12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      )
                                    : null,
                                onChanged: (value) {
                                  if (_skuValidationError != null) {
                                    setState(() => _skuValidationError = null);
                                  }
                                  if (_skuError != null) {
                                    setState(() => _skuError = null);
                                  }
                                  _checkSku();
                                },
                              ),
                            ),
                            
                            const SizedBox(width: 20),
                            
                            Expanded(
                              child: _buildCategoryDropdown(),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Pricing Section
                        _buildSectionHeader(
                          title: 'Pricing',
                          required: true,
                        ),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _priceController,
                                label: 'Selling Price',
                                icon: Icons.currency_rupee,
                                hintText: '0.00',
                                errorText: _priceError,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                prefixText: '₹ ',
                                onChanged: (value) {
                                  if (_priceError != null) {
                                    setState(() => _priceError = null);
                                  }
                                },
                              ),
                            ),
                            
                            const SizedBox(width: 20),
                            
                            Expanded(
                              child: _buildInputField(
                                controller: _costController,
                                label: 'Cost Price',
                                icon: Icons.currency_rupee,
                                hintText: '0.00',
                                errorText: _costError,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                prefixText: '₹ ',
                                optional: true,
                                onChanged: (value) {
                                  if (_costError != null) {
                                    setState(() => _costError = null);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Stock Information Section
                        _buildSectionHeader(
                          title: 'Stock Information',
                          required: true,
                        ),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _quantityController,
                                label: 'Current Stock',
                                icon: Icons.inventory_outlined,
                                hintText: '0',
                                errorText: _quantityError,
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  if (_quantityError != null) {
                                    setState(() => _quantityError = null);
                                  }
                                },
                              ),
                            ),
                            
                            const SizedBox(width: 20),
                            
                            Expanded(
                              child: _buildInputField(
                                controller: _lowStockController,
                                label: 'Reorder Level',
                                icon: Icons.warning_outlined,
                                hintText: '10',
                                errorText: _lowStockError,
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  if (_lowStockError != null) {
                                    setState(() => _lowStockError = null);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildInputField(
                                controller: _unitController,
                                label: 'Unit',
                                icon: Icons.square_foot_outlined,
                                hintText: 'pcs, kg, ml, etc.',
                                errorText: _unitError,
                                onChanged: (value) {
                                  if (_unitError != null) {
                                    setState(() => _unitError = null);
                                  }
                                },
                              ),
                            ),
                            
                            const SizedBox(width: 20),
                            
                            Expanded(
                              child: _buildInputField(
                                controller: _locationController,
                                label: 'Location',
                                icon: Icons.location_on_outlined,
                                hintText: 'Warehouse, Shelf, etc.',
                                optional: true,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Supplier Section
                        _buildSectionHeader(
                          title: 'Supplier Information',
                          required: false,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildSupplierDropdown(),
                        
                        const SizedBox(height: 40),
                        
                        // Required Fields Note
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Fields marked with * are required',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                
                // Bottom Action Buttons
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outline,
                        width: 1.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            side: BorderSide(
                              color: colorScheme.outline,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: isDark ? 4 : 2,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.item == null ? 'Add Item' : 'Save Changes',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
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

  // ============ CUSTOM WIDGETS ============
  Widget _buildSectionHeader({
    required String title,
    required bool required,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            if (required)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  '*',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 3,
          width: 40,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
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
    String? prefixText,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool optional = false,
    ValueChanged<String>? onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!optional)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Text(
                  '*',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Icon(
                icon,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
            prefixText: prefixText,
            prefixStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.primary,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 2,
              ),
            ),
            errorText: errorText,
            errorStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            filled: true,
            fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Category',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 2),
              child: Text(
                '*',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 56, // Fixed height to prevent layout shift
          decoration: BoxDecoration(
            border: Border.all(
              color: _categoryError != null 
                ? Colors.red 
                : colorScheme.outline,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
          ),
          child: MenuAnchor(
            builder: (BuildContext context, MenuController controller, Widget? child) {
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.category_outlined,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _categoryController.text.isEmpty
                              ? 'Select Category'
                              : _categoryController.text,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _categoryController.text.isEmpty
                                ? colorScheme.onSurface.withOpacity(0.5)
                                : colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: colorScheme.onSurface.withOpacity(0.5),
                        size: 28,
                      ),
                    ],
                  ),
                ),
              );
            },
            menuChildren: [
              // "Add New Category" option first for better visibility
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      _showAddCategoryDialog();
                    },
                    icon: Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    label: Text(
                      'Add New Category',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1),
              ..._categories.map((category) {
                return MenuItemButton(
                  style: MenuItemButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    backgroundColor: isDark ? colorScheme.surface : Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _categoryController.text = category;
                      _categoryError = null;
                    });
                  },
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (_categoryError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              _categoryError!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSupplierDropdown() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supplier',
          style: TextStyle(
            fontSize: 15,
            color: colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outline,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _supplierController.text.isNotEmpty && 
                     _suppliers.contains(_supplierController.text) 
                  ? _supplierController.text 
                  : null,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Select Supplier (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                ..._suppliers.map((supplier) {
                  return DropdownMenuItem(
                    value: supplier,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        supplier,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }),
                DropdownMenuItem(
                  value: 'new',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Add New Supplier',
                            style: TextStyle(
                              fontSize: 16,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                border: InputBorder.none,
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                filled: true,
                fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
              ),
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.arrow_drop_down,
                  color: colorScheme.onSurface.withOpacity(0.5),
                  size: 28,
                ),
              ),
              isExpanded: true,
              dropdownColor: isDark ? colorScheme.surface : Colors.white,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddCategoryDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoryController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Add New Category',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                autofocus: true,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Enter category name',
                  hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark 
                      ? colorScheme.surfaceContainerHighest 
                      : Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This category will be available for all items',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                foregroundColor: colorScheme.primary,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (categoryController.text.trim().isNotEmpty) {
                  try {
                    await widget.inventoryService.addCategory(categoryController.text.trim());
                    setState(() {
                      _categories.add(categoryController.text.trim());
                      _categoryController.text = categoryController.text.trim();
                      _categoryError = null;
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"${categoryController.text.trim()}" added successfully'),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error adding category: $e'),
                          backgroundColor: colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Add',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddSupplierDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final supplierController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Text(
            'Add New Supplier',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: supplierController,
                autofocus: true,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Enter supplier name',
                  hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark 
                      ? colorScheme.surfaceContainerHighest 
                      : Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can add contact details later',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                foregroundColor: colorScheme.primary,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (supplierController.text.trim().isNotEmpty) {
                  try {
                    await widget.inventoryService.addSupplier(supplierController.text.trim());
                    setState(() {
                      _suppliers.add(supplierController.text.trim());
                      _supplierController.text = supplierController.text.trim();
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"${supplierController.text.trim()}" added successfully'),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error adding supplier: $e'),
                          backgroundColor: colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Add',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _quantityController.dispose();
    _lowStockController.dispose();
    _unitController.dispose();
    _locationController.dispose();
    _supplierController.dispose();
    super.dispose();
  }
}