import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../services/customer_service.dart';
import 'location_picker.dart'; // Make sure this import path is correct

class AddEditCustomerScreen extends StatefulWidget {
  final String userMobile;
  final Customer? customer;
  
  const AddEditCustomerScreen({
    super.key,
    required this.userMobile,
    this.customer,
  });

  @override
  State<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final CustomerService _customerService;
  
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  
  // New location variables
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedLocationAddress;
  
  bool _isLoading = false;
  List<Customer> _existingCustomers = [];
  bool _isDataLoaded = false;
  
  // Add these flags to track if fields have been touched
  bool _nameTouched = false;
  bool _mobileTouched = false;
  
  // Add controllers for listening to text changes
  late FocusNode _nameFocusNode;
  late FocusNode _mobileFocusNode;

  @override
  void initState() {
    super.initState();
    _customerService = CustomerService(widget.userMobile);
    _loadExistingCustomers();
    
    // Initialize focus nodes
    _nameFocusNode = FocusNode();
    _mobileFocusNode = FocusNode();
    
    // Add listeners to clear validation when typing starts
    _nameController.addListener(_onNameChanged);
    _mobileController.addListener(_onMobileChanged);
    
    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _mobileController.text = widget.customer!.mobile;
      _addressController.text = widget.customer!.address;
      
      // Load location data if exists
      _selectedLatitude = widget.customer!.latitude;
      _selectedLongitude = widget.customer!.longitude;
      _selectedLocationAddress = widget.customer!.locationAddress;
    }
  }

  void _onNameChanged() {
    // When user starts typing, mark field as touched
    if (!_nameTouched && _nameController.text.isNotEmpty) {
      setState(() {
        _nameTouched = true;
      });
    }
  }

  void _onMobileChanged() {
    // When user starts typing, mark field as touched
    if (!_mobileTouched && _mobileController.text.isNotEmpty) {
      setState(() {
        _mobileTouched = true;
      });
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

  Future<void> _loadExistingCustomers() async {
    try {
      final customersStream = _customerService.getCustomers();
      
      customersStream.listen((customers) {
        if (mounted) {
          setState(() {
            _existingCustomers = customers;
            _isDataLoaded = true;
          });
        }
      }, onError: (error) {
        print('Error loading customers: $error');
        if (mounted) {
          setState(() {
            _isDataLoaded = true;
          });
        }
      });
      
    } catch (e) {
      print('Error setting up customer stream: $e');
      if (mounted) {
        setState(() {
          _isDataLoaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _mobileController.removeListener(_onMobileChanged);
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _nameFocusNode.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  // Validation method for name (check if exists)
  String? _validateName(String? value) {
    // Only validate if field has been touched or form is being submitted
    if (!_nameTouched) {
      return null;
    }
    
    if (value == null || value.trim().isEmpty) {
      return 'Please enter customer name';
    }
    
    final trimmedName = value.trim();
    
    if (!_isDataLoaded) {
      return null;
    }
    
    if (widget.customer != null && widget.customer!.name == trimmedName) {
      return null;
    }
    
    final nameExists = _existingCustomers.any(
      (customer) => customer.name.toLowerCase() == trimmedName.toLowerCase()
    );
    
    if (nameExists) {
      return 'Customer with this name already exists';
    }
    
    return null;
  }

  // Validation method for mobile (check if exists and 10 digits)
  String? _validateMobile(String? value) {
    // Only validate if field has been touched or form is being submitted
    if (!_mobileTouched) {
      return null;
    }
    
    if (value == null || value.trim().isEmpty) {
      return 'Please enter mobile number';
    }
    
    final trimmedMobile = value.trim();
    
    final mobileRegex = RegExp(r'^[0-9]+$');
    if (!mobileRegex.hasMatch(trimmedMobile)) {
      return 'Mobile number should contain only digits';
    }
    
    if (trimmedMobile.length != 10) {
      return 'Mobile number must be exactly 10 digits';
    }
    
    if (!_isDataLoaded) {
      return null;
    }
    
    if (widget.customer != null && widget.customer!.mobile == trimmedMobile) {
      return null;
    }
    
    final mobileExists = _existingCustomers.any(
      (customer) => customer.mobile == trimmedMobile
    );
    
    if (mobileExists) {
      return 'Customer with this mobile number already exists';
    }
    
    return null;
  }

  Future<void> _saveCustomer() async {
    // Mark all fields as touched before validation
    setState(() {
      _nameTouched = true;
      _mobileTouched = true;
    });
    
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      if (widget.customer == null) {
        // Add new customer with location
        final customer = Customer.create(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          userMobile: widget.userMobile,
          address: _addressController.text.trim(),
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          locationAddress: _selectedLocationAddress,
        );
        
        await _customerService.addCustomer(customer);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Customer added successfully'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        // Update existing customer with location
        final updatedCustomer = widget.customer!.copyWith(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          address: _addressController.text.trim(),
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          locationAddress: _selectedLocationAddress,
        );
        
        await _customerService.updateCustomer(updatedCustomer);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Customer updated successfully'),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.customer == null ? 'Add Customer' : 'Edit Customer',
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
              
              if (!_isDataLoaded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ),
              
              // Name field with validation
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Customer Name *',
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.error, width: 2),
                  ),
                  prefixIcon: Icon(Icons.person, color: colorScheme.primary),
                  filled: true,
                  fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                  helperText: _isDataLoaded ? 'Name must be unique' : 'Loading existing customers...',
                  helperStyle: TextStyle(
                    color: _isDataLoaded 
                        ? colorScheme.onSurface.withOpacity(0.4) 
                        : colorScheme.primary,
                    fontSize: 12,
                  ),
                  errorMaxLines: 2,
                ),
                validator: _validateName,
                onFieldSubmitted: (_) {
                  // Mark as touched when user submits the field
                  if (!_nameTouched) {
                    setState(() {
                      _nameTouched = true;
                    });
                  }
                },
                onTap: () {
                  // Mark as touched when user taps the field
                  if (!_nameTouched) {
                    setState(() {
                      _nameTouched = true;
                    });
                  }
                },
              ),
              
              const SizedBox(height: 16),
              
              // Mobile field with validation
              TextFormField(
                controller: _mobileController,
                focusNode: _mobileFocusNode,
                style: TextStyle(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Mobile Number *',
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.error, width: 2),
                  ),
                  prefixIcon: Icon(Icons.phone, color: colorScheme.primary),
                  filled: true,
                  fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                  helperText: _isDataLoaded 
                      ? '10-digit number, must be unique'
                      : 'Loading existing customers...',
                  helperStyle: TextStyle(
                    color: _isDataLoaded 
                        ? colorScheme.onSurface.withOpacity(0.4) 
                        : colorScheme.primary,
                    fontSize: 12,
                  ),
                  counterText: '',
                  errorMaxLines: 2,
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: _validateMobile,
                onFieldSubmitted: (_) {
                  if (!_mobileTouched) {
                    setState(() {
                      _mobileTouched = true;
                    });
                  }
                },
                onTap: () {
                  if (!_mobileTouched) {
                    setState(() {
                      _mobileTouched = true;
                    });
                  }
                },
              ),
              
              const SizedBox(height: 16),
              
              // Address field
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
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
                  prefixIcon: Icon(Icons.location_on, color: colorScheme.primary),
                  filled: true,
                  fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 16),
              
              // Location Picker Button
              OutlinedButton.icon(
                onPressed: _openLocationPicker,
                icon: Icon(
                  _selectedLatitude != null ? Icons.location_on : Icons.add_location,
                  color: _selectedLatitude != null ? colorScheme.primary : null,
                ),
                label: Text(
                  _selectedLatitude != null ? 'Update Location' : 'Add Map Location',
                  style: TextStyle(
                    color: _selectedLatitude != null ? colorScheme.primary : null,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(
                    color: _selectedLatitude != null 
                        ? colorScheme.primary 
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
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, 
                        color: colorScheme.primary, size: 20),
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
                                color: colorScheme.primary,
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
              
              // Save button
              ElevatedButton(
                onPressed: (_isLoading || !_isDataLoaded) ? null : _saveCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
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
                            : (widget.customer == null 
                                ? 'Add Customer' 
                                : 'Update Customer'),
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