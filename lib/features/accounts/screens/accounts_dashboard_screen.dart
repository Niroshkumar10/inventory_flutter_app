import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_app/core/navigation/app_router.dart';

class AccountsDashboardScreen extends StatelessWidget {
  final String userMobile;
  const AccountsDashboardScreen({super.key, required this.userMobile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: Text(
          'Accounts',
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
            // Header
            Text(
              'Manage your finances',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 28),

            // 1 — Transactions card
            _AccountCard(
              title: 'Transactions',
              subtitle: 'Sales & Purchases',
              description: 'Record goods sold to customers and bought from suppliers.',
              icon: Icons.swap_horiz_rounded,
              gradient: [const Color(0xFF1976D2), const Color(0xFF42A5F5)],
              items: const [
                _CardItem(icon: Icons.trending_up, label: 'Sold to Customer'),
                _CardItem(icon: Icons.trending_down, label: 'Bought from Supplier'),
              ],
              onTap: () => context.push(Routes.bills),
            ),

            const SizedBox(height: 16),

            // 2 — Borrows card
            _AccountCard(
              title: 'Borrows',
              subtitle: 'Dues & Receivables',
              description: 'Track money owed by customers and amounts you owe suppliers.',
              icon: Icons.handshake_outlined,
              gradient: [const Color(0xFFE65100), const Color(0xFFFFA726)],
              items: const [
                _CardItem(icon: Icons.arrow_circle_down_outlined, label: 'Customer Paid Me'),
                _CardItem(icon: Icons.arrow_circle_up_outlined, label: 'I Paid Supplier'),
              ],
              onTap: () => context.push(Routes.ledger),
            ),

            const SizedBox(height: 16),

            // 3 — Cash Book card
            _AccountCard(
              title: 'Cash Book',
              subtitle: 'Income & Expense',
              description: 'Record daily cash inflows and outflows to track your net balance.',
              icon: Icons.menu_book_outlined,
              gradient: [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
              items: const [
                _CardItem(icon: Icons.add_circle_outline, label: 'Income'),
                _CardItem(icon: Icons.remove_circle_outline, label: 'Expense'),
              ],
              onTap: () => context.push(Routes.cashBook),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Card widget ─────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final List<_CardItem> items;
  final VoidCallback onTap;

  const _AccountCard({
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
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coloured header band
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: items.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: gradient[0].withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: gradient[0].withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item.icon, size: 14, color: gradient[0]),
                              const SizedBox(width: 6),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: gradient[0],
                                ),
                              ),
                            ],
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

class _CardItem {
  final IconData icon;
  final String label;
  const _CardItem({required this.icon, required this.label});
}
