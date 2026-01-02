// lib/features/dashboard/bills_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bill/screens/bill_home_screen.dart';
import '../bill/services/bill_service.dart';
import '../inventory/services/inventory_repo_service.dart'; // Add this

class BillsTab extends StatelessWidget {
  final String userMobile;

  const BillsTab({super.key, required this.userMobile});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BillService>(
          create: (_) => BillService(userMobile),
        ),
        Provider<InventoryService>(
          create: (_) => InventoryService(userMobile), // Add this
        ),
      ],
      child: BillHomeScreen(userMobile: userMobile),
    );
  }
}