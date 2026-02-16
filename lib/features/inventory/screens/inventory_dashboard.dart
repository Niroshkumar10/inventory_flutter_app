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
    Key? key,
    required this.inventoryService,
    required this.userMobile,
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
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventory Summary',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
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
                _statItem('Total', _stats['totalItems']?.toString() ?? '0', Colors.blue),
                _statItem('In Stock', _stats['inStockItems']?.toString() ?? '0', Colors.green),
                _statItem('Low', _stats['lowStockItems']?.toString() ?? '0', Colors.orange),
                _statItem('Out', _stats['outOfStockItems']?.toString() ?? '0', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String title, String value, Color color) {
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
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          /// 🔹 STATUS DROPDOWN
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter ?? 'All Items',
                      isExpanded: true,
                      icon: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade600,
                          size: 26,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _filters.map((filter) {
                        return DropdownMenuItem<String>(
                          value: filter,
                          child: Text(
                            filter,
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFilter =
                              value == 'All Items' ? null : value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          /// 🔹 CATEGORY DROPDOWN
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory ?? 'All Categories',
                      isExpanded: true,
                      icon: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade600,
                          size: 26,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(
                            category,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory =
                              value == 'All Categories' ? null : value;
                        });
                      },
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.category, size: 18),
                label: const Text('Categories', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
    Color statusColor;
    String statusText;
    
    if (item.quantity <= 0) {
      statusColor = Colors.red;
      statusText = 'Out';
    } else if (item.isLowStock) {
      statusColor = Colors.orange;
      statusText = 'Low';
    } else {
      statusColor = Colors.green;
      statusText = 'In Stock';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200, width: 0.5),
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
                  backgroundColor: Colors.green,
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.sku,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
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
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.category,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Quantity and Price
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.quantity} ${item.unit}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${item.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
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
                      Icon(Icons.warning, size: 12, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        'Reorder at ${item.lowStockThreshold}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inventory Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Show search dialog or navigate to search screen
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
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Fixed Header Section (Non-scrollable)
                Container(
                  color: Colors.white,
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
                                color: Colors.grey.shade800,
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
                                    color: Colors.grey.shade600,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 16, thickness: 1),
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
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 40),
                              const SizedBox(height: 8),
                              Text(
                                'Error loading items',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
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
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedCategory != null || _selectedFilter != null || _searchQuery.isNotEmpty
                                      ? 'No items match your filters'
                                      : 'No items found',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
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
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${item.name}"?',
              style: const TextStyle(fontSize: 14),
            ),
            if (item.quantity > 0) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ Warning: This item has ${item.quantity} units in stock.',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontSize: 13)),
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
            child: const Text('Delete', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(InventoryItem item) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleting "${item.name}"...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );

      await widget.inventoryService.deleteInventoryItem(item.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${item.name}" deleted successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting item: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
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
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return StreamBuilder<List<InventoryItem>>(
      stream: inventoryService.searchInventoryItems(query),
      builder: (context, snapshot) {
        if (query.isEmpty) {
          return const Center(
            child: Text('Start typing to search items'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No items found for "$query"',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
              ),
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                '${item.sku} • ${item.quantity} ${item.unit}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Text(
                '₹${item.price.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
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
        );
      },
    );
  }
}