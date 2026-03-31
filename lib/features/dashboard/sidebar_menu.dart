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
    super.key,
    required this.userMobile,
    required this.selectedIndex,
    required this.onItemSelected,
    this.inventoryService,
  });

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final invService = widget.inventoryService ??
        Provider.of<InventoryService>(context, listen: false);

    return Drawer(
      elevation: 0,
      backgroundColor: colorScheme.surface, // Use theme surface color
      child: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: Container(
          color: colorScheme.surface, // Use theme surface color
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
                    
                    Divider(
                      color: colorScheme.onSurface.withOpacity(0.1), // Theme-aware divider
                    ),
                    
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
                    
                    Divider(
                      color: colorScheme.onSurface.withOpacity(0.1), // Theme-aware divider
                    ),
                    
                    // Logout Menu Item
                    
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary, // Use theme primary color
            isDark ? colorScheme.primary.withOpacity(0.7) : colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(isDark ? 0.5 : 0.3),
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
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.store, 
                size: 30, 
                color: colorScheme.primary, // Use theme primary color
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory Manager',
                  style: TextStyle(
                    color: Colors.white, // Always white for contrast on gradient
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userMobile,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9), // Slightly transparent white
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7),
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
      ),
      selected: isSelected,
      selectedTileColor: colorScheme.primary.withOpacity(0.1), // Theme-aware selection color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      hoverColor: colorScheme.primary.withOpacity(0.05), // Add hover effect
      splashColor: colorScheme.primary.withOpacity(0.1),
    );
  }

  Widget _buildExpandableMenu({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Theme(
      data: theme.copyWith(
        dividerColor: Colors.transparent,
        expansionTileTheme: ExpansionTileThemeData(
          iconColor: colorScheme.onSurface.withOpacity(0.7),
          collapsedIconColor: colorScheme.onSurface.withOpacity(0.7),
          textColor: colorScheme.onSurface,
          collapsedTextColor: colorScheme.onSurface,
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.only(left: 40),
        ),
      ),
      child: ExpansionTile(
        leading: Icon(
          icon, 
          color: colorScheme.onSurface.withOpacity(0.7),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
        ),
        children: children,
      ),
    );
  }

  Widget _buildSubMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListTile(
      leading: Icon(
        icon, 
        size: 18, 
        color: colorScheme.onSurface.withOpacity(0.6),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurface.withOpacity(0.9),
        ),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      onTap: onTap,
      hoverColor: colorScheme.primary.withOpacity(0.05),
      splashColor: colorScheme.primary.withOpacity(0.1),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error, // Theme-aware error color
                foregroundColor: Colors.white,
              ),
              child: const Text('LOGOUT'),
            ),
          ],
        ),
      );

      if (shouldLogout == true) {
        await SessionServiceNew.logout();
        if (mounted) {
          Navigator.of(rootContext).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      } else {
        if (mounted) setState(() => _isLoggingOut = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}