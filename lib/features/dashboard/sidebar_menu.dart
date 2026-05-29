// lib/features/dashboard/widgets/sidebar_menu.dart
import 'package:flutter/material.dart';
import 'package:inventory_app/core/navigation/app_router.dart';

class SidebarMenu extends StatefulWidget {
  final String userMobile;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final void Function(String route) onNavigate;
  final VoidCallback onLogout;

  const SidebarMenu({
    super.key,
    required this.userMobile,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onNavigate,
    required this.onLogout,
  });

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      elevation: 0,
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        top: true,
        bottom: false,
        left: false,
        right: false,
        child: Container(
          color: colorScheme.surface,
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
                    ),

                    _buildExpandableMenu(
                      icon: Icons.people,
                      title: 'Parties',
                      children: [
                        _buildSubMenuItem(
                          icon: Icons.person,
                          title: 'Customers',
                          onTap: () => widget.onNavigate(Routes.customers),
                        ),
                        _buildSubMenuItem(
                          icon: Icons.people,
                          title: 'Suppliers',
                          onTap: () => widget.onNavigate(Routes.suppliers),
                        ),
                      ],
                    ),

                    // ── Inventory (expandable with Batches submenu) ──────────
                    _buildExpandableMenu(
                      icon: Icons.inventory,
                      title: 'Inventory',
                      isSelectedGroup: widget.selectedIndex == 1,
                      children: [
                        _buildSubMenuItem(
                          icon: Icons.list_alt,
                          title: 'All Items',
                          onTap: () => widget.onNavigate(Routes.inventory),
                        ),
                        _buildSubMenuItem(
                          icon: Icons.layers,
                          title: 'Batches',
                          onTap: () => widget.onNavigate(Routes.batches),
                          badge: const _BatchAlertBadge(),
                        ),
                      ],
                    ),
                    // ────────────────────────────────────────────────────────

                    _buildMenuItem(
                      index: 2,
                      icon: Icons.receipt,
                      title: 'Bills',
                      isSelected: widget.selectedIndex == 2,
                      onTap: () => widget.onNavigate(Routes.bills),
                    ),

                    _buildMenuItem(
                      index: 3,
                      icon: Icons.menu_book,
                      title: 'Accounts',
                      isSelected: widget.selectedIndex == 3,
                      onTap: () => widget.onNavigate(Routes.ledger),
                    ),

                    _buildMenuItem(
                      index: 4,
                      icon: Icons.bar_chart,
                      title: 'Reports',
                      isSelected: widget.selectedIndex == 4,
                      onTap: () => widget.onNavigate(Routes.reports),
                    ),

                    Divider(color: colorScheme.onSurface.withValues(alpha:0.1)),

                    _buildMenuItem(
                      index: 7,
                      icon: Icons.feedback_outlined,
                      title: 'Feedback',
                      isSelected: false,
                      onTap: () => widget.onNavigate(Routes.feedback),
                    ),

                    _buildMenuItem(
                      index: 5,
                      icon: Icons.person,
                      title: 'Profile',
                      isSelected: widget.selectedIndex == 5,
                      onTap: () => widget.onNavigate(Routes.profile),
                    ),

                    _buildMenuItem(
                      index: 6,
                      icon: Icons.settings,
                      title: 'Settings',
                      isSelected: widget.selectedIndex == 6,
                      onTap: () => widget.onNavigate(Routes.settings),
                    ),

                    Divider(color: colorScheme.onSurface.withValues(alpha: 0.1)),

                    // ── Logout ──────────────────────────────────────────
                    ListTile(
                      leading: Icon(Icons.logout,
                          color: colorScheme.error, size: 22),
                      title: Text('Logout',
                          style: TextStyle(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      onTap: widget.onLogout,
                    ),

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
            colorScheme.primary,
            isDark
                ? colorScheme.primary.withValues(alpha:0.7)
                : colorScheme.primary.withValues(alpha:0.8),
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
            color: colorScheme.shadow.withValues(alpha:isDark ? 0.5 : 0.3),
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
              child: Icon(Icons.store, size: 30, color: colorScheme.primary),
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
                  style: TextStyle(
                    color: Colors.white.withValues(alpha:0.9),
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
        color: isSelected
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(alpha:0.7),
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
      selectedTileColor: colorScheme.primary.withValues(alpha:0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      hoverColor: colorScheme.primary.withValues(alpha:0.05),
      splashColor: colorScheme.primary.withValues(alpha:0.1),
    );
  }

  Widget _buildExpandableMenu({
    required IconData icon,
    required String title,
    required List<Widget> children,
    bool isSelectedGroup = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Theme(
      data: theme.copyWith(
        dividerColor: Colors.transparent,
        expansionTileTheme: ExpansionTileThemeData(
          iconColor: isSelectedGroup
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha:0.7),
          collapsedIconColor: isSelectedGroup
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha:0.7),
          textColor:
              isSelectedGroup ? colorScheme.primary : colorScheme.onSurface,
          collapsedTextColor:
              isSelectedGroup ? colorScheme.primary : colorScheme.onSurface,
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: isSelectedGroup
              ? colorScheme.primary.withValues(alpha:0.05)
              : Colors.transparent,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.only(left: 40),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: isSelectedGroup,
        leading: Icon(
          icon,
          color: isSelectedGroup
              ? colorScheme.primary
              : colorScheme.onSurface.withValues(alpha:0.7),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelectedGroup ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
            color:
                isSelectedGroup ? colorScheme.primary : colorScheme.onSurface,
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
    Widget? badge,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading:
          Icon(icon, size: 18, color: colorScheme.onSurface.withValues(alpha:0.6)),
      title: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha:0.9),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            badge,
          ],
        ],
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      onTap: onTap,
      hoverColor: colorScheme.primary.withValues(alpha:0.05),
      splashColor: colorScheme.primary.withValues(alpha:0.1),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Orange dot badge — wire to a real stream/provider to hide when all is well.
// ─────────────────────────────────────────────────────────────────────────────
class _BatchAlertBadge extends StatelessWidget {
  const _BatchAlertBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.orange,
        shape: BoxShape.circle,
      ),
    );
  }
}