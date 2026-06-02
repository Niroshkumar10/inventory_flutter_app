import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/inventory_item_model.dart';
import 'package:inventory_app/core/utils/app_logger.dart';

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
  late TextEditingController _locationController;
  late TextEditingController _supplierController;

  String _selectedUnit = 'pcs';
  String _selectedQuality = 'Standard';
  bool _isLoading = false;
  bool _trackByBatch = false;

  static final Map<String, List<Map<String, String>>> _unitGroups = {
    'Count': [
      {'unit': 'pcs', 'label': 'Pieces'},
      {'unit': 'unit', 'label': 'Unit'},
      {'unit': 'each', 'label': 'Each'},
      {'unit': 'dozen', 'label': 'Dozen'},
      {'unit': 'gross', 'label': 'Gross'},
      {'unit': 'set', 'label': 'Set'},
      {'unit': 'pair', 'label': 'Pair'},
    ],
    'Weight': [
      {'unit': 'mg', 'label': 'Milligram'},
      {'unit': 'g', 'label': 'Gram'},
      {'unit': 'kg', 'label': 'Kilogram'},
      {'unit': 'quintal', 'label': 'Quintal'},
      {'unit': 'ton', 'label': 'Ton'},
      {'unit': 'lb', 'label': 'Pound'},
      {'unit': 'oz', 'label': 'Ounce'},
    ],
    'Volume': [
      {'unit': 'ml', 'label': 'Millilitre'},
      {'unit': 'cl', 'label': 'Centilitre'},
      {'unit': 'dl', 'label': 'Decilitre'},
      {'unit': 'L', 'label': 'Litre'},
      {'unit': 'gallon', 'label': 'Gallon'},
      {'unit': 'fl oz', 'label': 'Fluid Oz'},
    ],
    'Length': [
      {'unit': 'mm', 'label': 'Millimetre'},
      {'unit': 'cm', 'label': 'Centimetre'},
      {'unit': 'm', 'label': 'Metre'},
      {'unit': 'km', 'label': 'Kilometre'},
      {'unit': 'inch', 'label': 'Inch'},
      {'unit': 'ft', 'label': 'Foot'},
      {'unit': 'yard', 'label': 'Yard'},
    ],
    'Packaging': [
      {'unit': 'box', 'label': 'Box'},
      {'unit': 'carton', 'label': 'Carton'},
      {'unit': 'pack', 'label': 'Pack'},
      {'unit': 'bag', 'label': 'Bag'},
      {'unit': 'bundle', 'label': 'Bundle'},
      {'unit': 'roll', 'label': 'Roll'},
      {'unit': 'sheet', 'label': 'Sheet'},
      {'unit': 'strip', 'label': 'Strip'},
      {'unit': 'sachet', 'label': 'Sachet'},
      {'unit': 'bottle', 'label': 'Bottle'},
      {'unit': 'jar', 'label': 'Jar'},
      {'unit': 'can', 'label': 'Can'},
      {'unit': 'tube', 'label': 'Tube'},
      {'unit': 'pouch', 'label': 'Pouch'},
    ],
    'Area': [
      {'unit': 'sq.cm', 'label': 'Sq. Cm'},
      {'unit': 'sq.ft', 'label': 'Sq. Ft'},
      {'unit': 'sq.m', 'label': 'Sq. Metre'},
      {'unit': 'sq.inch', 'label': 'Sq. Inch'},
    ],
    'Medical': [
      {'unit': 'tablet', 'label': 'Tablet'},
      {'unit': 'capsule', 'label': 'Capsule'},
      {'unit': 'vial', 'label': 'Vial'},
      {'unit': 'ampoule', 'label': 'Ampoule'},
    ],
  };

  static const List<String> _qualityGrades = [
    'Premium',
    'Grade A',
    'Grade B',
    'Grade C',
    'Standard',
    'First Quality',
    'Second Quality',
    'Fresh',
    'Reject',
  ];


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

  DateTime? _expiryDate;
  late TextEditingController _expiryController;
  bool _trackExpiry = false;  // Add this

