// lib/core/providers/app_providers.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_app/features/inventory/services/inventory_repo_service.dart';
import 'package:inventory_app/features/bill/services/bill_service.dart';
import 'package:inventory_app/features/party/services/customer_service.dart';
import 'package:inventory_app/features/party/services/supplier_service.dart';

class AppProviders extends StatelessWidget {
  final String userMobile;
  final Widget child;

  const AppProviders({
    super.key,
    required this.userMobile,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Inventory Service
        Provider<InventoryService>(
          create: (_) => InventoryService(userMobile),
        ),
        // Bill Service
        Provider<BillService>(
          create: (_) => BillService(userMobile),
        ),
        // Customer Service
        Provider<CustomerService>(
          create: (_) => CustomerService(userMobile),
        ),
        // Supplier Service
        Provider<SupplierService>(
          create: (_) => SupplierService(userMobile),
        ),
      ],
      child: child,
    );
  }
}