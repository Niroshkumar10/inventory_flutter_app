import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_app/core/navigation/app_router.dart';

class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(
          'Reports',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
        ),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a report to view',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 24),

            // Sales Report
            _ReportCard(
              title: 'Sales Report',
              subtitle: 'Invoices & Revenue',
              description:
                  'View all sales transactions, collected amounts, outstanding dues and payment status.',
              icon: Icons.trending_up_rounded,
              gradient: [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
              items: const ['Total Sales', 'Amount Collected', 'Outstanding Dues'],
              onTap: () => context.push(Routes.reportsSales),
            ),

            const SizedBox(height: 16),

            // Purchase Report
            _ReportCard(
              title: 'Purchase Report',
              subtitle: 'Supplier Bills & Costs',
              description:
                  'Track goods purchased from suppliers, payment history and pending amounts.',
              icon: Icons.trending_down_rounded,
              gradient: [const Color(0xFFE65100), const Color(0xFFFFA726)],
              items: const ['Total Purchases', 'Amount Paid', 'Pending Payments'],
              onTap: () => context.push(Routes.reportsPurchase),
            ),

            const SizedBox(height: 16),

            // Inventory Report
            _ReportCard(
              title: 'Inventory Report',
              subtitle: 'Stock & Item Status',
              description:
                  'Monitor current stock levels, low-stock alerts and total inventory value.',
              icon: Icons.inventory_2_rounded,
              gradient: [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)],
              items: const ['Total Items', 'Low Stock', 'Out of Stock'],
              onTap: () => context.push(Routes.reportsInventory),
            ),

            const SizedBox(height: 16),

            // Profit & Loss Report
            _ReportCard(
              title: 'Profit & Loss Report',
              subtitle: 'Revenue vs Cost',
              description:
                  'Analyse gross profit, net profit, total expenses and profit margin for any period.',
              icon: Icons.analytics_rounded,
              gradient: [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
              items: const ['Total Revenue', 'Total Cost', 'Net Profit'],
              onTap: () => context.push(Routes.reportsPL),
            ),

            const SizedBox(height: 16),

            // Party Report
            _ReportCard(
              title: 'Party Report',
              subtitle: 'Customers & Suppliers',
              description:
                  'Get a full breakdown of customer spending and supplier purchase history.',
              icon: Icons.people_rounded,
              gradient: [const Color(0xFF00695C), const Color(0xFF26A69A)],
              items: const ['Customer Analysis', 'Supplier Analysis'],
              onTap: () => context.push(Routes.reportsParty),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Card widget ──────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final List<String> items;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withValues(alpha: isDark ? 0.18 : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: gradient[0].withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: items.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: gradient[0].withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: gradient[0].withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: gradient[0],
                            ),
                          ),
                        );
                      }).toList(),
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
}
