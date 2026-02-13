// lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_tab.dart';
import 'profile_tab.dart'; // This imports your ProfileScreen
import 'bills_tab.dart';
import 'reports_tab.dart';
import 'sidebar_menu.dart'; // ✅ Fixed: Removed extra space
import '../inventory/screens/inventory_dashboard.dart';
import '../inventory/services/inventory_repo_service.dart';
import '../ledger/screens/ledger_home_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userMobile;

  const DashboardScreen({
    Key? key,
    required this.userMobile,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late InventoryService _inventoryService;
  
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _inventoryService = Provider.of<InventoryService>(context, listen: false);
    
    _screens = [
      HomeTab(userMobile: widget.userMobile),                    // Index 0
      const Center(child: Text('Inventory - Use menu')),         // Index 1
      BillsTab(userMobile: widget.userMobile),                   // Index 2
      const Center(child: Text('Ledger - Use menu')),            // Index 3
      ReportsTab(),                                              // Index 4
      ProfileScreen(userMobile: widget.userMobile),              // Index 5 ✅ Profile
      const Center(child: Text('Settings - Coming Soon')),       // Index 6 ✅ Settings
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: SidebarMenu(
        userMobile: widget.userMobile,
        selectedIndex: _selectedIndex,
        inventoryService: _inventoryService,
        onItemSelected: (index) {
          // ✅ FIXED: Allow ALL indices (0-6)
          setState(() {
            _selectedIndex = index;
          });
          Navigator.pop(context); // Close drawer
        },
      ),
      body: _screens[_selectedIndex],
    );
  }

  String _getAppBarTitle() {
    const titles = [
      'Dashboard',  // 0
      'Inventory',  // 1  
      'Bills',      // 2
      'Ledger',     // 3
      'Reports',    // 4
      'Profile',    // 5 ✅ Now shows Profile title
      'Settings',   // 6 ✅ Now shows Settings title
    ];
    return titles[_selectedIndex];
  }
}