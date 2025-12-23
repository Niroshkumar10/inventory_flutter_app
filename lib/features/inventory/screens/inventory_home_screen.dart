import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/inventory_item_model.dart';
import './inventory_item_screen.dart';
import './add_edit_item_screen.dart';

class InventoryHomeScreen extends StatefulWidget {
  final String userMobile;
    final InventoryService inventoryService; // This should exist

  
  const InventoryHomeScreen({
    Key? key,
    required this.userMobile,
    required this.inventoryService,
  }) : super(key: key);

  @override
  State<InventoryHomeScreen> createState() => _InventoryHomeScreenState();
}

class _InventoryHomeScreenState extends State<InventoryHomeScreen> {
  late InventoryService _inventoryService;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _inventoryService = InventoryService(widget.userMobile);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _inventoryService.getCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Categories'),
                      ),
                      ..._categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
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
          ),
          StreamBuilder<List<InventoryItem>>(
            stream: _searchQuery.isNotEmpty
                ? _inventoryService.searchInventoryItems(_searchQuery)
                : _inventoryService.getInventoryItems(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Expanded(
                  child: Center(
                    child: Text('Error: ${snapshot.error}'),
                  ),
                );
              }

              final items = snapshot.data ?? [];

              // Apply category filter
              List<InventoryItem> filteredItems = items;
              if (_selectedCategory != null) {
                filteredItems = items
                    .where((item) => item.category == _selectedCategory)
                    .toList();
              }

              if (filteredItems.isEmpty) {
                return const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No items found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Expanded(
                child: ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return _buildInventoryItemCard(item);
                  },
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditItemScreen(
                inventoryService: _inventoryService,
                userMobile: widget.userMobile,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

// Find this method and update the trailing property:
Widget _buildInventoryItem(InventoryItem item) {
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: ListTile(
      // ... your existing content ...
      
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edit button (you should already have this)
          IconButton(
            onPressed: () => _editItem(item),
            icon: const Icon(Icons.edit, size: 20),
            color: Colors.blue,
            tooltip: 'Edit Item',
          ),
          
          // ADD THIS DELETE BUTTON:
          IconButton(
            onPressed: () => _showDeleteItemDialog(item),
            icon: const Icon(Icons.delete, size: 20),
            color: Colors.red,
            tooltip: 'Delete Item',
          ),
        ],
      ),
    ),
  );
}


  void _handleMenuItemSelected(String value, InventoryItem item) {
    switch (value) {
      case 'view':
        _navigateToItemDetails(item);
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddEditItemScreen(
              inventoryService: _inventoryService,
              item: item,
              userMobile: widget.userMobile,
            ),
          ),
        );
        break;
      case 'adjust':
        // Navigate to adjust stock screen
        break;
      case 'delete':
        _showDeleteDialog(item);
        break;
    }
  }

  void _navigateToItemDetails(InventoryItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
 builder: (context) => InventoryItemScreen(
        item: item,
        inventoryService: widget.inventoryService, // Pass service
        userMobile: widget.userMobile, // Pass user mobile
      ),      ),
    );
  }

  void _showDeleteDialog(InventoryItem item) {
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
          TextButton(
            onPressed: () async {
              try {
                await _inventoryService.deleteInventoryItem(item.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Item deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting item: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}