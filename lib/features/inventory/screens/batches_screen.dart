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
    return Scaffold(
      appBar: AppBar(
        title: Text('Batches - ${widget.itemName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: expiryColor.withOpacity(0.1),
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
                              color: Colors.orange.withOpacity(0.1),
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
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}