// Add this method to check if batch tracking can be enabled
bool get _canEnableBatchTracking {
  // Batch tracking can only be enabled for new items or items that have no existing batches
  return widget.item == null || (widget.item != null && !widget.item!.trackByBatch);
}

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    
    // Initialize controllers
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _skuController = TextEditingController(text: item?.sku ?? '');

_trackExpiry = widget.item?.trackExpiry ?? false;
    _expiryDate = widget.item?.expiryDate;
    _expiryController = TextEditingController(
      text: _expiryDate != null 
          ? "${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}"
          : '',
    ); 

    if (widget.initialCategory != null) {
      _categoryController = TextEditingController(text: widget.initialCategory!);
    } else {
      _categoryController = TextEditingController(text: item?.category ?? '');
    }
    
    _priceController = TextEditingController(text: item?.price.toString() ?? '');
    _costController = TextEditingController(text: item?.cost.toString() ?? '');
    _quantityController = TextEditingController(text: item?.quantity.toString() ?? '0');
    _lowStockController = TextEditingController(text: item?.lowStockThreshold.toString() ?? '10');
    _selectedUnit = item?.unit ?? 'pcs';
    _selectedQuality = item?.quality ?? 'Standard';
    _trackByBatch = item?.trackByBatch ?? false;
    _locationController = TextEditingController(text: item?.location ?? '');
    
    // FIX: Use supplierName instead of supplierId
    _supplierController = TextEditingController(text: item?.supplierName ?? '');

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
    // Skip validation for editing (SKU is read-only)
    if (widget.item != null) {
      return null;
    }
    
    if (value == null || value.trim().isEmpty) {
      return 'SKU is required';
    }
    if (value.trim().length < 3) {
      return 'SKU must be at least 3 characters';
    }
    if (value.trim().length > 50) {
      return 'SKU must be less than 50 characters';
    }
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
      return null;
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

  String? _validateUnit() {
    if (_selectedUnit.trim().isEmpty) {
      return 'Unit is required';
    }
    return null;
  }


