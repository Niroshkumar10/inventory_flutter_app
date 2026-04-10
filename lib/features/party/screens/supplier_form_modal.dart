import 'package:flutter/material.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';
import 'location_picker.dart';

class SupplierFormModal extends StatefulWidget {
  final String userMobile;
  final Supplier? supplier;
  
  const SupplierFormModal({
    super.key, 
    required this.userMobile,
    this.supplier,
  });

  @override
  _SupplierFormModalState createState() => _SupplierFormModalState();
}

class _SupplierFormModalState extends State<SupplierFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final SupplierService _supplierService;
  
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
    // New location variables
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedLocationAddress;


  bool _isLoading = false;
  List<Supplier> _existingSuppliers = [];
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _supplierService = SupplierService(widget.userMobile);
    _loadExistingSuppliers();
    
    if (widget.supplier != null) {
      _nameController.text = widget.supplier!.name;
      _phoneController.text = widget.supplier!.phone;
      _emailController.text = widget.supplier!.email;
      _addressController.text = widget.supplier!.address;

       // Load location data if exists
      _selectedLatitude = widget.supplier!.latitude;
      _selectedLongitude = widget.supplier!.longitude;
      _selectedLocationAddress = widget.supplier!.locationAddress;

    }
  }

    // Add method to open location picker
  Future<void> _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPicker(
          initialLatitude: _selectedLatitude,
          initialLongitude: _selectedLongitude,
          initialAddress: _selectedLocationAddress,
          onLocationSelected: (lat, lng, address) {
            setState(() {
              _selectedLatitude = lat;
              _selectedLongitude = lng;
              _selectedLocationAddress = address;
            });
          },
        ),
      ),
    );
  }


  Future<void> _loadExistingSuppliers() async {
    try {
      // Get the stream
      final suppliersStream = _supplierService.getSuppliers();
      
      // Listen to the stream
      suppliersStream.listen((suppliers) {
        if (mounted) {
          setState(() {
            _existingSuppliers = suppliers;
            _isDataLoaded = true;
          });
        }
      }, onError: (error) {
        print('Error loading suppliers: $error');
        if (mounted) {
          setState(() {
            _isDataLoaded = true; // Mark as loaded even on error to enable validation
          });
        }
      });
      
    } catch (e) {
      print('Error setting up supplier stream: $e');
      if (mounted) {
        setState(() {
          _isDataLoaded = true; // Mark as loaded even on error
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // Validation method for name (check if exists)
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter supplier name';
    }
    
    final trimmedName = value.trim();
    
    // Skip validation if data hasn't loaded yet
    if (!_isDataLoaded) {
      return null;
    }
    
    // Skip validation if editing the same supplier
    if (widget.supplier != null && widget.supplier!.name == trimmedName) {
      return null;
    }
    
    // Check if name already exists (case-insensitive)
    final nameExists = _existingSuppliers.any(
      (supplier) => supplier.name.toLowerCase() == trimmedName.toLowerCase()
    );
    
    if (nameExists) {
      return 'Supplier with this name already exists';
    }
    
    return null;
  }

  // Validation method for phone (check if exists and 10 digits)
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter phone number';
    }
    
    final trimmedPhone = value.trim();
    
    // Check if it contains only digits
    final phoneRegex = RegExp(r'^[0-9]+$');
    if (!phoneRegex.hasMatch(trimmedPhone)) {
      return 'Phone number should contain only digits';
    }
    
    // Check length (exactly 10 digits)
    if (trimmedPhone.length != 10) {
      return 'Phone number must be exactly 10 digits';
    }
    
    // Skip validation if data hasn't loaded yet
    if (!_isDataLoaded) {
      return null;
    }
    
    // Skip validation if editing the same supplier
    if (widget.supplier != null && widget.supplier!.phone == trimmedPhone) {
      return null;
    }
    
    // Check if phone already exists
    final phoneExists = _existingSuppliers.any(
      (supplier) => supplier.phone == trimmedPhone
    );
    
    if (phoneExists) {
      return 'Supplier with this phone number already exists';
    }
    
    return null;
  }

  // Validation method for email
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Email is optional
    }
    
    final trimmedEmail = value.trim();
    
    // Basic email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(trimmedEmail)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }
