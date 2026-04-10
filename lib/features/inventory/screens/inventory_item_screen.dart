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
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showSellDialog(),
            icon: const Icon(Icons.sell),
            label: const Text('Sell Stock'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
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
    
    final maxQuantity = _item.trackByBatch 
        ? (_batchSummary?['totalRemaining'] ?? 0)
        : _item.quantity;

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
    
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: _item.isExpired
              ? Colors.red.shade100
              : _item.isLowStock
                  ? Colors.orange.shade100
                  : Colors.blue.shade100,
          child: Icon(
            _item.isLowStock ? Icons.warning : Icons.inventory_2,
            size: 40,
            color: _item.isLowStock ? Colors.orange : Colors.blue,
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
              Chip(
                label: Text(_item.category),
                backgroundColor: Colors.blue.shade50,
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
            _buildInfoRow('Description', _item.description),
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
                        if (_item.trackExpiry && _item.expiryDate != null) ...[
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
                              '⚠️ Multiple expiry dates exist in batches',
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
          const SizedBox(
            width: 120,
            child: Text(
              '',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
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
    
    final displayQuantity = _item.trackByBatch 
        ? (_batchSummary?['totalRemaining'] ?? 0)
        : _item.quantity;
    
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
                    '$displayQuantity ${_item.unit}',
                    _item.isLowStock ? Colors.orange : Colors.green,
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
              value: displayQuantity / (_item.lowStockThreshold * 3).clamp(1, double.infinity),
              backgroundColor: Colors.grey.shade200,
              color: _item.isLowStock ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              _item.isLowStock ? '⚠️ Low stock alert!' : 'Stock level is good',
              style: TextStyle(
                color: _item.isLowStock ? Colors.orange : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSection() {
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
                  child: _buildStatCard('Total Value', '₹${_item.totalValue.toStringAsFixed(2)}', Colors.purple),
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

  // FIXED: This is the correct _buildStatCard method
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