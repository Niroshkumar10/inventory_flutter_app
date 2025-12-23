// screens/add_edit_category_screen.dart
import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/category_model.dart';

class AddEditCategoryScreen extends StatefulWidget {
  final InventoryService inventoryService;
  final Category? category;

  const AddEditCategoryScreen({
    Key? key,
    required this.inventoryService,
    this.category,
  }) : super(key: key);

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      if (widget.category == null) {
        // Add new category
        await widget.inventoryService.addCategory(
          name,
          description: description.isNotEmpty ? description : null,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Update existing category
        await widget.inventoryService.updateCategory(
          widget.category!.id,
          name,
          description: description.isNotEmpty ? description : null,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Category' : 'Add Category'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter category name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCategory,
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : Text(isEdit ? 'Update Category' : 'Add Category'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}