import 'dart:async';
import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/category_model.dart';
import '../models/inventory_item_model.dart';
import './add_edit_item_screen.dart';
import './inventory_item_screen.dart';

class CategoryDashboardScreen extends StatefulWidget {
  final InventoryService inventoryService;
  final Category category;
  final String userMobile;

  const CategoryDashboardScreen({
    Key? key,
    required this.inventoryService,
    required this.category,
    required this.userMobile,
  }) : super(key: key);

  @override
  State<CategoryDashboardScreen> createState() => _CategoryDashboardScreenState();
}

class _CategoryDashboardScreenState extends State<CategoryDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedFilter;
  final List<String> _filters = ['All', 'Low Stock', 'Out of Stock'];

  // Stream for items - automatically updates
  Stream<List<InventoryItem>> get _itemsStream {
    return widget.inventoryService.getInventoryItems().map((allItems) {
      // Filter items for this category (case insensitive)
      return allItems.where((item) => 
          item.category.trim().toLowerCase() == widget.category.name.trim().toLowerCase()
      ).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InventoryItem> _applyFilters(List<InventoryItem> items) {
    List<InventoryItem> filtered = items;
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) =>
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.sku.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    if (_selectedFilter == 'Low Stock') {
      filtered = filtered.where((item) => item.isLowStock && item.quantity > 0).toList();
    } else if (_selectedFilter == 'Out of Stock') {
      filtered = filtered.where((item) => item.quantity <= 0).toList();
    }
    
    return filtered;
  }

  Map<String, dynamic> _calculateStats(List<InventoryItem> items) {
    int totalItems = items.length;
    int inStockItems = 0;
    int lowStockItems = 0;
    int outOfStockItems = 0;
    double totalValue = 0.0;
    
    for (final item in items) {
      totalValue += item.price * item.quantity;
      
      if (item.quantity <= 0) {
        outOfStockItems++;
      } else if (item.isLowStock) {
        lowStockItems++;
      } else {
        inStockItems++;
      }
    }
    
    return {
      'totalItems': totalItems,
      'inStockItems': inStockItems,
      'lowStockItems': lowStockItems,
      'outOfStockItems': outOfStockItems,
      'totalValue': totalValue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _generateColorFromString(widget.category.name);
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.category.name),
            StreamBuilder<List<InventoryItem>>(
              stream: _itemsStream,
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.length : 0;
                return Text(
                  '$count items',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditItemScreen(
                    inventoryService: widget.inventoryService,
                    userMobile: widget.userMobile,
                    initialCategory: widget.category.name,
                  ),
                ),
              );
            },
            tooltip: 'Add Item to Category',
          ),
        ],
      ),
      body: StreamBuilder<List<InventoryItem>>(
        stream: _itemsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final items = snapshot.data ?? [];
          final filteredItems = _applyFilters(items);
          final stats = _calculateStats(items);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            _getCategoryIcon(widget.category.name),
                            size: 30,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.category.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.category.description != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  widget.category.description!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Statistics Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildStatCard(
                      'Total Items',
                      stats['totalItems'].toString(),
                      Icons.inventory_2,
                      Colors.blue,
                      'Items in category',
                    ),
                    _buildStatCard(
                      'In Stock',
                      stats['inStockItems'].toString(),
                      Icons.check_circle,
                      Colors.green,
                      'Available items',
                    ),
                    _buildStatCard(
                      'Low Stock',
                      stats['lowStockItems'].toString(),
                      Icons.warning,
                      Colors.orange,
                      'Need reorder',
                    ),
                    _buildStatCard(
                      'Out of Stock',
                      stats['outOfStockItems'].toString(),
                      Icons.error,
                      Colors.red,
                      'Need restock',
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Total Value Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_money, color: Colors.blue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Inventory Value',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '₹${stats['totalValue'].toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Search and Filter Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search items in this category...',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedFilter = selected ? filter : null;
                                });
                              },
                              backgroundColor: Colors.grey.shade100,
                              selectedColor: color.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: isSelected ? color : Colors.grey.shade700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Items Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items (${filteredItems.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedFilter != null || _searchQuery.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedFilter = null;
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                        child: const Text('Clear filters'),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Items List
                filteredItems.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              items.isEmpty ? 'No items in this category' : 'No items found',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              items.isEmpty
                                  ? 'Add items to this category'
                                  : 'Try changing your search or filter',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddEditItemScreen(
                                          inventoryService: widget.inventoryService,
                                          userMobile: widget.userMobile,
                                          initialCategory: widget.category.name,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add First Item'),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _buildItemCard(item);
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item) {
    Color statusColor;
    String statusText;
    
    if (item.quantity <= 0) {
      statusColor = Colors.red;
      statusText = 'Out of Stock';
    } else if (item.isLowStock) {
      statusColor = Colors.orange;
      statusText = 'Low Stock';
    } else {
      statusColor = Colors.green;
      statusText = 'In Stock';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InventoryItemScreen(
                item: item,
                inventoryService: widget.inventoryService,
                userMobile: widget.userMobile,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Item Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.inventory_2, color: Colors.grey),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.sku,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${item.quantity} ${item.unit}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Price',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '₹${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final lowerName = categoryName.toLowerCase();
    
    if (lowerName.contains('grocery') || lowerName.contains('food')) {
      return Icons.shopping_basket;
    } else if (lowerName.contains('beverage') || lowerName.contains('drink')) {
      return Icons.local_drink;
    } else if (lowerName.contains('snack')) {
      return Icons.fastfood;
    } else if (lowerName.contains('personal') || lowerName.contains('care')) {
      return Icons.spa;
    } else if (lowerName.contains('electronic')) {
      return Icons.electrical_services;
    }
    
    return Icons.category;
  }

  Color _generateColorFromString(String text) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];
    
    final index = text.hashCode.abs() % colors.length;
    return colors[index];
  }
}