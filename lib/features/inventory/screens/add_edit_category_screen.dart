// screens/add_edit_category_screen.dart
import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/category_model.dart';
import '../../../core/utils/focus_utils.dart';
import '../../../core/widgets/required_field_label.dart';

class AddEditCategoryScreen extends StatefulWidget {
  final InventoryService inventoryService;
  final Category? category;

  const AddEditCategoryScreen({
    super.key,
    required this.inventoryService,
    this.category,
  });

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _descriptionFocusNode = FocusNode();
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
    _descriptionFocusNode.dispose();
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
        oldCategoryName: widget.category!.name,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.category != null;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isEdit ? 'Edit Category' : 'Add Category',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => advanceFocus(context, _descriptionFocusNode),
                decoration: InputDecoration(
                  label: requiredFieldLabel('Category Name *'),
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
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
                focusNode: _descriptionFocusNode,
                // Multiline field — keep the default "newline" keyboard
                // action so users can still write multi-line descriptions.
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEdit ? 'Update Category' : 'Add Category',
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
      ),
    );
  }
}