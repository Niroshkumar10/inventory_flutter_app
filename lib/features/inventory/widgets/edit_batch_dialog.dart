import 'package:flutter/material.dart';
import '../models/batch_model.dart';
import '../services/inventory_repo_service.dart';
import '../../../core/utils/focus_utils.dart';

/// The "Edit Batch" dialog (expiry date, purchase price, supplier, invoice
/// no.) — shared by every screen that lists batches, instead of the same
/// dialog being hand-copied per screen. [onUpdated] is optional since some
/// callers (e.g. a live Firestore stream) refresh themselves automatically.
Future<void> showEditBatchDialog({
  required BuildContext context,
  required Batch batch,
  required String inventoryId,
  required InventoryService inventoryService,
  VoidCallback? onUpdated,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

  DateTime selectedExpiry = batch.expiryDate;
  final priceController = TextEditingController(text: batch.purchasePrice.toStringAsFixed(2));
  final supplierController = TextEditingController(text: batch.supplierName ?? '');
  final invoiceController = TextEditingController(text: batch.supplierInvoiceNo ?? '');
  final priceFocusNode = FocusNode();
  final supplierFocusNode = FocusNode();
  final invoiceFocusNode = FocusNode();

  String formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  return showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(builder: (ctx, setDState) {
        Future<void> pickExpiryDate() async {
          final picked = await showDatePicker(
            context: ctx,
            initialDate: selectedExpiry,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            setDState(() => selectedExpiry = picked);
            // A date was just picked — move straight into Price, the next field.
            advanceFocus(ctx, priceFocusNode);
          }
        }

        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.edit, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Edit Batch',
                style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(batch.batchNumber,
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 16),

                Text('Expiry Date',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: pickExpiryDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                      color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          formatDate(selectedExpiry),
                          style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text('Purchase Price (₹)',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                TextField(
                  controller: priceController,
                  focusNode: priceFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => advanceFocus(ctx, supplierFocusNode),
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                Text('Supplier Name',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                TextField(
                  controller: supplierController,
                  focusNode: supplierFocusNode,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => advanceFocus(ctx, invoiceFocusNode),
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Optional',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                Text('Invoice No.',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                TextField(
                  controller: invoiceController,
                  focusNode: invoiceFocusNode,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Optional',
                    hintStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colorScheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await inventoryService.batchService.updateBatch(
                    inventoryId,
                    batch.id,
                    expiryDate: selectedExpiry,
                    purchasePrice: double.tryParse(priceController.text) ?? batch.purchasePrice,
                    supplierName: supplierController.text.trim().isEmpty ? null : supplierController.text.trim(),
                    supplierInvoiceNo: invoiceController.text.trim().isEmpty ? null : invoiceController.text.trim(),
                  );
                  onUpdated?.call();
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
