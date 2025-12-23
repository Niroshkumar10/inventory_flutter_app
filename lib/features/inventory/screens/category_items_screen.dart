// screens/category_items_screen.dart
import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/category_model.dart';
import '../models/inventory_item_model.dart';

class CategoryItemsScreen extends StatefulWidget {
  final Category category;
  final String userMobile;

  const CategoryItemsScreen({
    Key? key,
    required this.category,
    required this.userMobile,
  }) : super(key: key);

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  late InventoryService _inventoryService;
  List<InventoryItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _inventoryService = InventoryService(widget.userMobile);
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      // Try different method names that might exist
      List<InventoryItem> allItems = [];
      
      // Check which method exists in your InventoryService
      try {
        // Option 1: Try getAllInventoryItems
        allItems = await _inventoryService.getAllInventoryItems();
      } catch (e) {
        // Option 2: Try getInventoryItems as Future
        allItems = await _inventoryService.getInventoryItems().first;
      }
      
      setState(() {
        _items = allItems.where((item) => item.category == widget.category.name).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading items: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No items in this category',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text('Stock: ${item.quantity} ${item.unit}'),
                        trailing: Text('₹${item.price.toStringAsFixed(2)}'),
                      ),
                    );
                  },
                ),
    );
  }
}