import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/inventory_item_model.dart';
import './add_edit_item_screen.dart';
import './inventory_item_screen.dart';
import './categories_screen.dart';

class InventoryDashboard extends StatefulWidget {
    final InventoryService inventoryService; // Make sure this exists

  final String userMobile;
  
 const InventoryDashboard({
    Key? key,
    required this.inventoryService, // This should be here
    required this.userMobile, // And this
  }) : super(key: key);


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
    _inventoryService = InventoryService(widget.userMobile);
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventory Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Track & manage your stock',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            
            // Stats Grid
            SizedBox(
              height: 90, // Increased height to accommodate text
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.9, // Adjusted aspect ratio
                children: [
                  _statItem('Total Items', _stats['totalItems']?.toString() ?? '0', Colors.blue),
                  _statItem('In Stock', _stats['inStockItems']?.toString() ?? '0', Colors.green),
                  _statItem('Low Stock', _stats['lowStockItems']?.toString() ?? '0', Colors.orange),
                  _statItem('Out of Stock', _stats['outOfStockItems']?.toString() ?? '0', Colors.red),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Value
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          
          // Title
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 10, // Smaller font size
                  color: Colors.grey,
                ),
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
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
              backgroundColor: Colors.grey.shade100,
              selectedColor: Colors.blue.shade100,
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey.shade700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryChips() {
    if (_categories.length <= 1) return const SizedBox();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category || 
              (_selectedCategory == null && category == 'All Categories');
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : 'All Categories';
                  if (_selectedCategory == 'All Categories') {
                    _selectedCategory = null;
                  }
                });
              },
              backgroundColor: Colors.grey.shade100,
              selectedColor: Colors.green.shade100,
              labelStyle: TextStyle(
                color: isSelected ? Colors.green.shade800 : Colors.grey.shade700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filter by Category',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        _buildCategoryChips(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header section - Fixed height
                Container(
                  height: MediaQuery.of(context).size.height * 0.45, // 45% of screen
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsCard(),
                        const SizedBox(height: 16),
                        
                        // Categories and Add Item buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.category),
                                label: const Text('Categories'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CategoriesScreen(
                                        userMobile: widget.userMobile,
                                        inventoryService: widget.inventoryService, // Add this
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add Item'),
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
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Search Bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search items...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _searchController.clear();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Filter Chips Section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filter by Status',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildFilterChips(),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Category Filter Section
                        _buildCategoryFilterSection(),
                        
                        const SizedBox(height: 16),
                        
                        // Inventory Items Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Inventory Items',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_selectedCategory != null || _selectedFilter != null)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedCategory = null;
                                    _selectedFilter = null;
                                  });
                                },
                                icon: const Icon(Icons.clear_all, size: 16),
                                label: const Text('Clear filters'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Divider
                const Divider(height: 1),
                
                // Inventory items list section
                Expanded(
                  child: StreamBuilder<List<InventoryItem>>(
                    stream: _searchQuery.isNotEmpty
                        ? _inventoryService.searchInventoryItems(_searchQuery)
                        : _inventoryService.getInventoryItems(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      final items = snapshot.data ?? [];

                      // Apply status filter
                      List<InventoryItem> filteredItems = items;
                      if (_selectedFilter == 'Low Stock') {
                        filteredItems = items.where((item) => item.isLowStock).toList();
                      } else if (_selectedFilter == 'Out of Stock') {
                        filteredItems = items.where((item) => item.quantity <= 0).toList();
                      }

                      // Apply category filter
                      if (_selectedCategory != null && _selectedCategory != 'All Categories') {
                        filteredItems = filteredItems.where((item) => item.category == _selectedCategory).toList();
                      }

                      // Show active filters summary
                      if ((_selectedCategory != null || _selectedFilter != null) && filteredItems.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ScaffoldMessenger.of(context).removeCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Showing ${filteredItems.length} items'
                                '${_selectedFilter != null ? ' ($_selectedFilter)' : ''}'
                                '${_selectedCategory != null ? ' in "$_selectedCategory"' : ''}',
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.blue,
                            ),
                          );
                        });
                      }

                      if (filteredItems.isEmpty) {
                        return SingleChildScrollView(
                          child: Container(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inventory_2,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No items found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (_selectedCategory != null || _selectedFilter != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedCategory = null;
                                          _selectedFilter = null;
                                        });
                                      },
                                      child: const Text('Clear filters'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          // Summary info
                          if (_selectedCategory != null || _selectedFilter != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.filter_list,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${filteredItems.length} items'
                                      '${_selectedFilter != null ? ' • $_selectedFilter' : ''}'
                                      '${_selectedCategory != null ? ' • Category: $_selectedCategory' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue.shade700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Items list
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return _buildInventoryCard(item);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    
    );
  }

  // Add this method for delete dialog:
void _showDeleteItemDialog(InventoryItem item) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete "${item.name}"?'),
          if (item.quantity > 0) ...[
            const SizedBox(height: 8),
            Text(
              '⚠️ Warning: This item has ${item.quantity} units in stock.',
              style: const TextStyle(color: Colors.orange),
            ),
          ],
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
            await _deleteItem(item);
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

// Add this method for actual deletion:
Future<void> _deleteItem(InventoryItem item) async {
  try {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleting "${item.name}"...'),
        backgroundColor: Colors.blue,
      ),
    );

    // Use soft delete
    await widget.inventoryService.deleteInventoryItem(item.id);
    
    // Show success - the stream will automatically refresh the list
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${item.name}" deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error deleting item: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Widget _buildInventoryCard(InventoryItem item) {
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
      borderRadius: BorderRadius.circular(10),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
       // When navigating to item detail
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
  // This will be called when we return from detail screen
  if (deletedItemName != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$deletedItemName" deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
});
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Name and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // SKU and Category
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.sku,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedCategory == item.category 
                        ? Colors.green.shade100 
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedCategory == item.category 
                          ? Colors.green.shade300 
                          : Colors.blue.shade100,
                      width: _selectedCategory == item.category ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.category,
                        size: 12,
                        color: _selectedCategory == item.category 
                            ? Colors.green.shade800 
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _selectedCategory == item.category 
                              ? Colors.green.shade800 
                              : Colors.blue.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Stock and Price Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Stock Info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Stock',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${item.quantity} ${item.unit}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                
                // Price Info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Selling Price',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '₹${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // Reorder Level (if applicable)
            if (item.isLowStock && item.quantity > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      size: 14,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reorder at: ${item.lowStockThreshold}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            
            // ========== ADD THIS SECTION ==========
            // Action Buttons (Edit & Delete)
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit Button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddEditItemScreen(
                          inventoryService: _inventoryService,
                          item: item,
                          userMobile: widget.userMobile,
                        ),
                      ),
                    ).then((_) => _loadData());
                  },
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                ),
                const SizedBox(width: 8),
                
                // Delete Button
                OutlinedButton.icon(
                  onPressed: () => _showDeleteItemDialog(item),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                ),
              ],
            ),
            // ========== END OF NEW SECTION ==========
          ],
        ),
      ),
    ),
  );
}

}