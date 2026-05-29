import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ledger_service.dart';
import '../models/ledger_model.dart';
import 'package:inventory_app/core/theme/colors.dart';

class OutstandingDuesScreen extends StatefulWidget {
  final String userMobile;

  const OutstandingDuesScreen({super.key, required this.userMobile});

  @override
  State<OutstandingDuesScreen> createState() => _OutstandingDuesScreenState();
}

class _OutstandingDuesScreenState extends State<OutstandingDuesScreen> {
  late final LedgerService _ledgerService;
  late Future<List<LedgerEntry>> _future;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _date = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _ledgerService = LedgerService(widget.userMobile);
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = _ledgerService.getOutstandingDues();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        title: const Text('Outstanding Dues',
            style: TextStyle(color: Colors.white)),
        backgroundColor: cs.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<LedgerEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }

          final entries = snapshot.data ?? [];

          if (entries.isEmpty) return _emptyState(cs);

          final receivable = entries.where((e) => e.type == 'sale').toList();
          final payable = entries.where((e) => e.type == 'purchase').toList();

          final totalReceivable =
              receivable.fold<double>(0, (s, e) => s + e.amount);
          final totalPayable =
              payable.fold<double>(0, (s, e) => s + e.amount);

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            color: cs.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        label: 'To Receive',
                        amount: totalReceivable,
                        color: AppColors.success,
                        icon: Icons.arrow_downward,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        label: 'To Pay',
                        amount: totalPayable,
                        color: AppColors.error,
                        icon: Icons.arrow_upward,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (receivable.isNotEmpty) ...[
                  _sectionHeader('Money to Receive', AppColors.success, cs),
                  const SizedBox(height: 8),
                  ...receivable.map((e) => _entryCard(e, cs, isDark)),
                  const SizedBox(height: 20),
                ],
                if (payable.isNotEmpty) ...[
                  _sectionHeader('Money to Pay', AppColors.error, cs),
                  const SizedBox(height: 8),
                  ...payable.map((e) => _entryCard(e, cs, isDark)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard({
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currency.format(amount),
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color color, ColorScheme cs) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface)),
      ],
    );
  }

  Widget _entryCard(LedgerEntry entry, ColorScheme cs, bool isDark) {
    final isOverdue = entry.isOverdue;
    final daysSince = DateTime.now().difference(entry.date).inDays;
    final accentColor = isOverdue ? AppColors.error : entry.typeColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isDark ? 4 : 2,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: accentColor.withValues(alpha: 0.15),
              child: Icon(
                isOverdue ? Icons.warning_amber_rounded : entry.typeIcon,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.partyName,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(entry.description,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 11,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 3),
                      Text(_date.format(entry.date),
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.5))),
                      if (daysSince > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? AppColors.error.withValues(alpha: 0.1)
                                : AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$daysSince days ago',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  isOverdue ? AppColors.error : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currency.format(entry.amount),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: entry.type == 'sale' ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _markPaid(entry),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.4)),
                    ),
                    child: const Text('Mark Paid',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 80, color: AppColors.success.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('All Dues Cleared!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface)),
          const SizedBox(height: 8),
          Text('No pending payments from customers or to suppliers.',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5), fontSize: 14),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _markPaid(LedgerEntry entry) async {
    final cs = Theme.of(context).colorScheme;
    try {
      await _ledgerService.updateLedgerStatus(entry.id, 'paid');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${entry.partyName} marked as paid'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}