void _showBatchTrackingInfo() {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Batch Tracking Explained'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Batch tracking allows you to:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('• Track multiple purchases of the same item separately'),
          const Text('• Store each batch with its own expiry date'),
          const Text('• Use FIFO (First Expiry First Out) for sales'),
          const Text('• Get expiry alerts for each batch'),
          const SizedBox(height: 16),
          const Text(
            'When enabled:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('• Each purchase will create a new batch'),
          const Text('• Sales will automatically consume oldest batches first'),
          const Text('• Stock quantity will be sum of all active batches'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recommended for items with expiry dates like food, medicine, cosmetics',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

  // ============ LOAD METHODS ============
  Future<void> _loadCategories() async {
    try {
      final categories = await widget.inventoryService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      appLogger.d('Error loading categories: $e');
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final suppliers = await widget.inventoryService.getSuppliers();
      setState(() {
        _suppliers = suppliers;
      });
    } catch (e) {
      appLogger.d('Error loading suppliers: $e');
    }
  }


Future<void> _selectExpiryDate() async {
  final pickedDate = await showDatePicker(
    context: context,
    initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
    firstDate: DateTime.now(), // Prevent selecting past dates
    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
  );

  if (pickedDate != null) {
    setState(() {
      _expiryDate = pickedDate;
      _expiryController.text =
          "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
    });
  }
}

  // ============ SAVE METHOD WITH VALIDATION ============
// ============ SAVE METHOD WITH VALIDATION & BATCH TRACKING ============
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
  final unitValidation = _validateUnit();

  // Skip expiry/batch validations for items that already have batch tracking —
  // expiry dates are managed per-batch in the Add Purchase screen.
  final isEditingBatchItem = widget.item != null && widget.item!.trackByBatch;
  final initQtyForValidation = int.tryParse(_quantityController.text.trim()) ?? 0;

  if (!isEditingBatchItem) {
    // Expiry date required when tracking expiry AND (not batch mode OR has initial stock)
    if (_trackExpiry && _expiryDate == null) {
      if (!_trackByBatch || initQtyForValidation > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please select expiry date'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // Batch tracking requires expiry tracking only when there is initial stock to create a batch
    if (_trackByBatch && !_trackExpiry && initQtyForValidation > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enable expiry tracking for the initial batch'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
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
    final sku = widget.item != null ? widget.item!.sku : _skuController.text.trim();
    final category = _categoryController.text.trim();
    final unit = _selectedUnit;
    final quality = _selectedQuality;
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
        appLogger.w('⚠️ Could not find supplier ID for name: $supplierName');
      }
    }

    if (widget.item == null) {
      // ========== ADD NEW ITEM WITH BATCH TRACKING ==========
      final item = InventoryItem(
        id: '',
        name: name,
        description: description,
        sku: sku,
        category: category,
        price: price,
        cost: cost,
        quantity: _trackByBatch ? 0 : quantity, // If batch tracking, start with 0 quantity (batches will handle stock)
        lowStockThreshold: lowStockThreshold,
        unit: unit,
        quality: quality,
        location: location.isNotEmpty ? location : null,
        supplierId: supplierId,
        supplierName: supplierName.isNotEmpty ? supplierName : null,
        userMobile: widget.userMobile,
        expiryDate: _trackExpiry ? _expiryDate : null,
        trackExpiry: _trackExpiry,
        trackByBatch: _trackByBatch,
      );
      
      final itemId = await widget.inventoryService.addInventoryItem(item);
      
      // If batch tracking is enabled and quantity > 0, create initial batch
      if (_trackByBatch && quantity > 0 && _expiryDate != null) {
        try {
          await widget.inventoryService.purchaseStock(
            inventoryId: itemId,
            quantity: quantity,
            purchasePrice: cost,
            expiryDate: _expiryDate!,
            purchaseDate: DateTime.now(),
            supplierInvoiceNo: null,
            supplierName: supplierName.isNotEmpty ? supplierName : null,
          );
          appLogger.i('✅ Initial batch created with $quantity units');
        } catch (batchError) {
          appLogger.w('⚠️ Could not create initial batch: $batchError');
          // Don't fail the whole operation, item was created successfully
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _trackByBatch 
                ? 'Item added successfully with batch tracking enabled'
                : 'Item added successfully',
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // ========== UPDATE EXISTING ITEM WITH BATCH TRACKING ==========
      
      // Check if batch tracking is being enabled for the first time
      final isEnablingBatchTracking = _trackByBatch && !widget.item!.trackByBatch;

      // For already-batch-tracked items, keep existing quantity (managed by batches).
      // For newly enabling batch tracking, zero it out so batches take over.
      // For non-batch items, use the form value.
      final alreadyBatchTracked = widget.item!.trackByBatch;
      final finalQuantity = alreadyBatchTracked
          ? widget.item!.quantity
          : (_trackByBatch ? 0 : quantity);
      
      final updatedItem = widget.item!.copyWith(
        name: name,
        description: description,
        category: category,
        price: price,
        cost: cost,
        quantity: finalQuantity,
        lowStockThreshold: lowStockThreshold,
        unit: unit,
        quality: quality,
        location: location.isNotEmpty ? location : null,
        supplierId: supplierId ?? widget.item!.supplierId,
        supplierName: supplierName.isNotEmpty ? supplierName : widget.item!.supplierName,
        expiryDate: _trackExpiry ? _expiryDate : null,
        trackExpiry: _trackExpiry,
        trackByBatch: _trackByBatch,
      );
      
      // Debug print to verify values
      appLogger.d('📝 Updating item with:');
      appLogger.d('  - Name: $name');
      appLogger.d('  - Track Expiry: $_trackExpiry');
      appLogger.d('  - Track By Batch: $_trackByBatch');
      appLogger.d('  - Expiry Date: ${_expiryDate != null ? _expiryDate!.toIso8601String() : 'null'}');
      appLogger.d('  - Is Enabling Batch: $isEnablingBatchTracking');
      
      await widget.inventoryService.updateInventoryItem(updatedItem);
      
      // If enabling batch tracking and there's existing stock, convert to batch
      if (isEnablingBatchTracking && quantity > 0 && _expiryDate != null) {
        try {
          await widget.inventoryService.purchaseStock(
            inventoryId: widget.item!.id,
            quantity: quantity,
            purchasePrice: cost,
            expiryDate: _expiryDate!,
            purchaseDate: widget.item!.createdAt,
            supplierInvoiceNo: null,
            supplierName: supplierName.isNotEmpty ? supplierName : widget.item!.supplierName,
          );
          appLogger.i('✅ Existing stock converted to batch: $quantity units');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Batch tracking enabled! $quantity units converted to batch'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (batchError) {
          appLogger.w('⚠️ Could not convert existing stock to batch: $batchError');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Item updated but stock conversion failed: $batchError'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
      
      if (mounted && !isEnablingBatchTracking) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _trackByBatch 
                ? 'Item updated successfully (batch tracking active)'
                : 'Item updated successfully',
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  } catch (e, stackTrace) {
    appLogger.e('❌ Error saving item: $e');
    appLogger.d('Stack trace: $stackTrace');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
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
                          label: 'Item Name',
                          icon: Icons.shopping_bag_outlined,
                          hintText: 'Enter item name',
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
                                hintText: widget.item == null ? 'Enter unique SKU' : 'SKU cannot be changed',
                                errorText: _skuValidationError,
                                // Make SKU read-only when editing
                                readOnly: widget.item != null,
                                // Add a hint that it's read-only
                                suffixIcon: widget.item != null 
                                    ? Padding(
                                        padding: const EdgeInsets.only(right: 12),
                                        child: Icon(
                                          Icons.lock_outline,
                                          color: colorScheme.onSurface.withOpacity(0.4),
                                          size: 18,
                                        ),
                                      )
                                    : null,
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
                                // Batch-tracked items: quantity is managed by batches, not editable here
                                readOnly: widget.item != null && widget.item!.trackByBatch,
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
                            Expanded(child: _buildUnitPicker()),
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

                        const SizedBox(height: 24),
                        _buildQualityPicker(),

                        const SizedBox(height: 40),
const SizedBox(height: 40),

// 🔥 EXPIRY / REPLACEMENT SECTION (UPDATED WITH BATCH TRACKING)
_buildSectionHeader(
  title: 'Expiry & Batch Management',
  required: false,
),
const SizedBox(height: 20),

// Track Expiry Switch
Container(
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: colorScheme.outline),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track Expiry Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enable for items that have expiration dates',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
      Switch(
        value: _trackExpiry,
        onChanged: (value) {
          setState(() {
            _trackExpiry = value;
            if (!value) {
              _expiryDate = null;
              _expiryController.clear();
              // If expiry tracking is off, batch tracking might not be needed
              if (_trackByBatch && !value) {
                _trackByBatch = false;
              }
            }
          });
        },
        activeColor: colorScheme.primary,
      ),
    ],
  ),
),

// Expiry Date Picker (only show if tracking expiry)
if (_trackExpiry) ...[
  GestureDetector(
    onTap: _selectExpiryDate,
    child: AbsorbPointer(
      child: _buildInputField(
        controller: _expiryController,
        label: 'Expiry Date',
        icon: Icons.calendar_today,
        hintText: 'Select expiry date',
        optional: false,
        errorText: _trackExpiry && _expiryDate == null ? 'Expiry date is required' : null,
      ),
    ),
  ),
  const SizedBox(height: 8),
  if (_expiryDate != null)
    _buildExpiryWarningCard(_expiryDate!),
],

const SizedBox(height: 16),

// 🔥 NEW: BATCH TRACKING SECTION
Container(
  margin: const EdgeInsets.only(top: 8),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: _trackByBatch ? colorScheme.primary : colorScheme.outline,
      width: _trackByBatch ? 2 : 1.5,
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Batch Tracking',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _trackByBatch ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track multiple batches with different expiry dates (FIFO)',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _trackByBatch,
            onChanged: _canEnableBatchTracking
                ? (value) {
                    setState(() {
                      _trackByBatch = value;
                      // If enabling batch tracking, automatically enable expiry tracking
                      if (_trackByBatch && !_trackExpiry) {
                        _trackExpiry = true;
                      }
                    });
                  }
                : null, // Disable if can't enable
            activeColor: colorScheme.primary,
          ),
        ],
      ),
      
      if (_trackByBatch) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Batch Tracking Features:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '• Each purchase will be stored as a separate batch',
                style: TextStyle(fontSize: 12),
              ),
              const Text(
                '• Sales will use FIFO (First Expiry First Out)',
                style: TextStyle(fontSize: 12),
              ),
              const Text(
                '• View and manage batches from item details screen',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showBatchTrackingInfo,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.help_outline, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Learn more about batch tracking',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        if (widget.item != null && widget.item!.quantity > 0 && !widget.item!.trackByBatch) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, size: 20, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Current stock (${widget.item!.quantity} ${widget.item!.unit}) will be converted to a batch when you save',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
      
      if (!_canEnableBatchTracking && widget.item != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Batch tracking cannot be disabled once enabled (has existing batches)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  ),
),
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

Widget _buildExpiryWarningCard(DateTime expiryDate) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final now = DateTime.now();
  final daysUntilExpiry = expiryDate.difference(now).inDays;
  
  Color warningColor;
  IconData warningIcon;
  String warningMessage;
  
  if (daysUntilExpiry < 0) {
    warningColor = Colors.red;
    warningIcon = Icons.error_outline;
    warningMessage = '⚠️ This item has already expired!';
  } else if (daysUntilExpiry <= 7) {
    warningColor = Colors.red;
    warningIcon = Icons.warning_amber_rounded;
    warningMessage = '⚠️ Expires in $daysUntilExpiry days! Urgent action needed.';
  } else if (daysUntilExpiry <= 30) {
    warningColor = Colors.orange;
    warningIcon = Icons.warning;
    warningMessage = '⚠️ Expires in $daysUntilExpiry days. Consider taking action.';
  } else {
    warningColor = Colors.green;
    warningIcon = Icons.check_circle_outline;
    warningMessage = '✓ Valid for $daysUntilExpiry more days';
  }
  
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: warningColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: warningColor.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(warningIcon, color: warningColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            warningMessage,
            style: TextStyle(
              fontSize: 13,
              color: warningColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

  // ============ UNIT PICKER ============
  Widget _buildUnitPicker() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Unit',
                style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600)),
            const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Text('*',
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.red,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showUnitPicker,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              border: Border.all(
                color: _unitError != null ? Colors.red : colorScheme.outline,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.straighten_outlined,
                    color: colorScheme.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedUnit.isEmpty ? 'Select unit' : _selectedUnit,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _selectedUnit.isEmpty
                          ? colorScheme.onSurface.withValues(alpha: 0.5)
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down,
                    color: colorScheme.onSurface.withValues(alpha: 0.5), size: 28),
              ],
            ),
          ),
        ),
        if (_unitError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(_unitError!,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.red,
                    fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }

  void _showUnitPicker() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) {
          final filteredGroups = <String, List<Map<String, String>>>{};
          _unitGroups.forEach((category, units) {
            final filtered = units
                .where((u) =>
                    searchQuery.isEmpty ||
                    u['unit']!.toLowerCase().contains(searchQuery) ||
                    u['label']!.toLowerCase().contains(searchQuery))
                .toList();
            if (filtered.isNotEmpty) filteredGroups[category] = filtered;
          });

          return Container(
            height: MediaQuery.of(sheetContext).size.height * 0.85,
            decoration: BoxDecoration(
              color: isDark ? colorScheme.surface : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('Select Unit',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close,
                            color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: TextField(
                    onChanged: (v) =>
                        setSheetState(() => searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search units...',
                      prefixIcon: Icon(Icons.search,
                          color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark
                          ? colorScheme.surfaceContainerHighest
                          : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: filteredGroups.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 16,
                                decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(2)),
                              ),
                              const SizedBox(width: 8),
                              Text(entry.key,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.6))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: entry.value.map((u) {
                              final isSelected = u['unit'] == _selectedUnit;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedUnit = u['unit']!;
                                    _unitError = null;
                                  });
                                  Navigator.pop(sheetContext);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : (isDark
                                            ? colorScheme
                                                .surfaceContainerHighest
                                            : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.outline
                                              .withValues(alpha: 0.4),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        u['unit']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        u['label']!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isSelected
                                              ? Colors.white.withValues(alpha: 0.8)
                                              : colorScheme.onSurface
                                                  .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============ QUALITY PICKER ============
  Widget _buildQualityPicker() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quality Grade',
            style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _qualityGrades.map((grade) {
            final isSelected = _selectedQuality == grade;
            return GestureDetector(
              onTap: () => setState(() => _selectedQuality = grade),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.4),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  grade,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : colorScheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
    bool readOnly = false,
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
          readOnly: readOnly,
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
                color: readOnly ? colorScheme.onSurface.withOpacity(0.4) : colorScheme.primary,
                size: 22,
              ),
            ),
            prefixText: prefixText,
            prefixStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: readOnly ? colorScheme.onSurface.withOpacity(0.4) : colorScheme.onSurface,
            ),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: readOnly ? colorScheme.onSurface.withOpacity(0.2) : colorScheme.outline,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: readOnly ? colorScheme.onSurface.withOpacity(0.2) : colorScheme.primary,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: readOnly ? colorScheme.onSurface.withOpacity(0.2) : colorScheme.outline,
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
            fillColor: readOnly 
                ? (isDark ? colorScheme.surfaceContainerHighest.withOpacity(0.5) : Colors.grey.shade100)
                : (isDark ? colorScheme.surfaceContainerHighest : Colors.white),
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: readOnly ? null : onChanged,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: readOnly ? colorScheme.onSurface.withOpacity(0.6) : colorScheme.onSurface,
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
          height: 56,
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
         // In _buildCategoryDropdown method, replace the menuChildren section:

// In _buildCategoryDropdown method, update the menuChildren:

menuChildren: [
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    child: SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () {
          // Just close the menu and show dialog
          Navigator.of(context).pop(); // Close menu
          _showAddCategoryDialog(); // Show dialog
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
    barrierDismissible: false, // Prevent closing while loading
    builder: (BuildContext dialogContext) {
      bool isAdding = false;
      String? validationError;
      
      return StatefulBuilder(
        builder: (context, setDialogState) {
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
                  enabled: !isAdding, // Disable while adding
                  style: TextStyle(color: colorScheme.onSurface),
                  onChanged: (value) {
                    if (validationError != null) {
                      setDialogState(() {
                        validationError = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter category name',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                    errorText: validationError,
                    errorStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
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
                onPressed: isAdding ? null : () {
                  Navigator.of(dialogContext).pop();
                },
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
                onPressed: isAdding ? null : () async {
                  final categoryName = categoryController.text.trim();
                  
                  if (categoryName.isEmpty) {
                    setDialogState(() {
                      validationError = 'Category name is required';
                    });
                    return;
                  }
                  
                  // Check if category already exists
                  final existingCategory = _categories.any(
                    (cat) => cat.toLowerCase() == categoryName.toLowerCase()
                  );
                  
                  if (existingCategory) {
                    setDialogState(() {
                      validationError = 'Category "$categoryName" already exists';
                    });
                    return;
                  }
                  
                  // Set loading state
                  setDialogState(() {
                    isAdding = true;
                    validationError = null;
                  });
                  
                  try {
                    // Add to database
                    await widget.inventoryService.addCategory(categoryName);
                    
                    // Reload categories
                    final updatedCategories = await widget.inventoryService.getCategories();
                    
                    // Update parent state
                    if (mounted) {
                      setState(() {
                        _categories = updatedCategories;
                        _categoryController.text = categoryName;
                        _categoryError = null;
                      });
                    }
                    
                    // Close dialog
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                    
                    // Show success message
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Category added successfully',
                            style: TextStyle(fontSize: 14),
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    // Reset loading state on error
                    setDialogState(() {
                      isAdding = false;
                      if (e.toString().contains('already exists')) {
                        validationError = 'Category "$categoryName" already exists';
                      } else {
                        validationError = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
                      }
                    });
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
                child: isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Add',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          );
        },
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
    _locationController.dispose();
    _supplierController.dispose();
    super.dispose();
  }
}
