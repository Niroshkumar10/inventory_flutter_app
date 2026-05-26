// lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'home_tab.dart';
import 'profile_tab.dart';
import 'bills_tab.dart';
import 'reports_tab.dart';
import 'sidebar_menu.dart';
import 'package:inventory_app/features/inventory/services/expiry_alert_service.dart';
import 'package:inventory_app/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  final String userMobile;

  const DashboardScreen({
    super.key,
    required this.userMobile,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeTab(userMobile: widget.userMobile),                    // Index 0
      const Center(child: Text('Inventory - Use menu')),         // Index 1
      BillsTab(userMobile: widget.userMobile),                   // Index 2
      const Center(child: Text('Ledger - Use menu')),            // Index 3
      ReportsTab(),                                              // Index 4
      ProfileScreen(userMobile: widget.userMobile),              // Index 5 ✅ Profile
      const Center(child: Text('Settings - Coming Soon')),       // Index 6 ✅ Settings
    ];
    // Check expiry alerts after the first frame so the UI is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExpiryAlerts());
  }

  Future<void> _checkExpiryAlerts() async {
    debugPrint('[EXPIRY] _checkExpiryAlerts() started for ${widget.userMobile}');
    try {
      final summary = await ExpiryAlertService(widget.userMobile).getAlertSummary();
      final nearExpiry = (summary['nearExpiryCount'] as int? ?? 0);
      final expired   = (summary['expiredCount']    as int? ?? 0);
      debugPrint('[EXPIRY] nearExpiry=$nearExpiry expired=$expired');

      if (nearExpiry == 0 && expired == 0) {
        debugPrint('[EXPIRY] No alerts — no notification sent');
        return;
      }

      final parts = <String>[];
      if (expired > 0)    parts.add('$expired batch(es) expired');
      if (nearExpiry > 0) parts.add('$nearExpiry batch(es) expiring soon');

      debugPrint('[EXPIRY] Sending alert notification: ${parts.join(' • ')}');
      await NotificationService().showExpiryAlert(
        title: '⚠️ Inventory Expiry Alert',
        body: parts.join(' • '),
      );
    } catch (e, st) {
      debugPrint('[EXPIRY] ❌ Error: $e\n$st');
    }
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
        onItemSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _scaffoldKey.currentState?.closeDrawer();
        },
        onNavigate: (route) {
          _scaffoldKey.currentState?.closeDrawer();
          context.push(route);
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