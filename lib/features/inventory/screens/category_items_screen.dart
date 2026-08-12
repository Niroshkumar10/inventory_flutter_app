// screens/category_items_screen.dart
import 'package:flutter/material.dart';
import '../services/inventory_repo_service.dart';
import '../models/category_model.dart';
import '../models/inventory_item_model.dart';
import 'package:inventory_app/core/utils/app_logger.dart';

class CategoryItemsScreen extends StatefulWidget {
  final Category category;
  final String userMobile;

  const CategoryItemsScreen({
    super.key,
    required this.category,
    required this.userMobile,
  });

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
      appLogger.d('Error loading items: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Text(
          widget.category.name,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
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
                        color: colorScheme.onSurface.withValues(alpha:0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No items in this category',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface.withValues(alpha:0.5),
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
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Stock: ${item.quantity} ${item.unit}',
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha:0.6),
                          ),
                        ),
                        trailing: Text(
                          '₹${item.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
