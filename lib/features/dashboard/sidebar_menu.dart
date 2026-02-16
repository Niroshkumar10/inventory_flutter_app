// lib/features/dashboard/widgets/sidebar_menu.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../session/session_service_new.dart';
import '../inventory/screens/inventory_dashboard.dart';
import '../ledger/screens/ledger_home_screen.dart';
import '../inventory/services/inventory_repo_service.dart';
import '../../features/party/screens/customer_list_screen.dart';
import '../../features/party/screens/supplier_list_screen.dart';
import 'bills_tab.dart';
import 'reports_tab.dart';
import '../../features/dashboard/profile_tab.dart';
import '../dashboard/settings_screen.dart';

class SidebarMenu extends StatefulWidget {
  final String userMobile;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final InventoryService? inventoryService;

  const SidebarMenu({
    Key? key,
    required this.userMobile,
    required this.selectedIndex,
    required this.onItemSelected,
    this.inventoryService,
  }) : super(key: key);

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final invService = widget.inventoryService ??
        Provider.of<InventoryService>(context, listen: false);

    return Drawer(
      elevation: 0,
      child: Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildMenuItem(
                      index: 0,
                      icon: Icons.dashboard,
                      title: 'Dashboard',
                      isSelected: widget.selectedIndex == 0,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onItemSelected(0);
                      },
                    ),
                    
                    _buildExpandableMenu(
                      icon: Icons.people,
                      title: 'Parties',
                      children: [
                        _buildSubMenuItem(
                          icon: Icons.person,
                          title: 'Customers',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CustomerListScreen(
                                  userMobile: widget.userMobile,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildSubMenuItem(
                          icon: Icons.people,
                          title: 'Suppliers',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SupplierListScreen(
                                  userMobile: widget.userMobile,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    
                    _buildMenuItem(
                      index: 1,
                      icon: Icons.inventory,
                      title: 'Inventory',
                      isSelected: widget.selectedIndex == 1,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InventoryDashboard(
                              inventoryService: invService,
                              userMobile: widget.userMobile,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    _buildMenuItem(
                      index: 2,
                      icon: Icons.receipt,
                      title: 'Bills',
                      isSelected: widget.selectedIndex == 2,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BillsTab(
                              userMobile: widget.userMobile,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    _buildMenuItem(
                      index: 3,
                      icon: Icons.menu_book,
                      title: 'Ledger',
                      isSelected: widget.selectedIndex == 3,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LedgerHomeScreen(
                              userMobile: widget.userMobile,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    _buildMenuItem(
                      index: 4,
                      icon: Icons.bar_chart,
                      title: 'Reports',
                      isSelected: widget.selectedIndex == 4,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReportsTab(),
                          ),
                        );
                      },
                    ),
                    
                    const Divider(),
                    
                    // Profile Menu Item
                    _buildMenuItem(
                      index: 5,
                      icon: Icons.person,
                      title: 'Profile',
                      isSelected: widget.selectedIndex == 5,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(
                              userMobile: widget.userMobile,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Settings Menu Item
                    _buildMenuItem(
                      index: 6,
                      icon: Icons.settings,
                      title: 'Settings',
                      isSelected: widget.selectedIndex == 6,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SettingsScreen(
                              userMobile: widget.userMobile,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const Divider(),
                    
                    // Logout Menu Item
                    _buildMenuItem(
                      index: 7,
                      icon: Icons.logout,
                      title: _isLoggingOut ? 'Logging out...' : 'Logout',
                      isSelected: false,
                      onTap: _isLoggingOut ? null : _logout,
                    ),
                    
                    // Add bottom padding for better scrolling
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(Icons.store, size: 30, color: Colors.blue),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory Manager',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userMobile,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required int index,
    required IconData icon,
    required String title,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : Colors.grey[700],
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.blue.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
    );
  }

  Widget _buildExpandableMenu({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: Colors.grey[700], size: 22),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        children: children,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(left: 40),
        shape: const Border(),
        iconColor: Colors.grey[700],
        collapsedIconColor: Colors.grey[700],
      ),
    );
  }

  Widget _buildSubMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 18, color: Colors.grey[600]),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      onTap: onTap,
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    final rootContext = Navigator.of(context, rootNavigator: true).context;

    try {
      // Close drawer safely
      Navigator.of(context).pop();

      final shouldLogout = await showDialog<bool>(
        context: rootContext,
        builder: (_) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(rootContext, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(rootContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('LOGOUT'),
            ),
          ],
        ),
      );

      if (shouldLogout == true) {
        await SessionServiceNew.logout();
        Navigator.of(rootContext).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      } else {
        if (mounted) setState(() => _isLoggingOut = false);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(rootContext).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      }
    }
  }
}