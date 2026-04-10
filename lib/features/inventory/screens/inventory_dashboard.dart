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
  bool _hasShownLowStockAlert = false;
  bool _hasShownExpiredAlert = false;

  List<InventoryItem> _lowStockItems = [];
  List<InventoryItem> _expiredItems = [];

  final List<String> _filters = ['All Items', 'Low Stock', 'Out of Stock', 'Expired'];
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

      // Get low stock items
      final lowStock = await _inventoryService.getLowStockItems().first;
      
      // Get all items and filter expired ones
      final allItems = await _inventoryService.getInventoryItems().first;
      final expiredItems = allItems.where((item) => item.isExpired).toList();

      setState(() {
        _categories = ['All Categories', ...categories];
        _stats = stats;
        _lowStockItems = lowStock;
        _expiredItems = expiredItems;
        _isLoading = false;
      });

      // Show low stock modal if needed
      if (lowStock.isNotEmpty && !_hasShownLowStockAlert) {
        _hasShownLowStockAlert = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLowStockModal();
        });
      }
      
      // Show expired items modal if there are expired items
      if (expiredItems.isNotEmpty && !_hasShownExpiredAlert) {
        _hasShownExpiredAlert = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showExpiredItemsModal(expiredItems);
        });
      }

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
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
              children: [
                _statItem('Total', _stats['totalItems']?.toString() ?? '0', colorScheme.primary),
                _statItem('In Stock', _stats['inStockItems']?.toString() ?? '0', colorScheme.secondary),
                _statItem('Low', _stats['lowStockItems']?.toString() ?? '0', colorScheme.tertiary),
                _statItem('Out', _stats['outOfStockItems']?.toString() ?? '0', colorScheme.error),
                _statItem('Expired', _stats['expiredItems']?.toString() ?? _expiredItems.length.toString(), Colors.red),
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
          /// STATUS DROPDOWN
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
                                )
                              else if (filter == 'Expired')
                                Icon(
                                  Icons.event_busy,
                                  size: 18,
                                  color: Colors.red,
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

          /// CATEGORY DROPDOWN
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildCompactInventoryCard(InventoryItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    
    // Priority: Expired > Out of Stock > Low Stock > In Stock
    if (item.isExpired) {
      statusColor = Colors.red;
      statusText = 'Expired';
    } else if (item.quantity <= 0) {
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
        side: BorderSide(
          color: item.isExpired 
              ? Colors.red.withOpacity(0.5) 
              : colorScheme.outline, 
          width: item.isExpired ? 1.5 : 0.5,
        ),
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
              _loadData();
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: item.isExpired 
                                      ? Colors.red 
                                      : colorScheme.onSurface,
                                  decoration: item.isExpired 
                                      ? TextDecoration.lineThrough 
                                      : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Near expiry icon
                            if (item.isNearExpiry && !item.isExpired)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: Colors.orange,
                                ),
                              ),
                          ],
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
                          color: item.isExpired 
                              ? Colors.red.withOpacity(0.7)
                              : colorScheme.onSurface,
                          decoration: item.isExpired 
                              ? TextDecoration.lineThrough 
                              : null,
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
              
              // EXPIRY WARNING SECTION
              if (item.trackExpiry && item.expiryDate != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: item.isExpired 
                        ? Colors.red.withOpacity(0.1)
                        : (item.isNearExpiry 
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.green.withOpacity(0.05)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.isExpired 
                          ? Colors.red.withOpacity(0.3)
                          : (item.isNearExpiry 
                              ? Colors.orange.withOpacity(0.3)
                              : Colors.green.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.isExpired 
                            ? Icons.event_busy
                            : (item.isNearExpiry 
                                ? Icons.warning_amber_rounded
                                : Icons.event_available),
                        size: 14,
                        color: item.isExpired 
                            ? Colors.red
                            : (item.isNearExpiry 
                                ? Colors.orange
                                : Colors.green),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.isExpired
                              ? '❌ EXPIRED on ${_formatDate(item.expiryDate!)}'
                              : (item.isNearExpiry
                                  ? '⚠️ Expires in ${item.daysUntilExpiry} days (${_formatDate(item.expiryDate!)})'
                                  : '✓ Valid until ${_formatDate(item.expiryDate!)}'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: item.isExpired 
                                ? Colors.red
                                : (item.isNearExpiry 
                                    ? Colors.orange
                                    : Colors.green),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Low Stock Warning (only if not expired)
              if (item.isLowStock && item.quantity > 0 && !item.isExpired)
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

  void _showExpiredItemsModal(List<InventoryItem> expiredItems) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  children: [
                    Icon(Icons.event_busy, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Expired Items Alert",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "The following items have expired and need immediate attention:",
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                
                // LIST OF EXPIRED ITEMS
                Expanded(
                  child: ListView.builder(
                    itemCount: expiredItems.length,
                    itemBuilder: (context, index) {
                      final item = expiredItems[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: Colors.red.withOpacity(0.05),
                        child: ListTile(
                          leading: const Icon(Icons.warning, color: Colors.red),
                          title: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SKU: ${item.sku}'),
                              Text(
                                'Expired on: ${_formatDate(item.expiryDate!)}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: Text(
                            '${item.quantity} ${item.unit}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
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
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // ACTION BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                        ),
                        child: const Text("Later"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedFilter = 'Expired';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text("View All"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLowStockModal() {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxHeight: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: colorScheme.tertiary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Low Stock Alert",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  "These items need restocking:",
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 10),

                // LIST
                Expanded(
                  child: ListView.builder(
                    itemCount: _lowStockItems.length,
                    itemBuilder: (context, index) {
                      final item = _lowStockItems[index];

                      return Card(
                        elevation: 0.5,
                        child: ListTile(
                          leading: const Icon(Icons.inventory_2),
                          title: Text(item.name),
                          subtitle: Text(
                            'Qty: ${item.quantity} | Min: ${item.lowStockThreshold}',
                          ),
                          trailing: Text(
                            "Low",
                            style: TextStyle(
                              color: colorScheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
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
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("OK"),
                  ),
                )
              ],
            ),
          ),
        );
      },
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

                      // Alert Cards

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
                      } else if (_selectedFilter == 'Expired') {
                        filteredItems = items.where((item) => item.isExpired).toList();
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
        _loadData();
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