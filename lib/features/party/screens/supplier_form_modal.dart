import 'package:flutter/material.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';

class SupplierFormModal extends StatefulWidget {
  final String userMobile;
  final Supplier? supplier;
  
  const SupplierFormModal({
    Key? key, 
    required this.userMobile,
    this.supplier,
  }) : super(key: key);

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
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _supplierService = SupplierService(widget.userMobile);
    
    if (widget.supplier != null) {
      _nameController.text = widget.supplier!.name;
      _phoneController.text = widget.supplier!.phone;
      _emailController.text = widget.supplier!.email;
      _addressController.text = widget.supplier!.address;
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

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      if (widget.supplier == null) {
        // Add new supplier
        final supplier = Supplier.create(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          userMobile: widget.userMobile,
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
        );
        
        final newId = await _supplierService.addSupplier(supplier);
        print('✅ Supplier added with ID: $newId');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplier added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Update existing supplier
        final updatedSupplier = widget.supplier!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
        );
        
        await _supplierService.updateSupplier(updatedSupplier);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplier updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.supplier == null ? 'Add Supplier' : 'Edit Supplier',
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
              
              Text(
                'User: ${widget.userMobile}',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              
              const SizedBox(height: 20),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Supplier Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter supplier name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Phone Field
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.trim().length < 10) {
                    return 'Please enter valid phone number';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              
              const SizedBox(height: 16),
              
              // Address Field
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 24),
              
              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveSupplier,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
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
                        widget.supplier == null 
                            ? 'Add Supplier' 
                            : 'Update Supplier',
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
}