import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/reports/screens/reports_dashboard_screen.dart';

class ReportsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh logic will be handled by the dashboard screen
            },
          ),
        ],
      ),
      body: const ReportsDashboardScreen(),
    );
  }
}