// Update _saveSupplier method to include location data
  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      if (widget.supplier == null) {
        // Add new supplier with location
        final supplier = Supplier.create(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          userMobile: widget.userMobile,
          address: _addressController.text.trim(),
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          locationAddress: _selectedLocationAddress,
        );
        
        final newId = await _supplierService.addSupplier(supplier);
        print('✅ Supplier added with ID: $newId');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Supplier added successfully'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        // Update existing supplier with location
        final updatedSupplier = widget.supplier!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          address: _addressController.text.trim(),
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          locationAddress: _selectedLocationAddress,
        );
        
        await _supplierService.updateSupplier(updatedSupplier);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Supplier updated successfully'),
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
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
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

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.supplier == null ? 'Add Supplier' : 'Edit Supplier',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              Text(
                'User: ${widget.userMobile}',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.6), 
                  fontSize: 12,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Show loading indicator while data is being loaded
              if (!_isDataLoaded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.tertiary),
                  ),
                ),
              
              // Name Field with validation
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Supplier Name *',
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
                    borderSide: BorderSide(color: colorScheme.tertiary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.error, width: 2),
                  ),
                  prefixIcon: Icon(Icons.person, color: colorScheme.tertiary),
                  filled: true,
                  fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                  helperText: _isDataLoaded ? 'Name must be unique' : 'Loading existing suppliers...',
                  helperStyle: TextStyle(
                    color: _isDataLoaded 
                        ? colorScheme.onSurface.withOpacity(0.4) 
                        : colorScheme.tertiary,
                    fontSize: 12,
                  ),
                ),
                validator: _validateName,
              ),
              
              const SizedBox(height: 16),
              
              // Phone Field with validation
              TextFormField(
                controller: _phoneController,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
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
                    borderSide: BorderSide(color: colorScheme.tertiary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.error, width: 2),
                  ),
                  prefixIcon: Icon(Icons.phone, color: colorScheme.tertiary),
                  filled: true,
                  fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                  helperText: _isDataLoaded 
                      ? '10-digit number, must be unique'
                      : 'Loading existing suppliers...',
                  helperStyle: TextStyle(
                    color: _isDataLoaded 
                        ? colorScheme.onSurface.withOpacity(0.4) 
                        : colorScheme.tertiary,
                    fontSize: 12,
                  ),
                  counterText: '', // Hide default counter
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10, // Limit to 10 digits
                validator: _validatePhone,
              ),
              
              const SizedBox(height: 16),
              
              // Email Field with improved validation

              const SizedBox(height: 16),
              
              // Address Field
              TextFormField(
                controller: _addressController,
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
                    borderSide: BorderSide(color: colorScheme.tertiary, width: 2),
                  ),
                  prefixIcon: Icon(Icons.location_on, color: colorScheme.tertiary),
                  filled: true,
                  fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                ),
                maxLines: 3,
              ),
               OutlinedButton.icon(
                onPressed: _openLocationPicker,
                icon: Icon(
                  _selectedLatitude != null ? Icons.location_on : Icons.add_location,
                  color: _selectedLatitude != null ? colorScheme.tertiary : null,
                ),
                label: Text(
                  _selectedLatitude != null ? 'Update Location' : 'Add Map Location',
                  style: TextStyle(
                    color: _selectedLatitude != null ? colorScheme.tertiary : null,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(
                    color: _selectedLatitude != null 
                        ? colorScheme.tertiary 
                        : colorScheme.outline,
                  ),
                ),
              ),
              
              // Show selected location if available
              if (_selectedLocationAddress != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.tertiary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, 
                        color: colorScheme.tertiary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Location',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.tertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedLocationAddress!,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.clear, size: 20, 
                          color: colorScheme.onSurface.withOpacity(0.5)),
                        onPressed: () {
                          setState(() {
                            _selectedLatitude = null;
                            _selectedLongitude = null;
                            _selectedLocationAddress = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Save Button
              ElevatedButton(
                onPressed: (_isLoading || !_isDataLoaded) ? null : _saveSupplier,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.tertiary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isDark ? 4 : 2,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        !_isDataLoaded 
                            ? 'Loading...' 
                            : (widget.supplier == null 
                                ? 'Add Supplier' 
                                : 'Update Supplier'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
}