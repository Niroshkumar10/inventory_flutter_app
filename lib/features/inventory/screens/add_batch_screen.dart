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

  // Shared controllers
  final _quantityController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _supplierInvoiceController = TextEditingController();
  final _supplierNameController = TextEditingController();

  // New batch only
  DateTime? _expiryDate;
  DateTime? _purchaseDate;

  // Mode: false = new batch, true = restock existing
  bool _isRestockMode = false;

  // Restock existing
  List<Batch> _existingBatches = [];
  bool _loadingBatches = false;
  Batch? _selectedBatch;

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

  Future<void> _loadExistingBatches() async {
    setState(() {
      _loadingBatches = true;
      _selectedBatch = null;
    });
    try {
      final batches = await widget.inventoryService.batchService
          .getBatchesOnce(widget.inventoryId);
      // Only show active, non-expired batches with remaining stock
      final active = batches
          .where((b) => !b.isExpired && b.remainingQuantity > 0)
          .toList();
      if (mounted) {
        setState(() {
          _existingBatches = active;
          _loadingBatches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBatches = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading batches: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isRestockMode && _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiry date')),
      );
      return;
    }

    if (_isRestockMode && _selectedBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a batch to restock')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final qty = int.parse(_quantityController.text.trim());
      final price = double.parse(_purchasePriceController.text.trim());
      final invoice = _supplierInvoiceController.text.trim();
      final supplier = _supplierNameController.text.trim();

      if (_isRestockMode) {
        // ── Restock existing batch ────────────────────────────────
        await widget.inventoryService.restockBatch(
          inventoryId: widget.inventoryId,
          batchId: _selectedBatch!.id,
          additionalQuantity: qty,
          purchasePrice: price,
          supplierInvoiceNo: invoice,
          supplierName: supplier,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${_selectedBatch!.batchNumber} restocked with $qty units'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // ── Add new batch ─────────────────────────────────────────
        await widget.inventoryService.purchaseStock(
          inventoryId: widget.inventoryId,
          quantity: qty,
          purchasePrice: price,
          expiryDate: _expiryDate!,
          purchaseDate: _purchaseDate,
          supplierInvoiceNo: invoice.isNotEmpty ? invoice : null,
          supplierName: supplier.isNotEmpty ? supplier : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New batch added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(
          'Add Purchase — ${widget.itemName}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Mode toggle ───────────────────────────────────────────────
          Container(
            color: colorScheme.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _modeButton(
                    label: 'New Batch',
                    icon: Icons.add_box_outlined,
                    selected: !_isRestockMode,
                    onTap: () {
                      if (_isRestockMode) {
                        setState(() {
                          _isRestockMode = false;
                          _selectedBatch = null;
                        });
                      }
                    },
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modeButton(
                    label: 'Restock Existing',
                    icon: Icons.refresh_outlined,
                    selected: _isRestockMode,
                    onTap: () {
                      if (!_isRestockMode) {
                        setState(() => _isRestockMode = true);
                        _loadExistingBatches();
                      }
                    },
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),
          ),

          // ── Form ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Restock: batch picker
                    if (_isRestockMode) ...[
                      _sectionLabel('Select Batch to Restock'),
                      const SizedBox(height: 8),
                      _buildBatchPicker(colorScheme, isDark),
                      const SizedBox(height: 20),
                    ],

                    // Quantity
                    _sectionLabel('Additional Quantity'),
                    const SizedBox(height: 8),
                    _buildField(
                      controller: _quantityController,
                      hint: '0',
                      icon: Icons.production_quantity_limits,
                      suffix: 'units',
                      keyboardType: TextInputType.number,
                      colorScheme: colorScheme,
                      isDark: isDark,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Quantity is required';
                        }
                        final n = int.tryParse(v.trim());
                        if (n == null || n <= 0) {
                          return 'Enter a valid positive number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Purchase price
                    _sectionLabel('Purchase Price per Unit'),
                    const SizedBox(height: 8),
                    _buildField(
                      controller: _purchasePriceController,
                      hint: '0.00',
                      icon: Icons.currency_rupee,
                      prefix: '₹ ',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      colorScheme: colorScheme,
                      isDark: isDark,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Purchase price is required';
                        }
                        if (double.tryParse(v.trim()) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),

                    // New batch only fields
                    if (!_isRestockMode) ...[
                      const SizedBox(height: 20),
                      _sectionLabel('Purchase Date'),
                      const SizedBox(height: 8),
                      _buildDateTile(
                        label: _purchaseDate != null
                            ? '${_purchaseDate!.day}/${_purchaseDate!.month}/${_purchaseDate!.year}'
                            : 'Select date',
                        icon: Icons.calendar_today_outlined,
                        colorScheme: colorScheme,
                        isDark: isDark,
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _purchaseDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setState(() => _purchaseDate = d);
                        },
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel('Expiry Date *'),
                      const SizedBox(height: 8),
                      _buildDateTile(
                        label: _expiryDate != null
                            ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                            : 'Select expiry date',
                        icon: Icons.event_outlined,
                        colorScheme: colorScheme,
                        isDark: isDark,
                        isRequired: true,
                        isEmpty: _expiryDate == null,
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _expiryDate ??
                                DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 5)),
                          );
                          if (d != null) setState(() => _expiryDate = d);
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Supplier info (both modes)
                    _sectionLabel('Supplier Invoice No. (Optional)'),
                    const SizedBox(height: 8),
                    _buildField(
                      controller: _supplierInvoiceController,
                      hint: 'INV-001',
                      icon: Icons.receipt_outlined,
                      colorScheme: colorScheme,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 20),

                    _sectionLabel('Supplier Name (Optional)'),
                    const SizedBox(height: 8),
                    _buildField(
                      controller: _supplierNameController,
                      hint: 'Supplier name',
                      icon: Icons.store_outlined,
                      colorScheme: colorScheme,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(_isRestockMode
                                ? Icons.refresh
                                : Icons.add_box),
                        label: Text(
                          _isLoading
                              ? 'Saving...'
                              : (_isRestockMode
                                  ? 'Restock Batch'
                                  : 'Add New Batch'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode toggle button ──────────────────────────────────────────────────────
  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? colorScheme.primary : Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? colorScheme.primary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Batch picker for restock mode ───────────────────────────────────────────
  Widget _buildBatchPicker(ColorScheme colorScheme, bool isDark) {
    if (_loadingBatches) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
          color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        ),
        child: Center(
          child: CircularProgressIndicator(
              color: colorScheme.primary, strokeWidth: 2),
        ),
      );
    }

    if (_existingBatches.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.errorContainer.withValues(alpha: 0.1),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colorScheme.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No active batches available to restock. Create a new batch instead.',
                style: TextStyle(color: colorScheme.error, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: _selectedBatch != null
              ? colorScheme.primary
              : colorScheme.outline,
          width: _selectedBatch != null ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Batch>(
          value: _selectedBatch,
          isExpanded: true,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 20),
                const SizedBox(width: 12),
                Text('Select batch',
                    style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          dropdownColor:
              isDark ? colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: _existingBatches.map((batch) {
            final daysLeft = batch.expiryDate.difference(DateTime.now()).inDays;
            final expiryColor =
                batch.isNearExpiry ? Colors.orange : Colors.green;
            return DropdownMenuItem<Batch>(
              value: batch,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    batch.batchNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Remaining: ${batch.remainingQuantity} units  •  Expiry: ${batch.expiryDate.day}/${batch.expiryDate.month}/${batch.expiryDate.year} ($daysLeft days)',
                    style: TextStyle(fontSize: 11, color: expiryColor),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (batch) => setState(() => _selectedBatch = batch),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ColorScheme colorScheme,
    required bool isDark,
    String? prefix,
    String? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(),
        prefixText: prefix,
        suffixText: suffix,
        filled: true,
        fillColor:
            isDark ? colorScheme.surfaceContainerHighest : Colors.white,
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
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDateTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required bool isDark,
    bool isRequired = false,
    bool isEmpty = false,
  }) {
    final borderColor = isRequired && isEmpty ? Colors.red : colorScheme.outline;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
          border: Border.all(color: borderColor, width: isRequired && isEmpty ? 1.5 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isRequired && isEmpty
                    ? Colors.red
                    : colorScheme.primary,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: isEmpty
                      ? colorScheme.onSurface.withValues(alpha: 0.5)
                      : colorScheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
