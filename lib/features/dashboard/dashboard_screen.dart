import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'bills_tab.dart';
import 'reports_tab.dart';
import '../inventory/services/inventory_repo_service.dart'; // Add import


class DashboardScreen extends StatefulWidget {
  final String userMobile;
  final InventoryService inventoryService; // Add this

  const DashboardScreen({
    Key? key,
    required this.userMobile,
        required this.inventoryService, // Add this

  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      HomeTab(userMobile: widget.userMobile,        inventoryService: widget.inventoryService,
),
      BillsTab(userMobile: widget.userMobile),
      ReportsTab(),
      ProfileScreen(userMobile: widget.userMobile),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    
      body: _tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Bills',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
