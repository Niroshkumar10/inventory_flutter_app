// lib/features/bill/screens/bill_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/bill_service.dart';
import '../models/bill_model.dart';
import 'add_edit_bill_screen.dart';
import 'view_bill_screen.dart';
import '../../inventory/services/inventory_repo_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../analytics/services/analytics_service.dart';

class BillHomeScreen extends StatefulWidget {
  final String userMobile;

  const BillHomeScreen({super.key, required this.userMobile});

  @override
  State<BillHomeScreen> createState() => _BillHomeScreenState();
}

class _BillHomeScreenState extends State<BillHomeScreen>
    with SingleTickerProviderStateMixin {
  String _currentFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOutBack),
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

 @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;

  return Scaffold(
    backgroundColor: isDark ? colorScheme.background : const Color(0xffF8F9FC),
    appBar: _buildAppBar(context, colorScheme),
    body: CustomScrollView(
      slivers: [
        // Fixed Summary Section (doesn't scroll)
        SliverToBoxAdapter(
          child: _buildSummarySection(context, colorScheme),
        ),
        
        // Scrollable content
        SliverList(
          delegate: SliverChildListDelegate([
            // Analytics Section
            _buildAnalyticsSection(context, colorScheme),
            
            // Filter Tabs
            _buildFilterTabs(context, colorScheme),
            
            // Transactions List - now as a separate widget
            _buildTransactionsList(context, colorScheme),
          ]),
        ),
      ],
    ),
    floatingActionButton: ScaleTransition(
      scale: _fabScaleAnimation,
      child: FloatingActionButton.extended(
        onPressed: () {
          _handleFabAction();
        },
        icon: Icon(_getFabIcon(), color: Colors.white, size: 20),
        label: Text(
          _getFabLabel(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        backgroundColor: _getFabColor(context),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    ),
  );
}
  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme colorScheme) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bills & Transactions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          Text(
            'Manage all your financial records',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colorScheme.onSurface, size: 18),
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            shape: const CircleBorder(),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: colorScheme.onSurface),
          onPressed: () {
            showSearch(
              context: context,
              delegate: _BillSearchDelegate(
                userMobile: widget.userMobile,
              ),
            );
          },
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            shape: const CircleBorder(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.refresh, color: colorScheme.onSurface),
          onPressed: () {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Refreshed successfully'),
                backgroundColor: colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            shape: const CircleBorder(),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ==================== SUMMARY SECTION ====================
  Widget _buildSummarySection(BuildContext context, ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: StreamBuilder<BillSummary>(
        stream: Provider.of<BillService>(context, listen: false).getBillSummary(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: SizedBox(
                height: 120,
                child: Center(
                  child: CircularProgressIndicator(
                    color: colorScheme.primary,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            );
          }

          final summary = snapshot.data!;
          return Column(
            children: [
              // Welcome Row with animated gradient
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateRange(),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.15),
                          colorScheme.primary.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Summary Cards Row
              Row(
                children: [
                  Expanded(
                    child: _buildAnimatedSummaryCard(
                      title: 'Total Sales',
                      amount: summary.totalSales,
                      icon: Icons.trending_up,
                      color: colorScheme.secondary,
                      prefix: '₹',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildAnimatedSummaryCard(
                      title: 'Total Purchases',
                      amount: summary.totalPurchases,
                      icon: Icons.trending_down,
                      color: colorScheme.tertiary,
                      prefix: '₹',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Due Card with shimmer effect
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.error.withOpacity(0.12),
                        colorScheme.error.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.error.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.error.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: colorScheme.error,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Outstanding Amount',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₹${NumberFormat('#,##0.00').format(summary.totalDue)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.error,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.error.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${summary.dueCount} pending',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnimatedSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required String prefix,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: amount),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.12),
                color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$prefix${NumberFormat('#,##0.00').format(value)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== ANALYTICS SECTION ====================
  Widget _buildAnalyticsSection(BuildContext context, ColorScheme colorScheme) {
    return StreamBuilder<List<Bill>>(
      stream: Provider.of<BillService>(context, listen: false).getBills(filter: 'all'),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final bills = snapshot.data!;
        final analytics = AnalyticsService();
        final topSelling = analytics.getTopSelling(bills);
        final topPurchase = analytics.getTopPurchase(bills);

        if (topSelling.isEmpty && topPurchase.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.insights,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Analytics Insights',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (topSelling.isNotEmpty) ...[
                _buildAnalyticsItem(
                  title: 'Top Selling Items',
                  icon: Icons.trending_up,
                  color: Colors.green,
                  items: topSelling.take(3).map((e) => _AnalyticsItem(
                    name: e.key,
                    value: e.value,
                    unit: 'sold',
                    suggestion: analytics.getSuggestion(e.value),
                  )).toList(),
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 20),
              ],
              if (topPurchase.isNotEmpty) ...[
                _buildAnalyticsItem(
                  title: 'Top Purchased Items',
                  icon: Icons.inventory_2,
                  color: Colors.blue,
                  items: topPurchase.take(3).map((e) => _AnalyticsItem(
                    name: e.key,
                    value: e.value,
                    unit: 'bought',
                    suggestion: null,
                  )).toList(),
                  colorScheme: colorScheme,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsItem({
    required String title,
    required IconData icon,
    required Color color,
    required List<_AnalyticsItem> items,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.value} ${item.unit}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (item.suggestion != null)
                      Text(
                        item.suggestion!,
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  // ==================== FILTER TABS ====================
// ==================== FILTER TABS ====================
Widget _buildFilterTabs(BuildContext context, ColorScheme colorScheme) {
  final filters = [
    {'label': 'All', 'value': 'all', 'color': colorScheme.primary},
    {'label': 'Sales', 'value': 'sales', 'color': colorScheme.secondary},
    {'label': 'Purchases', 'value': 'purchase', 'color': colorScheme.tertiary},
    {'label': 'Due', 'value': 'due', 'color': colorScheme.error},
  ];

  return Container(
    color: colorScheme.surface,
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.filter_list,
              size: 16,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              'Filter by type',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withOpacity(0.6),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              final isActive = _currentFilter == filter['value'];
              final color = filter['color'] as Color;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildFilterChip(
                  filter['label'] as String,  // Add type cast
                  filter['value'] as String,  // Add type cast
                  color,
                  isActive,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );
}
  Widget _buildFilterChip(String label, String value, Color color, bool isActive) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
            color: isActive ? color : colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        selected: isActive,
        onSelected: (selected) {
          setState(() {
            _currentFilter = value;
          });
        },
        backgroundColor: colorScheme.surface,
        selectedColor: color.withOpacity(0.12),
        checkmarkColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        side: isActive
            ? BorderSide(color: color, width: 1.5)
            : BorderSide(color: colorScheme.outline.withOpacity(0.5), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  // ==================== TRANSACTIONS LIST ====================
// ==================== TRANSACTIONS LIST ====================
Widget _buildTransactionsList(BuildContext context, ColorScheme colorScheme) {
  return StreamBuilder<List<Bill>>(
    stream: Provider.of<BillService>(context, listen: false)
        .getBills(filter: _currentFilter),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Container(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: CircularProgressIndicator(
              color: _getFilterColor(context),
              strokeWidth: 2.5,
            ),
          ),
        );
      }

      if (snapshot.hasError) {
        return Container(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  'Error loading transactions',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      final bills = snapshot.data ?? [];

      if (bills.isEmpty) {
        return _buildEmptyState(context, colorScheme);
      }

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.receipt,
                  size: 14,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  '${bills.length} transactions',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,  // Important for nested scrolling
            physics: const NeverScrollableScrollPhysics(),  // Disable inner scrolling
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              return _buildTransactionCard(bill, context, colorScheme, index);
            },
          ),
        ],
      );
    },
  );
}
Widget _buildTransactionCard(Bill bill, BuildContext context, ColorScheme colorScheme, int index) {
  final isSales = bill.type == 'sales';
  Color statusColor;
  String statusText;
  IconData statusIcon;

  if (bill.amountDue == 0) {
    statusColor = colorScheme.secondary;
    statusText = 'Paid';
    statusIcon = Icons.check_circle;
  } else if (bill.amountPaid > 0) {
    statusColor = colorScheme.primary;
    statusText = 'Partial';
    statusIcon = Icons.hourglass_empty;
  } else {
    statusColor = colorScheme.error;
    statusText = 'Due';
    statusIcon = Icons.pending;
  }

  return TweenAnimationBuilder(
    tween: Tween<double>(begin: 0, end: 1),
    duration: Duration(milliseconds: 300 + (index * 50)),
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      );
    },
    child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewBillScreen(
                billId: bill.id,
                userMobile: widget.userMobile,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon with gradient
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSales
                        ? [colorScheme.secondary, colorScheme.secondary.withOpacity(0.7)]
                        : [colorScheme.tertiary, colorScheme.tertiary.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    isSales ? Icons.shopping_bag : Icons.inventory_2,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Bill Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            bill.invoiceNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusIcon,
                                size: 12,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bill.partyName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(bill.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSales
                                ? colorScheme.secondary.withOpacity(0.08)
                                : colorScheme.tertiary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₹${NumberFormat('#,##0').format(bill.totalAmount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isSales ? colorScheme.secondary : colorScheme.tertiary,
                              fontSize: 14,
                            ),
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
    ),
  );
}
  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    IconData icon;
    String title;
    String subtitle;
    Color color;

    switch (_currentFilter) {
      case 'sales':
        icon = Icons.shopping_cart_outlined;
        title = 'No Sales Found';
        subtitle = 'Start by creating your first sales entry';
        color = colorScheme.secondary;
        break;
      case 'purchase':
        icon = Icons.inventory_2_outlined;
        title = 'No Purchases Found';
        subtitle = 'Start by creating your first purchase entry';
        color = colorScheme.tertiary;
        break;
      case 'due':
        icon = Icons.celebration;
        title = 'All Clear!';
        subtitle = 'No outstanding payments to track';
        color = colorScheme.error;
        break;
      default:
        icon = Icons.receipt_outlined;
        title = 'No Transactions Yet';
        subtitle = 'Create your first sales or purchase transaction';
        color = colorScheme.primary;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.15),
                    color.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 72,
                color: color.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _handleFabAction();
              },
              icon: Icon(_getFabIcon(), color: Colors.white, size: 18),
              label: Text(
                _getFabLabel(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getFabColor(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPER METHODS ====================
  IconData _getFabIcon() {
    switch (_currentFilter) {
      case 'sales':
        return Icons.add_shopping_cart;
      case 'purchase':
        return Icons.add_business;
      default:
        return Icons.add;
    }
  }

  String _getFabLabel() {
    switch (_currentFilter) {
      case 'sales':
        return 'Add Sale';
      case 'purchase':
        return 'Add Purchase';
      default:
        return 'New Transaction';
    }
  }

  Color _getFabColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (_currentFilter) {
      case 'sales':
        return colorScheme.secondary;
      case 'purchase':
        return colorScheme.tertiary;
      default:
        return colorScheme.primary;
    }
  }

  Color _getFilterColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (_currentFilter) {
      case 'sales':
        return colorScheme.secondary;
      case 'purchase':
        return colorScheme.tertiary;
      case 'due':
        return colorScheme.error;
      default:
        return colorScheme.primary;
    }
  }

  void _handleFabAction() {
    if (_currentFilter == 'sales') {
      _navigateToAddBill('sales');
    } else if (_currentFilter == 'purchase') {
      _navigateToAddBill('purchase');
    } else {
      _showAddBillDialog(context);
    }
  }

  void _showAddBillDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Create New Transaction',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose the type of transaction you want to create',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildDialogOption(
                  context: context,
                  icon: Icons.shopping_cart,
                  title: 'Sales Entry',
                  subtitle: 'Record a sale to customer',
                  color: colorScheme.secondary,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToAddBill('sales');
                  },
                ),
                const SizedBox(height: 12),
                _buildDialogOption(
                  context: context,
                  icon: Icons.inventory,
                  title: 'Purchase Entry',
                  subtitle: 'Record a purchase from supplier',
                  color: colorScheme.tertiary,
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToAddBill('purchase');
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(color: colorScheme.outline),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  void _navigateToAddBill(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppProviders(
          userMobile: widget.userMobile,
          child: AddEditBillScreen(
            type: type,
            userMobile: widget.userMobile,
            billService: BillService(widget.userMobile),
          ),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  String _formatDateRange() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    return '${DateFormat('dd MMM').format(startOfMonth)} - ${DateFormat('dd MMM yyyy').format(now)}';
  }
}

// Helper class for analytics items
class _AnalyticsItem {
  final String name;
  final double value;
  final String unit;
  final String? suggestion;

  _AnalyticsItem({
    required this.name,
    required this.value,
    required this.unit,
    this.suggestion,
  });
}

// Search Delegate
class _BillSearchDelegate extends SearchDelegate {
  final String userMobile;
  late final BillService _billService;

  _BillSearchDelegate({required this.userMobile}) {
    _billService = BillService(userMobile);
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          fontSize: 16,
        ),
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    final theme = Theme.of(context);
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: Icon(Icons.clear, color: theme.colorScheme.onSurface),
          onPressed: () {
            query = '';
            showSuggestions(context);
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

    return StreamBuilder<List<Bill>>(
      stream: _billService.searchBills(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: colorScheme.primary,
              strokeWidth: 2.5,
            ),
          );
        }

        final bills = snapshot.data ?? [];

        if (bills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  query.isEmpty ? Icons.search : Icons.search_off,
                  size: 64,
                  color: colorScheme.onSurface.withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  query.isEmpty ? 'Search transactions...' : 'No results found',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                if (query.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Try a different keyword',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return Container(
          color: colorScheme.background,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              final isSales = bill.type == 'sales';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: colorScheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isSales ? colorScheme.secondary : colorScheme.tertiary)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isSales ? Icons.shopping_bag : Icons.inventory_2,
                      color: isSales ? colorScheme.secondary : colorScheme.tertiary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    bill.invoiceNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '${bill.partyName} • ${bill.type == 'sales' ? 'Sale' : 'Purchase'}',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isSales ? colorScheme.secondary : colorScheme.tertiary)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₹${NumberFormat('#,##0').format(bill.totalAmount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSales ? colorScheme.secondary : colorScheme.tertiary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  onTap: () {
                    close(context, null);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewBillScreen(
                          billId: bill.id,
                          userMobile: userMobile,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  String get searchFieldLabel => 'Search by invoice, party name...';
}