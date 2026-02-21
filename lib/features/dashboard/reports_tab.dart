import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/reports/screens/reports_dashboard_screen.dart';

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     
      body: const ReportsDashboardScreen(),
    );
  }
}