// lib/features/inventory/screens/all_batches_screen.dart
import 'package:flutter/material.dart';
import '../models/batch_model.dart';
import '../services/inventory_repo_service.dart';

enum BatchFilter { all, active, nearExpiry, expired, lowStock }

class AllBatchesScreen extends StatefulWidget {
  final InventoryService inventoryService;

  const AllBatchesScreen({
    super.key,
    required this.inventoryService,
  });

  @override
  State<AllBatchesScreen> createState() => _AllBatchesScreenState();
}

class _AllBatchesScreenState extends State<AllBatchesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<_BatchWithItem> _allBatches = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllBatches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllBatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await widget.inventoryService.getAllInventoryItems();
      final List<_BatchWithItem> result = [];

      for (final item in items) {
        if (!item.trackByBatch) continue;
        final batches =
            await widget.inventoryService.batchService.getBatchesOnce(item.id);
        for (final batch in batches) {
          result.add(_BatchWithItem(
              batch: batch,
              itemName: item.name,
              itemUnit: item.unit,
              itemId: item.id));
        }
      }

      result.sort((a, b) {
        if (a.batch.isExpired && !b.batch.isExpired) return 1;
        if (!a.batch.isExpired && b.batch.isExpired) return -1;
        if (a.batch.isNearExpiry && !b.batch.isNearExpiry) return -1;
        if (!a.batch.isNearExpiry && b.batch.isNearExpiry) return 1;
        return a.batch.expiryDate.compareTo(b.batch.expiryDate);
      });

      setState(() {
        _allBatches = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<_BatchWithItem> _getFilteredBatches(BatchFilter filter) {
    List<_BatchWithItem> batches;
    switch (filter) {
      case BatchFilter.all:
        batches = _allBatches;
        break;
      case BatchFilter.active:
        batches = _allBatches
            .where((b) =>
                !b.batch.isExpired &&
                !b.batch.isNearExpiry &&
                b.batch.remainingQuantity > 0)
            .toList();
        break;
      case BatchFilter.nearExpiry:
        batches = _allBatches
            .where((b) => b.batch.isNearExpiry && !b.batch.isExpired)
            .toList();
        break;
      case BatchFilter.expired:
        batches = _allBatches.where((b) => b.batch.isExpired).toList();
        break;
      case BatchFilter.lowStock:
        batches = _allBatches
            .where((b) => b.batch.isLowStock && !b.batch.isExpired)
            .toList();
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      batches = batches
          .where((b) =>
              b.itemName.toLowerCase().contains(q) ||
              b.batch.batchNumber.toLowerCase().contains(q) ||
              (b.batch.supplierName?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return batches;
  }

  int _countFor(BatchFilter filter) => _getFilteredBatches(filter).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark ? colorScheme.surface : const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Batch Management',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllBatches,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              // ── Search bar ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search item, batch no, supplier…',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 14),
                    prefixIcon: Icon(Icons.search,
                        size: 20, color: Colors.white.withValues(alpha: 0.8)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                size: 18,
                                color: Colors.white.withValues(alpha: 0.8)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              // ── Tab bar ──
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                tabs: [
                  _buildTab('All', _countFor(BatchFilter.all), null),
                  _buildTab('Active', _countFor(BatchFilter.active),
                      Colors.greenAccent),
                  _buildTab('Near Expiry',
                      _countFor(BatchFilter.nearExpiry), Colors.orangeAccent),
                  _buildTab('Expired', _countFor(BatchFilter.expired),
                      Colors.redAccent),
                  _buildTab('Low Stock', _countFor(BatchFilter.lowStock),
                      Colors.purpleAccent),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: BatchFilter.values
                      .map((f) => _buildBatchList(f))
                      .toList(),
                ),
    );
  }

  // ── Tab ──────────────────────────────────────────────────────────────────

  Tab _buildTab(String label, int count, Color? dotColor) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(label),
          const SizedBox(width: 5),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 16),
            Text('Something went wrong',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAllBatches,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Batch list per tab ────────────────────────────────────────────────────

  Widget _buildBatchList(BatchFilter filter) {
    final batches = _getFilteredBatches(filter);

    if (batches.isEmpty) {
      return _buildEmptyState(filter);
    }

    return RefreshIndicator(
      onRefresh: _loadAllBatches,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSummaryHeader(batches, filter)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _BatchCard(
                    data: batches[i],
                    inventoryService: widget.inventoryService,
                    onUpdated: _loadAllBatches),
                childCount: batches.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BatchFilter filter) {
    final messages = {
      BatchFilter.all:
          'No batches yet.\nAdd batches from your Inventory items.',
      BatchFilter.active: 'No active batches right now.',
      BatchFilter.nearExpiry: '✅ No batches expiring soon. All good!',
      BatchFilter.expired: '✅ No expired batches.',
      BatchFilter.lowStock: '✅ No low-stock batches.',
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No batches match your search'
                : messages[filter] ?? '',
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 15,
                height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Summary header ────────────────────────────────────────────────────────

  Widget _buildSummaryHeader(List<_BatchWithItem> batches, BatchFilter filter) {
    final totalRemaining =
        batches.fold<int>(0, (s, b) => s + b.batch.remainingQuantity);

    Widget row(List<Widget> cards) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                cards[i],
              ],
            ],
          ),
        );

    switch (filter) {
      case BatchFilter.all:
        final expiredCount = batches.where((b) => b.batch.isExpired).length;
        final nearExpiryCount =
            batches.where((b) => b.batch.isNearExpiry && !b.batch.isExpired).length;
        return row([
          _statCard('${batches.length}', 'Batches', Icons.layers, Colors.blue),
          _statCard('$totalRemaining', 'In Stock', Icons.inventory_2, Colors.green),
          _statCard('$nearExpiryCount', 'Near Expiry', Icons.warning_amber, Colors.orange),
          _statCard('$expiredCount', 'Expired', Icons.cancel_outlined, Colors.red),
        ]);

      case BatchFilter.active:
        return row([
          _statCard('${batches.length}', 'Active Batches', Icons.check_circle_outline, Colors.green),
          _statCard('$totalRemaining', 'Total Stock', Icons.inventory_2, Colors.blue),
        ]);

      case BatchFilter.nearExpiry:
        final urgentCount = batches.where((b) => b.batch.daysUntilExpiry <= 7).length;
        return row([
          _statCard('${batches.length}', 'Near Expiry', Icons.warning_amber, Colors.orange),
          _statCard('$totalRemaining', 'Units at Risk', Icons.inventory_2, Colors.amber.shade700),
          _statCard('$urgentCount', 'Urgent (≤7d)', Icons.alarm, Colors.deepOrange),
        ]);

      case BatchFilter.expired:
        final totalExpiredUnits =
            batches.fold<int>(0, (s, b) => s + b.batch.remainingQuantity);
        return row([
          _statCard('${batches.length}', 'Expired', Icons.cancel_outlined, Colors.red),
          _statCard('$totalExpiredUnits', 'Write-off Units', Icons.delete_outline, Colors.red.shade300),
        ]);

      case BatchFilter.lowStock:
        return row([
          _statCard('${batches.length}', 'Low Stock', Icons.trending_down, Colors.purple),
          _statCard('$totalRemaining', 'Remaining Units', Icons.inventory_2, Colors.deepPurple),
        ]);
    }
  }

  Widget _statCard(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
          border: Border(
            top: BorderSide(color: color, width: 3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Batch Card ───────────────────────────────────────────────────────────────

class _BatchCard extends StatefulWidget {
  final _BatchWithItem data;
  final InventoryService inventoryService;
  final VoidCallback onUpdated;
  const _BatchCard(
      {required this.data,
      required this.inventoryService,
      required this.onUpdated});

  @override
  State<_BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends State<_BatchCard> {
  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showEditDialog() {
    final batch = widget.data.batch;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    DateTime selectedExpiry = batch.expiryDate;
    final priceController =
        TextEditingController(text: batch.purchasePrice.toStringAsFixed(2));
    final supplierController =
        TextEditingController(text: batch.supplierName ?? '');
    final invoiceController =
        TextEditingController(text: batch.supplierInvoiceNo ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: colorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.edit, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Edit Batch',
                  style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(batch.batchNumber,
                    style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 4),
                Text(widget.data.itemName,
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.4))),
                const SizedBox(height: 16),

                // Expiry date picker
                Text('Expiry Date',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedExpiry,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDState(() => selectedExpiry = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                      color: isDark
                          ? colorScheme.surfaceContainerHighest
                          : Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(_fmtDate(selectedExpiry),
                            style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Purchase price
                Text('Purchase Price (₹)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2)),
                    filled: true,
                    fillColor: isDark
                        ? colorScheme.surfaceContainerHighest
                        : Colors.grey.shade50,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Supplier name
                Text('Supplier Name',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                TextField(
                  controller: supplierController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Optional',
                    hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2)),
                    filled: true,
                    fillColor: isDark
                        ? colorScheme.surfaceContainerHighest
                        : Colors.grey.shade50,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Invoice number
                Text('Invoice No.',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                TextField(
                  controller: invoiceController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Optional',
                    hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2)),
                    filled: true,
                    fillColor: isDark
                        ? colorScheme.surfaceContainerHighest
                        : Colors.grey.shade50,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel',
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await widget.inventoryService.batchService.updateBatch(
                    widget.data.itemId,
                    batch.id,
                    expiryDate: selectedExpiry,
                    purchasePrice:
                        double.tryParse(priceController.text) ??
                            batch.purchasePrice,
                    supplierName: supplierController.text.trim().isEmpty
                        ? null
                        : supplierController.text.trim(),
                    supplierInvoiceNo: invoiceController.text.trim().isEmpty
                        ? null
                        : invoiceController.text.trim(),
                  );
                  widget.onUpdated();
                  messenger.showSnackBar(SnackBar(
                    content: const Text('Batch updated successfully'),
                    backgroundColor: colorScheme.secondary,
                    behavior: SnackBarBehavior.floating,
                  ));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: colorScheme.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.data.batch;
    final colorScheme = Theme.of(context).colorScheme;

    // Status
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (batch.isExpired) {
      statusColor = Colors.red;
      statusLabel = 'EXPIRED';
      statusIcon = Icons.cancel;
    } else if (batch.isNearExpiry) {
      statusColor = Colors.orange;
      statusLabel = 'NEAR EXPIRY';
      statusIcon = Icons.warning_amber_rounded;
    } else if (batch.remainingQuantity == 0) {
      statusColor = Colors.grey;
      statusLabel = 'SOLD OUT';
      statusIcon = Icons.remove_circle_outline;
    } else if (batch.isLowStock) {
      statusColor = Colors.purple;
      statusLabel = 'LOW STOCK';
      statusIcon = Icons.trending_down;
    } else {
      statusColor = Colors.green;
      statusLabel = 'ACTIVE';
      statusIcon = Icons.check_circle;
    }

    final usagePct = batch.quantity > 0
        ? (batch.remainingQuantity / batch.quantity).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left status strip
              Container(width: 5, color: statusColor),

              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Row 1: Item name + status badge ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.data.itemName,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A2E)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.qr_code,
                                        size: 11,
                                        color: colorScheme.primary),
                                    const SizedBox(width: 3),
                                    Text(
                                      batch.batchNumber,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon,
                                    size: 11, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Edit button
                          GestureDetector(
                            onTap: _showEditDialog,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: colorScheme.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.edit_outlined,
                                  size: 15, color: colorScheme.primary),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Row 2: Stock stats ──
                      Row(
                        children: [
                          _pill(
                            icon: Icons.inventory_2_outlined,
                            label: 'Remaining',
                            value:
                                '${batch.remainingQuantity} ${widget.data.itemUnit}',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _pill(
                            icon: Icons.all_inbox_outlined,
                            label: 'Total',
                            value: '${batch.quantity} ${widget.data.itemUnit}',
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _pill(
                            icon: Icons.currency_rupee,
                            label: 'Price/unit',
                            value:
                                '₹${batch.purchasePrice.toStringAsFixed(0)}',
                            color: Colors.indigo,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Row 3: Stock progress ──
                      Row(
                        children: [
                          Text(
                            '${(usagePct * 100).toStringAsFixed(0)}% in stock',
                            style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            '${((1 - usagePct) * 100).toStringAsFixed(0)}% sold',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: usagePct,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Divider(height: 1, color: Colors.grey.shade100),
                      const SizedBox(height: 10),

                      // ── Row 4: Dates ──
                      Row(
                        children: [
                          // Purchase date
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.shopping_cart_outlined,
                                    size: 13,
                                    color: Colors.grey.shade400),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Bought: ${_fmtDate(batch.purchaseDate)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Expiry date — prominent
                          _ExpiryChip(batch: batch),
                        ],
                      ),

                      // ── Row 5: Supplier ──
                      if (batch.supplierName != null &&
                          batch.supplierName!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.local_shipping_outlined,
                                size: 13, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${batch.supplierName}'
                                '${batch.supplierInvoiceNo != null ? '  •  Invoice: ${batch.supplierInvoiceNo}' : ''}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(fontSize: 9, color: color)),
            ]),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

}

// ── Expiry chip ───────────────────────────────────────────────────────────────

class _ExpiryChip extends StatelessWidget {
  final Batch batch;
  const _ExpiryChip({required this.batch});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String text;

    if (batch.isExpired) {
      bg = Colors.red.shade50;
      fg = Colors.red;
      text = 'Expired';
    } else if (batch.isNearExpiry) {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade800;
      text = '${batch.daysUntilExpiry}d left';
    } else {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
      text = _fmt(batch.expiryDate);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_outlined, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: fg)),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Data holder ───────────────────────────────────────────────────────────────

class _BatchWithItem {
  final Batch batch;
  final String itemName;
  final String itemUnit;
  final String itemId;

  const _BatchWithItem({
    required this.batch,
    required this.itemName,
    required this.itemUnit,
    required this.itemId,
  });
}
