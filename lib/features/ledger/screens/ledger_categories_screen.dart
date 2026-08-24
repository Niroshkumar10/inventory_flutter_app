// lib/features/ledger/screens/ledger_categories_screen.dart
import 'package:flutter/material.dart';
import '../models/ledger_category_model.dart';
import '../services/ledger_category_service.dart';
import 'package:inventory_app/core/theme/colors.dart';

/// Manage-categories screen — lets a user add/edit/delete their own
/// income & expense categories (name + icon), replacing the old fixed
/// hardcoded lists. Reflected live in the Add Entry chip grid since both
/// screens read from the same Firestore stream.
class LedgerCategoriesScreen extends StatefulWidget {
  final String userMobile;

  const LedgerCategoriesScreen({super.key, required this.userMobile});

  @override
  State<LedgerCategoriesScreen> createState() =>
      _LedgerCategoriesScreenState();
}

class _LedgerCategoriesScreenState extends State<LedgerCategoriesScreen> {
  late final LedgerCategoryService _categoryService;
  String _selectedType = 'income'; // 'income' | 'expense'

  @override
  void initState() {
    super.initState();
    _categoryService = LedgerCategoryService(widget.userMobile);
    // Backfill defaults once for both types so nobody's category list is
    // silently empty the first time this screen (or the Add Entry form)
    // runs after this feature ships.
    _categoryService.seedDefaultsIfEmpty('income');
    _categoryService.seedDefaultsIfEmpty('expense');
  }

  Color get _typeColor =>
      _selectedType == 'income' ? AppColors.secondary : AppColors.error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text('Categories',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
        backgroundColor: cs.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      body: Column(
        children: [
          // Income / Expense segmented toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _typeToggle(cs, isDark),
          ),
          Expanded(
            child: StreamBuilder<List<LedgerCategory>>(
              stream: _categoryService.getCategories(type: _selectedType),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: _typeColor));
                }

                final categories = snap.data ?? [];

                if (categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined,
                            size: 56, color: cs.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Text(
                          'No ${_selectedType == 'income' ? 'income' : 'expense'} categories yet',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.45),
                              fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _categoryCard(cs, isDark, categories[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCategoryDialog(),
        backgroundColor: _typeColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Category',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ─── Segmented toggle ───────────────────────────────────────────────────

  Widget _typeToggle(ColorScheme cs, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _toggleButton('income', 'Income', Icons.add_circle_outline, cs)),
          Expanded(child: _toggleButton('expense', 'Expense', Icons.remove_circle_outline, cs)),
        ],
      ),
    );
  }

  Widget _toggleButton(String type, String label, IconData icon, ColorScheme cs) {
    final isActive = _selectedType == type;
    final color = type == 'income' ? AppColors.secondary : AppColors.error;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : cs.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Category card ──────────────────────────────────────────────────────

  Widget _categoryCard(ColorScheme cs, bool isDark, LedgerCategory category) {
    final color = _typeColor;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openCategoryDialog(existing: category),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(category.iconData, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  category.name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Add / edit dialog ──────────────────────────────────────────────────

  void _openCategoryDialog({LedgerCategory? existing}) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _CategoryFormDialog(
        userMobile: widget.userMobile,
        type: _selectedType,
        typeColor: _typeColor,
        categoryService: _categoryService,
        existing: existing,
      ),
    );
  }
}

/// Add/edit form — name field + icon grid picker + (when editing) a delete
/// action. Styled to match the rounded/colorScheme-driven dialog language
/// used elsewhere in the app (add_edit_bill_screen.dart, category screens).
class _CategoryFormDialog extends StatefulWidget {
  final String userMobile;
  final String type;
  final Color typeColor;
  final LedgerCategoryService categoryService;
  final LedgerCategory? existing;

  const _CategoryFormDialog({
    required this.userMobile,
    required this.type,
    required this.typeColor,
    required this.categoryService,
    this.existing,
  });

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late String _selectedIcon;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.existing?.name ?? '';
    _selectedIcon = widget.existing?.icon ?? kDefaultLedgerCategoryIcon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          name: _nameController.text.trim(),
          icon: _selectedIcon,
        );
        await widget.categoryService.updateCategory(updated);
      } else {
        final category = LedgerCategory.create(
          name: _nameController.text.trim(),
          type: widget.type,
          icon: _selectedIcon,
          userMobile: widget.userMobile,
        );
        await widget.categoryService.addCategory(category);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDelete() {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (deleteCtx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete this category?',
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
        content: Text(
          'This cannot be undone. Existing entries already saved with this category keep their name.',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.65)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(deleteCtx),
            child: Text('Cancel',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(deleteCtx); // close confirm dialog
              setState(() => _isSaving = true);
              try {
                await widget.categoryService.deleteCategory(widget.existing!.id);
                if (mounted) Navigator.pop(context); // close form dialog
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: cs.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                  setState(() => _isSaving = false);
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: cs.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.typeColor;

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _isEditing ? 'Edit Category' : 'Add Category',
              style: TextStyle(
                  color: cs.onSurface, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: cs.error),
              onPressed: _isSaving ? null : _confirmDelete,
            ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.55))),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEditing,
                style: TextStyle(color: cs.onSurface, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. Business',
                  hintStyle: TextStyle(
                      fontSize: 14, color: cs.onSurface.withValues(alpha: 0.38)),
                  filled: true,
                  fillColor: isDark ? cs.surfaceContainerHigh : const Color(0xFFF7F8FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: color, width: 2)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a category name'
                    : null,
              ),
              const SizedBox(height: 18),
              Text('Icon',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.55))),
              const SizedBox(height: 10),
              SizedBox(
                height: 176,
                child: GridView.count(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: kLedgerCategoryIcons.entries.map((entry) {
                    final isSelected = _selectedIcon == entry.key;
                    return InkWell(
                      onTap: () => setState(() => _selectedIcon = entry.key),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.14)
                              : (isDark
                                  ? cs.surfaceContainerHigh
                                  : const Color(0xFFF7F8FA)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : cs.outline.withValues(alpha: 0.2),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Icon(
                          entry.value,
                          size: 20,
                          color: isSelected
                              ? color
                              : cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(_isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
