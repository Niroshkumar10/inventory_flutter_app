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
    super.key,
    required this.inventoryService,
    required this.category,
    required this.userMobile,
  });

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final color = _generateColorFromString(widget.category.name);
    
    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : const Color(0xffF5F6FA),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Category Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onSurface),
            onPressed: () => setState(() {}),
          ),
          // Add Item button
          IconButton(
            icon: Icon(Icons.add, color: colorScheme.onSurface),
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
              ).then((_) => setState(() {}));
            },
            tooltip: 'Add Item to Category',
          ),
        ],
      ),
      body: StreamBuilder<List<InventoryItem>>(
        stream: _itemsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: colorScheme.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: colorScheme.error),
              ),
            );
          }

          final items = snapshot.data ?? [];
          final filteredItems = _applyFilters(items);
          final stats = _calculateStats(items);
          
          return CustomScrollView(
            slivers: [
              // Category Header Sliver
              SliverToBoxAdapter(
                child: Container(
                  color: colorScheme.surface,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Category Info
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withOpacity(0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Icon(
                                _getCategoryIcon(widget.category.name),
                                size: 30,
                                color: Colors.white,
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
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                if (widget.category.description != null &&
                                    widget.category.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      widget.category.description!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Item Count Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2, size: 16, color: color),
                            const SizedBox(width: 8),
                            Text(
                              '${items.length} Items in Category',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Stats Grid
              SliverToBoxAdapter(
                child: Container(
                  color: colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildCompactStatCard(
                        'Total Items',
                        stats['totalItems'].toString(),
                        Icons.inventory_2,
                        colorScheme.primary,
                      ),
                      _buildCompactStatCard(
                        'In Stock',
                        stats['inStockItems'].toString(),
                        Icons.check_circle,
                        colorScheme.secondary,
                      ),
                      _buildCompactStatCard(
                        'Low Stock',
                        stats['lowStockItems'].toString(),
                        Icons.warning,
                        colorScheme.tertiary,
                      ),
                      _buildCompactStatCard(
                        'Out of Stock',
                        stats['outOfStockItems'].toString(),
                        Icons.error,
                        colorScheme.error,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Total Value Card
              SliverToBoxAdapter(
                child: Container(
                  color: colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.1),
                          colorScheme.primary.withOpacity(0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.attach_money, 
                            color: colorScheme.primary, 
                            size: 24
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Inventory Value',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              Text(
                                '₹${stats['totalValue'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Search and Filter Section
              SliverToBoxAdapter(
                child: Container(
                  color: colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outline),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search, 
                              color: colorScheme.onSurface.withOpacity(0.5), 
                              size: 20
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: colorScheme.onSurface),
                                decoration: InputDecoration(
                                  hintText: 'Search items...',
                                  hintStyle: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.5)
                                  ),
                                  border: InputBorder.none,
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
                                icon: Icon(
                                  Icons.clear, 
                                  size: 18, 
                                  color: colorScheme.onSurface.withOpacity(0.5)
                                ),
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
                      
                      const SizedBox(height: 16),
                      
                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((filter) {
                            final isSelected = _selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = selected ? filter : null;
                                  });
                                },
                                backgroundColor: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
                                selectedColor: color.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSelected ? color : colorScheme.onSurface.withOpacity(0.7),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                checkmarkColor: color,
                                side: isSelected 
                                    ? BorderSide(color: color)
                                    : BorderSide(color: colorScheme.outline),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Items Header
              SliverToBoxAdapter(
                child: Container(
                  color: colorScheme.surface,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Row(
                        children: [
                          if (_selectedFilter != null || _searchQuery.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedFilter = null;
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: color,
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: const Text('Clear'),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${filteredItems.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Items List
              filteredItems.isEmpty
                  ? SliverFillRemaining(
                      child: _buildEmptyState(items.isEmpty, color),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = filteredItems[index];
                            return _buildItemCard(item, color);
                          },
                          childCount: filteredItems.length,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactStatCard(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(InventoryItem item, Color categoryColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    
    if (item.quantity <= 0) {
      statusColor = colorScheme.error;
      statusText = 'Out of Stock';
    } else if (item.isLowStock) {
      statusColor = colorScheme.tertiary;
      statusText = 'Low Stock';
    } else {
      statusColor = colorScheme.secondary;
      statusText = 'In Stock';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 4 : 2,
      color: colorScheme.surface,
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
          ).then((_) => setState(() {}));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Item Icon with category color
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [categoryColor, categoryColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.inventory_2, color: Colors.white, size: 24),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          item.sku,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor.withOpacity(0.2)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${item.quantity} ${item.unit}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '₹${item.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isCategoryEmpty, Color categoryColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCategoryEmpty ? Icons.inventory_2_outlined : Icons.search_off,
                size: 64,
                color: categoryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isCategoryEmpty ? 'No Items in Category' : 'No Results Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCategoryEmpty
                  ? 'Start by adding items to ${widget.category.name}'
                  : 'Try changing your search or filter',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (isCategoryEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
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
                  ).then((_) => setState(() {}));
                },
                icon: const Icon(Icons.add),
                label: const Text('Add First Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: categoryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isDark ? 4 : 2,
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedFilter = null;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                icon: Icon(Icons.clear, color: categoryColor),
                label: Text(
                  'Clear Filters',
                  style: TextStyle(color: categoryColor),
                ),
              ),
            ],
          ],
        ),
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
    } else if (lowerName.contains('clothing') || lowerName.contains('apparel')) {
      return Icons.checkroom;
    } else if (lowerName.contains('book') || lowerName.contains('stationery')) {
      return Icons.menu_book;
    } else if (lowerName.contains('home') || lowerName.contains('kitchen')) {
      return Icons.home;
    } else if (lowerName.contains('health') || lowerName.contains('medical')) {
      return Icons.medical_services;
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