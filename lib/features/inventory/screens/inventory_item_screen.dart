// ./lib/features/inventory/screens/inventory_item_screen.dart

import 'package:flutter/material.dart';
import '../models/inventory_item_model.dart';
import '../models/batch_model.dart';
import '../services/inventory_repo_service.dart';
import './add_edit_item_screen.dart';
import './add_batch_screen.dart';
import './batches_screen.dart';

class InventoryItemScreen extends StatefulWidget {
  final InventoryItem item;
  final InventoryService inventoryService;
  final String userMobile;

  const InventoryItemScreen({
    super.key,
    required this.item,
    required this.inventoryService,
    required this.userMobile,
  });

  @override
  State<InventoryItemScreen> createState() => _InventoryItemScreenState();
}

class _InventoryItemScreenState extends State<InventoryItemScreen> {
  late InventoryItem _item;
  Map<String, dynamic>? _batchSummary;
  bool _isLoadingBatchSummary = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadBatchSummary();
  }

  Future<void> _loadBatchSummary() async {
    if (!_item.trackByBatch) return;
    
    setState(() => _isLoadingBatchSummary = true);
    try {
      final summary = await widget.inventoryService.batchService.getStockSummary(_item.id);
      setState(() {
        _batchSummary = summary;
        _isLoadingBatchSummary = false;
      });
    } catch (e) {
      print('Error loading batch summary: $e');
      setState(() => _isLoadingBatchSummary = false);
    }
  }

  // Helper method to get the current effective quantity
  int get _currentQuantity {
    if (_item.trackByBatch && _batchSummary != null) {
      return _batchSummary!['totalRemaining'] ?? 0;
    }
    return _item.quantity;
  }

  // Helper method to get quantity display text
  String get _quantityDisplay {
    final qty = _currentQuantity;
    return '$qty ${_item.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory),
            onPressed: () => _handleBatchManagement(context),
            tooltip: _item.trackByBatch ? 'Manage Batches' : 'Enable Batch Tracking',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditItemScreen(
                    inventoryService: widget.inventoryService,
                    item: _item,
                    userMobile: widget.userMobile,
                  ),
                ),
              ).then((value) {
                if (value == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item updated successfully')),
                  );
                  _refreshItem();
                }
              });
            },
            tooltip: 'Edit Item',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteDialog(context, _item),
            tooltip: 'Delete Item',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            
            if (_item.trackByBatch) ...[
              _buildBatchSummarySection(),
              const SizedBox(height: 24),
            ],
            _buildBatchDetailsSection(),  // ← ADD THIS LINE
            const SizedBox(height: 24),

            _buildInfoSection(),
            const SizedBox(height: 24),
            _buildStockSection(),
            const SizedBox(height: 24),
            _buildFinancialSection(),
            const SizedBox(height: 24),
            _buildAdditionalInfo(),
            const SizedBox(height: 24),
            _buildQuickActionButtons(),
          ],
        ),
      ),
    );
  }

  void _handleBatchManagement(BuildContext context) {
    if (!_item.trackByBatch) {
      _showEnableBatchTrackingDialog();
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BatchesScreen(
            inventoryService: widget.inventoryService,
            inventoryId: _item.id,
            itemName: _item.name,
          ),
        ),
      ).then((_) => _loadBatchSummary());
    }
  }

  void _showEnableBatchTrackingDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Batch Tracking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Batch tracking allows you to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Track multiple batches with different expiry dates'),
            const Text('• Use FIFO (First Expiry First Out) for stock usage'),
            const Text('• Get expiry alerts for each batch'),
            const Text('• Track purchase history per batch'),
            const SizedBox(height: 16),
            Text(
              'Current stock (${_item.quantity} ${_item.unit}) will be converted to a batch.',
              style: TextStyle(color: colorScheme.primary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _enableBatchTracking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Future<void> _enableBatchTracking() async {
    if (!mounted) return;
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enabling batch tracking...')),
      );

      if (_item.quantity > 0 && _item.expiryDate != null) {
        await widget.inventoryService.purchaseStock(
          inventoryId: _item.id,
          quantity: _item.quantity,
          purchasePrice: _item.cost,
          expiryDate: _item.expiryDate!,
          purchaseDate: _item.createdAt,
        );
      }

      final updatedItem = _item.copyWith(
        trackByBatch: true,
        quantity: 0,
      );
      
      await widget.inventoryService.updateInventoryItem(updatedItem);
      
      if (mounted) {
        setState(() {
          _item = updatedItem;
        });
        await _loadBatchSummary();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Batch tracking enabled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshItem() async {
    try {
      final refreshedItem = await widget.inventoryService.getInventoryItem(_item.id);
      if (mounted) {
        setState(() {
          _item = refreshedItem;
        });
        await _loadBatchSummary();
      }
    } catch (e) {
      print('Error refreshing item: $e');
    }
  }

  Widget _buildBatchSummarySection() {
    if (_isLoadingBatchSummary) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_batchSummary == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      color: colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Batch Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildBatchStatCard(
                    'Total Stock',
                    '${_batchSummary!['totalRemaining']} ${_item.unit}',
                    Icons.production_quantity_limits,
                    colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBatchStatCard(
                    'Active Batches',
                    '${_batchSummary!['totalBatches']}',
                    Icons.grid_view,
                    colorScheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildBatchStatCard(
                    'Near Expiry',
                    '${_batchSummary!['nearExpiryBatches']}',
                    Icons.warning_amber,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBatchStatCard(
                    'Expired',
                    '${_batchSummary!['expiredBatches']}',
                    Icons.event_busy,
                    Colors.red,
                  ),
                ),
              ],
            ),
            if (_batchSummary!['earliestExpiry'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Earliest expiry: ${_formatDate(_batchSummary!['earliestExpiry'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBatchStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Widget _buildQuickActionButtons() {
  //   final theme = Theme.of(context);
  //   final colorScheme = theme.colorScheme;
    
  //   return Row(
  //     children: [
  //       Expanded(
  //         child: ElevatedButton.icon(
  //           onPressed: _item.trackByBatch
  //               ? () => _handlePurchase()
  //               : () => _showStockAdjustmentDialog(),
  //           icon: const Icon(Icons.shopping_cart),
  //           label: Text(_item.trackByBatch ? 'Add Batch' : 'Purchase Stock'),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: colorScheme.primary,
  //             foregroundColor: Colors.white,
  //             padding: const EdgeInsets.symmetric(vertical: 12),
  //           ),
  //         ),
  //       ),
  //       const SizedBox(width: 12),
  //     ],
  //   );
  // }
  Widget _buildQuickActionButtons() {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  
  return Row(
    children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: _item.trackByBatch
              ? () => _handlePurchase()
              : () => _showStockAdjustmentDialog(),
          icon: const Icon(Icons.shopping_cart),
          label: Text(_item.trackByBatch ? 'Add Batch' : 'Purchase Stock'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),      
      // ADD THIS NEW BUTTON
      const SizedBox(width: 12),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _showSalesHistory(),
          icon: const Icon(Icons.history),
          label: const Text('Sales History'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    ],
  );
}


// Add this method to _InventoryItemScreenState

Widget _buildBatchDetailsSection() {
  if (!_item.trackByBatch) return const SizedBox.shrink();
  
  return FutureBuilder<List<Map<String, dynamic>>>(
    future: widget.inventoryService.batchService.getBatchesWithDetails(_item.id),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      
      if (snapshot.hasError) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text('Error loading batches: ${snapshot.error}'),
            ),
          ),
        );
      }
      
      final batches = snapshot.data ?? [];
      
      if (batches.isEmpty) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text('No batches found'),
            ),
          ),
        );
      }
      
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Batch Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${batches.length} Batches',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Batch List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: batches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final batchData = batches[index];
                  final batch = batchData['batch'] as Batch;
                  final totalSold = batchData['totalSold'] ?? 0;
                  final remainingQty = batchData['remainingQuantity'] ?? 0;
                  final totalQty = batchData['totalQuantity'] ?? 0;
                  
                  return _buildBatchDetailCard(
                    batch: batch,
                    totalSold: totalSold,
                    remainingQty: remainingQty,
                    totalQty: totalQty,
                    batchNumber: index + 1,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildBatchDetailCard({
  required Batch batch,
  required int totalSold,
  required int remainingQty,
  required int totalQty,
  required int batchNumber,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  
  // Determine batch status
  bool isExpired = batch.isExpired;
  bool isNearExpiry = batch.isNearExpiry;
  bool isLowStock = remainingQty <= 5;
  
  Color statusColor;
  String statusText;
  IconData statusIcon;
  
  if (isExpired) {
    statusColor = Colors.red;
    statusText = 'EXPIRED';
    statusIcon = Icons.cancel;
  } else if (isNearExpiry) {
    statusColor = Colors.orange;
    statusText = 'NEAR EXPIRY';
    statusIcon = Icons.warning;
  } else if (remainingQty == 0) {
    statusColor = Colors.grey;
    statusText = 'SOLD OUT';
    statusIcon = Icons.check_circle;
  } else if (isLowStock) {
    statusColor = Colors.orange;
    statusText = 'LOW STOCK';
    statusIcon = Icons.inventory;
  } else {
    statusColor = Colors.green;
    statusText = 'ACTIVE';
    statusIcon = Icons.check_circle;
  }
  
  return Container(
    decoration: BoxDecoration(
      border: Border.all(color: statusColor.withOpacity(0.3)),
      borderRadius: BorderRadius.circular(12),
      color: statusColor.withOpacity(0.05),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Batch Number and Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Batch #$batchNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Stock Information Row
          Row(
            children: [
              Expanded(
                child: _buildBatchInfoTile(
                  label: 'Total',
                  value: '$totalQty ${_item.unit}',
                  icon: Icons.production_quantity_limits,
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildBatchInfoTile(
                  label: 'Remaining',
                  value: '$remainingQty ${_item.unit}',
                  icon: Icons.inventory,
                  color: remainingQty > 0 ? Colors.green : Colors.red,
                ),
              ),
              Expanded(
                child: _buildBatchInfoTile(
                  label: 'Sold',
                  value: '$totalSold ${_item.unit}',
                  icon: Icons.sell,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Expiry Information
          Row(
            children: [
              Icon(Icons.event, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Expires: ${_formatDate(batch.expiryDate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isExpired ? Colors.red : (isNearExpiry ? Colors.orange : Colors.grey),
                  fontWeight: isExpired || isNearExpiry ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const Spacer(),
              if (!isExpired && !isNearExpiry)
                Text(
                  '${batch.daysUntilExpiry} days left',
                  style: const TextStyle(fontSize: 11, color: Colors.green),
                ),
              if (isNearExpiry && !isExpired)
                Text(
                  '${batch.daysUntilExpiry} days left',
                  style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          
          // Purchase Info
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.shopping_cart, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Purchased: ${_formatDate(batch.purchaseDate)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const Spacer(),
              Text(
                '₹${batch.purchasePrice.toStringAsFixed(2)}/unit',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          
          // Supplier Info (if available)
          if (batch.supplierName != null && batch.supplierName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.local_shipping, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Supplier: ${batch.supplierName}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (batch.supplierInvoiceNo != null)
                    Text(
                      ' | Invoice: ${batch.supplierInvoiceNo}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),
          
          // Progress bar for stock usage
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: remainingQty / totalQty,
              backgroundColor: Colors.grey.shade200,
              color: remainingQty == 0 
                  ? Colors.red 
                  : (isNearExpiry ? Colors.orange : Colors.green),
              minHeight: 6,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${((remainingQty / totalQty) * 100).toStringAsFixed(0)}% remaining',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              Text(
                '${((totalSold / totalQty) * 100).toStringAsFixed(0)}% sold',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildBatchInfoTile({
  required String label,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Column(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    ],
  );
}

  Future<void> _handlePurchase() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBatchScreen(
          inventoryService: widget.inventoryService,
          inventoryId: _item.id,
          itemName: _item.name,
        ),
      ),
    );
    
    if (result == true) {
      await _refreshItem();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch added successfully')),
        );
      }
    }
  }

  void _showStockAdjustmentDialog() {
    final TextEditingController quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Stock'),
        content: TextField(
          controller: quantityController,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text);
              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid quantity')),
                );
                return;
              }
              Navigator.pop(context);
              await _adjustStock(quantity, 'PURCHASE');
            },
            child: const Text('Add Stock'),
          ),
        ],
      ),
    );
  }

  void _showSellDialog() {
    final TextEditingController quantityController = TextEditingController();
    
    final maxQuantity = _currentQuantity;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sell Stock'),
        content: TextField(
          controller: quantityController,
          decoration: InputDecoration(
            labelText: 'Quantity',
            border: const OutlineInputBorder(),
            helperText: 'Available: $maxQuantity ${_item.unit}',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text);
              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid quantity')),
                );
                return;
              }
              if (quantity > maxQuantity) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Insufficient stock')),
                );
                return;
              }
              Navigator.pop(context);
              await _sellStock(quantity);
            },
            child: const Text('Sell'),
          ),
        ],
      ),
    );
  }

  Future<void> _adjustStock(int quantity, String reason) async {
    try {
      await widget.inventoryService.adjustStock(_item.id, quantity, reason);
      await _refreshItem();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $quantity ${_item.unit} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sellStock(int quantity) async {
    try {
      if (_item.trackByBatch) {
        final saleId = DateTime.now().millisecondsSinceEpoch.toString();
        await widget.inventoryService.sellStock(
          inventoryId: _item.id,
          quantity: quantity,
          saleId: saleId,
          soldBy: widget.userMobile,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sold $quantity ${_item.unit} using FIFO'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final newQuantity = _item.quantity - quantity;
        await widget.inventoryService.updateInventoryItem(
          _item.copyWith(quantity: newQuantity)
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sold $quantity ${_item.unit} successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      await _refreshItem();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLowStock = _currentQuantity <= _item.lowStockThreshold;
    
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: _item.isExpired
              ? Colors.red.shade100
              : isLowStock
                  ? Colors.orange.shade100
                  : Colors.blue.shade100,
          child: Icon(
            isLowStock ? Icons.warning : Icons.inventory_2,
            size: 40,
            color: isLowStock ? Colors.orange : Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _item.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_item.trackByBatch)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.primary),
                      ),
                      child: Text(
                        'BATCH',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _item.sku,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    label: Text(_item.category),
                    backgroundColor: Colors.blue.shade50,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLowStock ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _quantityDisplay,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isLowStock ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Item Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Description', _item.description.isNotEmpty ? _item.description : 'No description'),
            const Divider(),
            _buildInfoRow('Unit', _item.unit),
            const Divider(),
            _buildInfoRow('Location', _item.location ?? 'Not specified'),
            const Divider(),
            _buildInfoRow('Supplier', _item.supplierName ?? 'Not specified'),
            const Divider(),
            _buildInfoRow('Created', _formatDateTime(_item.createdAt)),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 120,
                    child: Text(
                      'Expiry Date',
                      style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.expiryDate != null
                              ? _formatDateTime(_item.expiryDate!)
                              : 'Not set',
                          style: TextStyle(
                            fontSize: 16,
                            color: _item.isExpired 
                                ? Colors.red 
                                : (_item.isNearExpiry ? Colors.orange : null),
                            fontWeight: _item.isExpired || _item.isNearExpiry 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                        if (_item.trackExpiry && _item.expiryDate != null && !_item.trackByBatch) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _item.expiryStatusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _item.isExpired
                                  ? '❌ EXPIRED'
                                  : (_item.isNearExpiry
                                      ? '⚠️ Expires in ${_item.daysUntilExpiry} days'
                                      : '✓ Valid for ${_item.daysUntilExpiry} days'),
                              style: TextStyle(
                                fontSize: 12,
                                color: _item.expiryStatusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (_item.trackByBatch)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠️ Multiple expiry dates exist in batches. Check Batch Summary above.',
                              style: const TextStyle(fontSize: 11, color: Colors.orange),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final displayQuantity = _currentQuantity;
    final isLowStock = displayQuantity <= _item.lowStockThreshold;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Stock Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_item.trackByBatch)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'FIFO Enabled',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Current Stock',
                    _quantityDisplay,
                    isLowStock ? Colors.orange : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Low Stock Alert',
                    _item.lowStockThreshold.toString(),
                    Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (displayQuantity / (_item.lowStockThreshold * 3)).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              color: isLowStock ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              isLowStock ? '⚠️ Low stock alert!' : 'Stock level is good',
              style: TextStyle(
                color: isLowStock ? Colors.orange : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSection() {
    final totalValue = _currentQuantity * _item.price;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Cost Price', '₹${_item.cost.toStringAsFixed(2)}', Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('Selling Price', '₹${_item.price.toStringAsFixed(2)}', Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Profit Margin', '${_item.profitMargin.toStringAsFixed(1)}%', 
                    _item.profitMargin >= 0 ? Colors.green : Colors.red),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('Total Value', '₹${totalValue.toStringAsFixed(2)}', Colors.purple),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Additional Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Last Updated', _formatDateTime(_item.updatedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    return '${localDateTime.year}-${_twoDigits(localDateTime.month)}-${_twoDigits(localDateTime.day)} '
        '${_twoDigits(localDateTime.hour)}:${_twoDigits(localDateTime.minute)}:${_twoDigits(localDateTime.second)}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  void _showDeleteDialog(BuildContext context, InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteItem(context, item);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

// Add this method to _InventoryItemScreenState class

Future<void> _showSalesHistory() async {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outline),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sales History - ${_item.name}',
                      style: TextStyle(
                        fontSize: 18,
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
              ),
              // Content
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: widget.inventoryService.batchService.getSalesSummary(_item.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    
                    final summary = snapshot.data ?? {};
                    final totalSold = summary['totalSold'] ?? 0;
                    final totalSalesCount = summary['totalSalesCount'] ?? 0;
                    final recentSales = summary['recentSales'] as List<StockConsumption>? ?? [];
                    
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Summary Cards
                        Row(
                          children: [
                            Expanded(
                              child: Card(
                                color: colorScheme.primary.withOpacity(0.1),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Text(
                                        '$totalSold',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      Text(
                                        'Total Sold',
                                        style: TextStyle(color: colorScheme.primary),
                                      ),
                                      Text(
                                        '${_item.unit}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Card(
                                color: colorScheme.secondary.withOpacity(0.1),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Text(
                                        '$totalSalesCount',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                      Text(
                                        'Total Transactions',
                                        style: TextStyle(color: colorScheme.secondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Recent Sales List
                        Text(
                          'Recent Sales',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        if (recentSales.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'No sales recorded yet',
                                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: recentSales.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final sale = recentSales[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                                  child: Icon(Icons.sell, color: colorScheme.primary, size: 20),
                                ),
                                title: Text(
                                  'Sold: ${sale.quantityConsumed} ${_item.unit}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${_formatDate(sale.consumedAt)} • ${sale.reason}',
                                ),
                                trailing: Text(
                                  '₹${(sale.quantityConsumed * _item.price).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              );
                            },
                          ),
                        
                        const SizedBox(height: 16),
                        
                        // View All Button
                        if (recentSales.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showAllSalesHistory();
                            },
                            child: const Text('View All Sales History'),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _showAllSalesHistory() async {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  
  final consumptions = await widget.inventoryService.batchService.getConsumptionHistory(_item.id);
  final sales = consumptions.where((c) => c.transactionType == 'SALE').toList();
  
  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Sales History',
                  style: TextStyle(
                    fontSize: 18,
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
            const Divider(),
            Expanded(
              child: sales.isEmpty
                  ? Center(
                      child: Text(
                        'No sales recorded',
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: sales.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final sale = sales[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text('${index + 1}'),
                          ),
                          title: Text('Sold: ${sale.quantityConsumed} ${_item.unit}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Date: ${_formatDateTime(sale.consumedAt)}'),
                              if (sale.referenceId != null)
                                Text('Reference: ${sale.referenceId}', style: TextStyle(fontSize: 12)),
                              Text('Reason: ${sale.reason}', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${(sale.quantityConsumed * _item.price).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                              Text(
                                _formatDate(sale.consumedAt),
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Future<void> _deleteItem(BuildContext context, InventoryItem item) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleting "${item.name}"...'), backgroundColor: Colors.blue),
      );
      await widget.inventoryService.deleteInventoryItem(item.id);
      if (mounted) Navigator.of(context).pop(item.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}