import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../services/customer_service.dart';

class AddEditCustomerScreen extends StatefulWidget {
  final String userMobile;
  final Customer? customer;
  
  const AddEditCustomerScreen({
    Key? key,
    required this.userMobile,
    this.customer,
  }) : super(key: key);

  @override
  State<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final CustomerService _customerService;
  
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _customerService = CustomerService(widget.userMobile);
    
    if (widget.customer != null) {
      _nameController.text = widget.customer!.name;
      _mobileController.text = widget.customer!.mobile;
      _addressController.text = widget.customer!.address;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      if (widget.customer == null) {
        // Add new customer
        final customer = Customer(
          id: '',
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          address: _addressController.text.trim(),
          userMobile: widget.userMobile,
          createdAt: DateTime.now(),
        );
        
        await _customerService.addCustomer(customer);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer added successfully')),
        );
      } else {
        // Update existing customer
        final updatedCustomer = widget.customer!.copyWith(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          address: _addressController.text.trim(),
        );
        
        await _customerService.updateCustomer(updatedCustomer);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer updated successfully')),
        );
      }
      
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
                    widget.customer == null ? 'Add Customer' : 'Edit Customer',
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
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter customer name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter mobile number';
                  }
                  if (value.trim().length < 10) {
                    return 'Please enter valid mobile number';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
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
              
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCustomer,
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
                        widget.customer == null 
                            ? 'Add Customer' 
                            : 'Update Customer',
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