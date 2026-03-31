import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/inventory_item_model.dart';
import './add_edit_item_screen.dart';
import './inventory_item_screen.dart';
import './categories_screen.dart';

class InventoryDashboard extends StatefulWidget {
  final InventoryService inventoryService;
  final String userMobile;

  const InventoryDashboard({
    super.key,
    required this.inventoryService,
    required this.userMobile,
  });

  @override
  State<InventoryDashboard> createState() => _InventoryDashboardState();
}

class _InventoryDashboardState extends State<InventoryDashboard> {
  late InventoryService _inventoryService;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedFilter;
  String? _selectedCategory;
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  final List<String> _filters = ['All Items', 'Low Stock', 'Out of Stock'];
  List<String> _categories = ['All Categories'];

  @override
  void initState() {
    super.initState();
    _inventoryService = widget.inventoryService;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final categories = await _inventoryService.getCategories();
      final stats = await _inventoryService.getInventoryStats();
      
      setState(() {
        _categories = ['All Categories', ...categories];
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStatsCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isDark ? 4 : 1,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory Summary',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            
            // Compact Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
              children: [
                _statItem('Total', _stats['totalItems']?.toString() ?? '0', colorScheme.primary),
                _statItem('In Stock', _stats['inStockItems']?.toString() ?? '0', colorScheme.secondary),
                _statItem('Low', _stats['lowStockItems']?.toString() ?? '0', colorScheme.tertiary),
                _statItem('Out', _stats['outOfStockItems']?.toString() ?? '0', colorScheme.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String title, String value, Color color) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurface.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: colorScheme.surface,
      child: Row(
        children: [
          /// 🔹 STATUS DROPDOWN - Mobile Optimized
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),

                // Enhanced dropdown container
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.outline,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black12 : colorScheme.shadow.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter ?? 'All Items',
                      isExpanded: true,
                      icon: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _selectedFilter != null 
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.5),
                          size: 22,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      hint: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Select Status',
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _filters.map((filter) {
                        return DropdownMenuItem<String>(
                          value: filter,
                          child: Row(
                            children: [
                              if (filter == 'All Items')
                                Icon(
                                  Icons.list_rounded,
                                  size: 18,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                )
                              else if (filter == 'Low Stock')
                                Icon(
                                  Icons.warning_rounded,
                                  size: 18,
                                  color: colorScheme.tertiary,
                                )
                              else if (filter == 'Out of Stock')
                                Icon(
                                  Icons.block_rounded,
                                  size: 18,
                                  color: colorScheme.error,
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFilter = value == 'All Items' ? null : value;
                        });
                      },
                      dropdownColor: colorScheme.surface,
                      elevation: isDark ? 8 : 4,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          /// 🔹 CATEGORY DROPDOWN - Mobile Optimized
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),

                // Enhanced dropdown container
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colorScheme.outline,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black12 : colorScheme.shadow.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory ?? 'All Categories',
                      isExpanded: true,
                      icon: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _selectedCategory != null 
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.5),
                          size: 22,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                      hint: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Select Category',
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _categories.map((category) {
                        bool isSelected = _selectedCategory == category;
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                category == 'All Categories'
                                    ? Icons.category_rounded
                                    : Icons.folder_open_rounded,
                                size: 18,
                                color: isSelected 
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withOpacity(0.5),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected 
                                        ? FontWeight.w600 
                                        : FontWeight.w500,
                                    color: isSelected 
                                        ? colorScheme.primary
                                        : colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value == 'All Categories' ? null : value;
                        });
                      },
                      dropdownColor: colorScheme.surface,
                      elevation: isDark ? 8 : 4,
                      borderRadius: BorderRadius.circular(12),
                      menuMaxHeight: 300,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                icon: Icon(Icons.category, size: 18, color: colorScheme.primary),
                label: Text(
                  'Categories', 
                  style: TextStyle(fontSize: 13, color: colorScheme.primary)
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(color: colorScheme.primary),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoriesScreen(
                        userMobile: widget.userMobile,
                        inventoryService: widget.inventoryService,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text('Add Item', style: TextStyle(fontSize: 13, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: isDark ? 4 : 2,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditItemScreen(
                        inventoryService: _inventoryService,
                        userMobile: widget.userMobile,
                      ),
                    ),
                  ).then((_) => _loadData());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInventoryCard(InventoryItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    
    if (item.quantity <= 0) {
      statusColor = colorScheme.error;
      statusText = 'Out';
    } else if (item.isLowStock) {
      statusColor = colorScheme.tertiary;
      statusText = 'Low';
    } else {
      statusColor = colorScheme.secondary;
      statusText = 'In Stock';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isDark ? 4 : 0.5,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: colorScheme.outline, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
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
          ).then((deletedItemName) {
            if (deletedItemName != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"$deletedItemName" deleted successfully'),
                  backgroundColor: colorScheme.secondary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // First Row: Name and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.sku,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Second Row: Category, Quantity and Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Category
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.category,
                          size: 12,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Quantity and Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.quantity} ${item.unit}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '₹${item.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              // Low Stock Warning
              if (item.isLowStock && item.quantity > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.warning, size: 12, color: colorScheme.tertiary),
                      const SizedBox(width: 4),
                      Text(
                        'Reorder at ${item.lowStockThreshold}',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.tertiary,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(
          'Inventory Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: colorScheme.onSurface),
            onPressed: _loadData,
          ),
          IconButton(
            icon: Icon(Icons.search, color: colorScheme.onSurface),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _InventorySearchDelegate(
                  inventoryService: _inventoryService,
                  userMobile: widget.userMobile,
                ),
              );
            },
          ),

        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Column(
              children: [
                // Fixed Header Section (Non-scrollable)
                Container(
                  color: colorScheme.surface,
                  child: Column(
                    children: [
                      // Summary Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildStatsCard(),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Add/Category Row
                      _buildQuickActions(),
                      
                      const SizedBox(height: 4),
                      
                      // Filter Row
                      _buildFilterRow(),
                      
                      const SizedBox(height: 8),
                      
                      // Inventory Items Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Inventory Items',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            StreamBuilder<List<InventoryItem>>(
                              stream: _inventoryService.getInventoryItems(),
                              builder: (context, snapshot) {
                                int totalItems = snapshot.data?.length ?? 0;
                                return Text(
                                  '$totalItems items',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 16, 
                        thickness: 1,
                        color: colorScheme.outline,
                      ),
                    ],
                  ),
                ),
                
                // Scrollable Items List Only
                Expanded(
                  child: StreamBuilder<List<InventoryItem>>(
                    stream: _searchQuery.isNotEmpty
                        ? _inventoryService.searchInventoryItems(_searchQuery)
                        : _inventoryService.getInventoryItems(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: colorScheme.primary));
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: colorScheme.error, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'Error loading items',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final items = snapshot.data ?? [];

                      // Apply filters
                      List<InventoryItem> filteredItems = items;
                      if (_selectedFilter == 'Low Stock') {
                        filteredItems = items.where((item) => item.isLowStock).toList();
                      } else if (_selectedFilter == 'Out of Stock') {
                        filteredItems = items.where((item) => item.quantity <= 0).toList();
                      }

                      if (_selectedCategory != null && _selectedCategory != 'All Categories') {
                        filteredItems = filteredItems.where((item) => item.category == _selectedCategory).toList();
                      }

                      if (filteredItems.isEmpty) {
                        return SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inventory_2,
                                  size: 60,
                                  color: colorScheme.onSurface.withOpacity(0.2),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedCategory != null || _selectedFilter != null || _searchQuery.isNotEmpty
                                      ? 'No items match your filters'
                                      : 'No items found',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (_selectedCategory != null || _selectedFilter != null || _searchQuery.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedCategory = null;
                                          _selectedFilter = null;
                                          _searchQuery = '';
                                          _searchController.clear();
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: isDark ? 4 : 2,
                                      ),
                                      child: const Text(
                                        'Clear all filters',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: _loadData,
                        color: colorScheme.primary,
                        backgroundColor: colorScheme.surface,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            return _buildCompactInventoryCard(item);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showDeleteItemDialog(InventoryItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Delete Item', 
          style: TextStyle(fontSize: 16, color: colorScheme.onSurface)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${item.name}"?',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
            ),
            if (item.quantity > 0) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ Warning: This item has ${item.quantity} units in stock.',
                style: TextStyle(fontSize: 12, color: colorScheme.tertiary),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel', 
              style: TextStyle(fontSize: 13, color: colorScheme.primary)
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteItem(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleting "${item.name}"...'),
          backgroundColor: colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      await widget.inventoryService.deleteInventoryItem(item.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.name}" deleted successfully'),
            backgroundColor: colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting item: $e'),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
// Search Delegate for Inventory
class _InventorySearchDelegate extends SearchDelegate {
  final InventoryService inventoryService;
  final String userMobile;

  _InventorySearchDelegate({
    required this.inventoryService,
    required this.userMobile,
  });

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    final theme = Theme.of(context);
    return [
      IconButton(
        icon: Icon(Icons.clear, color: theme.colorScheme.onSurface),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<List<InventoryItem>>(
      stream: inventoryService.searchInventoryItems(query),
      builder: (context, snapshot) {
        if (query.isEmpty) {
          return Center(
            child: Text(
              'Start typing to search items',
              style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: colorScheme.primary));
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: colorScheme.onSurface.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  'No items found for "$query"',
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.5)),
                ),
              ],
            ),
          );
        }

        return Container(
          color: colorScheme.background,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  '${item.sku} • ${item.quantity} ${item.unit}',
                  style: TextStyle(
                    fontSize: 12, 
                    color: colorScheme.onSurface.withOpacity(0.6)
                  ),
                ),
                trailing: Text(
                  '₹${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                onTap: () {
                  close(context, null);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InventoryItemScreen(
                        item: item,
                        inventoryService: inventoryService,
                        userMobile: userMobile,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}