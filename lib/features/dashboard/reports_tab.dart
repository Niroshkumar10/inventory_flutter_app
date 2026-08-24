import 'package:flutter/material.dart';
import '../../features/reports/screens/reports_dashboard_screen.dart';

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Explicit display order: Sales|Purchase, Inventory|P&L, Customer|Supplier
      // (indices 2=P&L/3=Inventory are swapped from their default array order
      // so the pairs read left-to-right the way the rest of the app expects).
      body: const ReportsDashboardScreen(allowedTabs: [0, 1, 3, 2, 4, 5]),
    );
  }
}