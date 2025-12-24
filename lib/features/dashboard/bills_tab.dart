// lib/features/dashboard/bills_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../bill/screens/bill_home_screen.dart';
import '../bill/services/bill_service.dart';

class BillsTab extends StatelessWidget {
  final String userMobile;

  const BillsTab({super.key, required this.userMobile});

  @override
  Widget build(BuildContext context) {
    return Provider<BillService>(
      create: (_) => BillService(userMobile),
      child: BillHomeScreen(userMobile: userMobile),
    );
  }
}