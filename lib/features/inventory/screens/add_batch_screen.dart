// lib/features/inventory/screens/add_batch_screen.dart
import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/batch_model.dart';

class AddBatchScreen extends StatefulWidget {
  final InventoryService inventoryService;
  final String inventoryId;
  final String itemName;
  
  const AddBatchScreen({
    super.key,
    required this.inventoryService,
    required this.inventoryId,
    required this.itemName,
  });
  
  @override
  State<AddBatchScreen> createState() => _AddBatchScreenState();
}

class _AddBatchScreenState extends State<AddBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _supplierInvoiceController = TextEditingController();
  final _supplierNameController = TextEditingController();
  
  DateTime? _expiryDate;
  DateTime? _purchaseDate;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _purchaseDate = DateTime.now();
  }
  
  @override
  void dispose() {
    _quantityController.dispose();
    _purchasePriceController.dispose();
    _supplierInvoiceController.dispose();
    _supplierNameController.dispose();
    super.dispose();
  }
  
  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select expiry date')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await widget.inventoryService.purchaseStock(
        inventoryId: widget.inventoryId,
        quantity: int.parse(_quantityController.text),
        purchasePrice: double.parse(_purchasePriceController.text),
        expiryDate: _expiryDate!,
        purchaseDate: _purchaseDate,
        supplierInvoiceNo: _supplierInvoiceController.text.isNotEmpty 
            ? _supplierInvoiceController.text 
            : null,
        supplierName: _supplierNameController.text.isNotEmpty 
            ? _supplierNameController.text 
            : null,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch added successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Batch - ${widget.itemName}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                        suffixText: 'units',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter quantity';
                        }
                        if (int.tryParse(value) == null || int.parse(value) <= 0) {
                          return 'Enter valid quantity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _purchasePriceController,
                      decoration: const InputDecoration(
                        labelText: 'Purchase Price',
                        border: OutlineInputBorder(),
                        prefixText: '₹',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter purchase price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Enter valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Purchase Date'),
                      subtitle: Text(_purchaseDate != null
                          ? '${_purchaseDate!.day}/${_purchaseDate!.month}/${_purchaseDate!.year}'
                          : 'Not selected'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _purchaseDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _purchaseDate = date);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Expiry Date'),
                      subtitle: Text(_expiryDate != null
                          ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                          : 'Not selected'),
                      trailing: Icon(
                        Icons.event,
                        color: _expiryDate != null && _expiryDate!.isBefore(DateTime.now())
                            ? Colors.red
                            : null,
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (date != null) {
                          setState(() => _expiryDate = date);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _supplierInvoiceController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Invoice No. (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _supplierNameController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Name (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveBatch,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('ADD BATCH'),
            ),
          ],
        ),
      ),
    );
  }
}