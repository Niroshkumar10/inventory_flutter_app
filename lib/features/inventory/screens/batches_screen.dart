// lib/features/inventory/screens/batches_screen.dart
import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/batch_model.dart';
import 'add_batch_screen.dart';

class BatchesScreen extends StatefulWidget {
  final InventoryService inventoryService;
  final String inventoryId;
  final String itemName;
  
  const BatchesScreen({
    super.key,
    required this.inventoryService,
    required this.inventoryId,
    required this.itemName,
  });
  
  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  late final Stream<List<Batch>> _batchesStream;
  
  @override
  void initState() {
    super.initState();
    _batchesStream = widget.inventoryService.batchService.getBatches(widget.inventoryId);
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Color _getExpiryColor(Batch batch) {
    if (batch.isExpired) return Colors.red;
    if (batch.isNearExpiry) return Colors.orange;
    return Colors.green;
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          'Batches — ${widget.itemName}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddBatchScreen(
                    inventoryService: widget.inventoryService,
                    inventoryId: widget.inventoryId,
                    itemName: widget.itemName,
                  ),
                ),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Batch>>(
        stream: _batchesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final batches = snapshot.data ?? [];
          
          if (batches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No batches found'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddBatchScreen(
                            inventoryService: widget.inventoryService,
                            inventoryId: widget.inventoryId,
                            itemName: widget.itemName,
                          ),
                        ),
                      ).then((_) => setState(() {}));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Batch'),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            itemBuilder: (context, index) {
              final batch = batches[index];
              final expiryColor = _getExpiryColor(batch);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                                  batch.batchNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Purchase: ${_formatDate(batch.purchaseDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: expiryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: expiryColor),
                                ),
                                child: Text(
                                  batch.isExpired
                                      ? 'EXPIRED'
                                      : (batch.isNearExpiry
                                          ? 'Expires in ${batch.daysUntilExpiry}d'
                                          : 'Valid'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: expiryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.edit_outlined,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.primary),
                                onPressed: () => _showEditBatchDialog(batch),
                                tooltip: 'Edit Batch',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRow(
                              'Remaining',
                              '${batch.remainingQuantity} units',
                              Icons.inventory,
                            ),
                          ),
                          Expanded(
                            child: _buildInfoRow(
                              'Total',
                              '${batch.quantity} units',
                              Icons.production_quantity_limits,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoRow(
                              'Purchase Price',
                              '₹${batch.purchasePrice.toStringAsFixed(2)}',
                              Icons.currency_rupee,
                            ),
                          ),
                          Expanded(
                            child: _buildInfoRow(
                              'Expiry Date',
                              _formatDate(batch.expiryDate),
                              Icons.event,
                            ),
                          ),
                        ],
                      ),
                      if (batch.supplierName != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Supplier',
                          batch.supplierName!,
                          Icons.business,
                        ),
                      ],
                      if (batch.supplierInvoiceNo != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Invoice No.',
                          batch.supplierInvoiceNo!,
                          Icons.receipt,
                        ),
                      ],
                      if (batch.isNearExpiry && !batch.isExpired)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '⚠️ This batch will expire on ${_formatDate(batch.expiryDate)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
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
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditBatchDialog(Batch batch) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    DateTime selectedExpiry = batch.expiryDate;
    final priceController = TextEditingController(
        text: batch.purchasePrice.toStringAsFixed(2));
    final supplierController =
        TextEditingController(text: batch.supplierName ?? '');
    final invoiceController =
        TextEditingController(text: batch.supplierInvoiceNo ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (ctx, setDState) {
          return AlertDialog(
            backgroundColor: colorScheme.surface,
            title: Row(
              children: [
                Icon(Icons.edit, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Edit Batch',
                  style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Batch number (read-only)
                  Text(batch.batchNumber,
                      style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: 16),

                  // Expiry date
                  Text('Expiry Date',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedExpiry,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDState(() => selectedExpiry = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                        color: isDark
                            ? colorScheme.surfaceContainerHighest
                            : Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(selectedExpiry),
                            style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Purchase price
                  Text('Purchase Price (₹)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? colorScheme.surfaceContainerHighest
                          : Colors.grey.shade50,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Supplier name
                  Text('Supplier Name',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: supplierController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Optional',
                      hintStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.4)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? colorScheme.surfaceContainerHighest
                          : Colors.grey.shade50,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Invoice number
                  Text('Invoice No.',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: invoiceController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Optional',
                      hintStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.4)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? colorScheme.surfaceContainerHighest
                          : Colors.grey.shade50,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancel',
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await widget.inventoryService.batchService.updateBatch(
                      widget.inventoryId,
                      batch.id,
                      expiryDate: selectedExpiry,
                      purchasePrice:
                          double.tryParse(priceController.text) ??
                              batch.purchasePrice,
                      supplierName: supplierController.text.trim().isEmpty
                          ? null
                          : supplierController.text.trim(),
                      supplierInvoiceNo:
                          invoiceController.text.trim().isEmpty
                              ? null
                              : invoiceController.text.trim(),
                    );
                    messenger.showSnackBar(SnackBar(
                      content: const Text('Batch updated successfully'),
                      backgroundColor: colorScheme.secondary,
                      behavior: SnackBarBehavior.floating,
                    ));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }
}