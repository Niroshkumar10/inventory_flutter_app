// screens/categories_screen.dart
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../services/inventory_repo_service.dart';
import '../models/inventory_item_model.dart';
import './category_dashboard_screen.dart'; // ADD THIS LINE - make sure file exists
import './add_edit_category_screen.dart';


class CategoriesScreen extends StatefulWidget {
  final String userMobile;
    final InventoryService inventoryService; // Add this

  const CategoriesScreen({
    Key? key,
    required this.userMobile,
    required this.inventoryService,
  }) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late InventoryService _inventoryService;
  List<Category> _categories = [];
  List<InventoryItem> _allItems = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Category statistics
  int _totalItems = 0;
  int _lowStockItems = 0;
  int _outOfStockItems = 0;
  int _categoriesCount = 0;

  @override
  void initState() {
    super.initState();
    _inventoryService = InventoryService(widget.userMobile);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final categories = await _inventoryService.getCategoriesWithCount();
      final allItems = await _getAllItems();
      
      // Calculate statistics
      int totalItems = 0;
      int lowStockItems = 0;
      int outOfStockItems = 0;
      
      for (final item in allItems) {
        totalItems++;
        if (item.quantity <= 0) {
          outOfStockItems++;
        } else if (item.isLowStock) {
          lowStockItems++;
        }
      }
      
      setState(() {
        _categories = categories;
        _allItems = allItems;
        _categoriesCount = categories.length;
        _totalItems = totalItems;
        _lowStockItems = lowStockItems;
        _outOfStockItems = outOfStockItems;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<InventoryItem>> _getAllItems() async {
    try {
      // Try different methods to get items
      // Adjust based on your available methods
      final itemsStream = _inventoryService.getInventoryItems();
      return await itemsStream.first;
    } catch (e) {
      print('Error getting items: $e');
      return [];
    }
  }

  List<Category> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    return _categories
        .where((category) =>
            category.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
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
                  padding: const EdgeInsets.all(6),
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
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                              hintText: 'Search categories...',
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
                  
                  const SizedBox(height: 20),
                  
                  // Statistics Row
                  Row(
                    children: [
                      _buildStatsCard(
                        'Categories',
                        _categoriesCount.toString(),
                        Icons.category,
                        Colors.blue,
                      ),
                      _buildStatsCard(
                        'Total Items',
                        _totalItems.toString(),
                        Icons.inventory_2,
                        Colors.green,
                      ),
                      _buildStatsCard(
                        'Low Stock',
                        _lowStockItems.toString(),
                        Icons.warning,
                        Colors.orange,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Categories Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'All Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_filteredCategories.length} categories',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Categories Grid
                  _filteredCategories.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No categories found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add your first category to organize items',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _navigateToAddCategory,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Category'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: _filteredCategories.length,
                          itemBuilder: (context, index) {
                            final category = _filteredCategories[index];
                            return _buildCategoryCard(category);
                          },
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddCategory,
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    // Generate color based on category name
    final color = _generateColorFromString(category.name);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryDashboardScreen(
        inventoryService: widget.inventoryService, // Use widget.inventoryService
              category: category,
              userMobile: widget.userMobile,
            ),
          ),
        );
      },
      onLongPress: () {
        _showCategoryOptions(category);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Category Icon and Name
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        _getCategoryIcon(category.name),
                        size: 20,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              
              // Item Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${category.itemCount} items',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: color,
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
    } else if (lowerName.contains('office')) {
      return Icons.work;
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

  void _navigateToAddCategory() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCategoryScreen(
          inventoryService: _inventoryService,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  void _showCategoryOptions(Category category) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Category'),
                onTap: () {
                  Navigator.pop(context);
                  _editCategory(category);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Category'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteCategory(category);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editCategory(Category category) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCategoryScreen(
          inventoryService: _inventoryService,
          category: category,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  void _deleteCategory(Category category) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
await widget.inventoryService.deleteCategory(category.id, category.name);        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${category.name}" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}