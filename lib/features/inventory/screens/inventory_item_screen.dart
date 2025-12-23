// ./lib/features/inventory/screens/inventory_item_screen.dart

import 'package:flutter/material.dart';
import '../models/inventory_item_model.dart';
import '../services/inventory_repo_service.dart';
import './add_edit_item_screen.dart';

class InventoryItemScreen extends StatelessWidget {
  final InventoryItem item;
  final InventoryService inventoryService;
  final String userMobile;

  const InventoryItemScreen({
    Key? key,
    required this.item,
    required this.inventoryService,
    required this.userMobile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditItemScreen(
                    inventoryService: inventoryService,
                    item: item,
                    userMobile: userMobile,
                  ),
                ),
              ).then((value) {
                if (value == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Item updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              });
            },
            tooltip: 'Edit Item',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _showDeleteDialog(context, item), // Pass context
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
            _buildInfoSection(),
            const SizedBox(height: 24),
            _buildStockSection(),
            const SizedBox(height: 24),
            _buildFinancialSection(),
            const SizedBox(height: 24),
            _buildAdditionalInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: item.isLowStock ? Colors.orange.shade100 : Colors.blue.shade100,
          child: Icon(
            item.isLowStock ? Icons.warning : Icons.inventory_2,
            size: 40,
            color: item.isLowStock ? Colors.orange : Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.sku,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(item.category),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(label: 'Description', value: item.description),
            const Divider(),
            _buildInfoRow(label: 'Unit', value: item.unit),
            const Divider(),
            _buildInfoRow(label: 'Location', value: item.location ?? 'Not specified'),
            const Divider(),
            _buildInfoRow(label: 'Supplier ID', value: item.supplierId ?? 'Not specified'),
            const Divider(),
            _buildInfoRow(
              label: 'Created',
              value: '${item.createdAt.toLocal().toString().split(' ')[0]}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Current Stock',
                    value: item.quantity.toString(),
                    color: item.isLowStock ? Colors.orange : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Low Stock Alert',
                    value: item.lowStockThreshold.toString(),
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: item.quantity / (item.lowStockThreshold * 3).clamp(1, double.infinity),
              backgroundColor: Colors.grey.shade200,
              color: item.isLowStock ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              item.isLowStock ? '⚠️ Low stock alert!' : 'Stock level is good',
              style: TextStyle(
                color: item.isLowStock ? Colors.orange : Colors.green,
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Cost Price',
                    value: '₹${item.cost.toStringAsFixed(2)}',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Selling Price',
                    value: '₹${item.price.toStringAsFixed(2)}',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Profit Margin',
                    value: '${item.profitMargin.toStringAsFixed(1)}%',
                    color: item.profitMargin >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Value',
                    value: '₹${item.totalValue.toStringAsFixed(2)}',
                    color: Colors.purple,
                  ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              label: 'Last Updated',
              value: item.updatedAt.toLocal().toString(),
            ),
            const Divider(),
            _buildInfoRow(label: 'Item ID', value: item.id),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
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

  // Delete Methods - Fixed to accept BuildContext parameter
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

 Future<void> _deleteItem(BuildContext context, InventoryItem item) async {
  try {
    // Close the dialog using root navigator
    Navigator.of(context, rootNavigator: true).pop();
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleting "${item.name}"...'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 1),
      ),
    );

    await inventoryService.deleteInventoryItem(item.id);
    
    // Navigate back to inventory list using root navigator
    Navigator.of(context, rootNavigator: true).pop(item.name);
    
  } catch (e) {
    // Only show error if still on screen
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
}