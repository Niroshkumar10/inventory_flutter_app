// lib/features/dashboard/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';
import '../settings/settings_service.dart';
import '../settings/auto_sync_service.dart';
import '../reports/services/export_service.dart';
import 'dart:async';
class SettingsScreen extends StatefulWidget {
  final String userMobile;

  const SettingsScreen({
    super.key,
    required this.userMobile,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final ExportService _exportService = ExportService();
  final AutoSyncService _autoSyncService = AutoSyncService();
  
  bool _darkModeEnabled = false;
  bool _autoSyncEnabled = true;
  String _selectedLanguage = 'English';
  String _currencySymbol = '₹ (INR)';
  String _dateFormat = 'DD/MM/YYYY';
  
  String _lastSyncTime = 'Never';
  bool _isSyncing = false;

  bool _isLoading = false;
  bool _isSaving = false;

  // Debounce timer for auto-save
  Timer? _saveDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _setupSyncListener();
    _loadLastSyncTime();
  }

  @override
  void dispose() {
    _autoSyncService.dispose();
    _saveDebounceTimer?.cancel();
    super.dispose();
  }

  void _setupSyncListener() {
    _autoSyncService.syncStatusStream.listen((status) {
      if (!mounted) return;
      
      setState(() {
        _isSyncing = status.isStarted;
      });
      
      if (status.isCompleted) {
        setState(() {
          _lastSyncTime = status.message ?? 'Synced';
        });
        _showSuccessSnackBar(status.message ?? 'Sync completed');
      } else if (status.isFailed) {
        _showErrorSnackBar(status.message ?? 'Sync failed');
      }
    });
  }

  Future<void> _loadLastSyncTime() async {
    final lastTime = await _autoSyncService.loadLastSyncTime();
    if (lastTime != null && mounted) {
      setState(() {
        _lastSyncTime = _formatTimeAgo(lastTime);
      });
    }
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Future<void> _loadUserSettings() async {
    if (widget.userMobile.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final settings = await _settingsService.loadSettings(widget.userMobile);

      setState(() {
        _darkModeEnabled = settings['darkMode'] ?? false;
        _autoSyncEnabled = settings['autoSync'] ?? true;
        _selectedLanguage = settings['language'] ?? 'English';
        _currencySymbol = settings['currency'] ?? '₹ (INR)';
        _dateFormat = settings['dateFormat'] ?? 'DD/MM/YYYY';
      });

      // Apply theme after loading
      _applyTheme();
      
      // Start or stop auto sync based on settings
      _configureAutoSync();
      
    } catch (e) {
      _showErrorSnackBar('Error loading settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _configureAutoSync() {
    if (_autoSyncEnabled && widget.userMobile.isNotEmpty) {
      _autoSyncService.startAutoSync(widget.userMobile);
    } else {
      _autoSyncService.stopAutoSync();
    }
  }

  void _applyTheme() {
    try {
      if (mounted) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        themeProvider.toggleTheme(_darkModeEnabled);
      }
    } catch (e) {
      debugPrint('ThemeProvider not available: $e');
    }
  }

  // Auto-save function with debounce
  Future<void> _autoSaveSettings() async {
    if (widget.userMobile.isEmpty) return;

    // Cancel previous timer
    _saveDebounceTimer?.cancel();
    
    // Set new timer
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      setState(() => _isSaving = true);

      try {
        final settings = {
          'darkMode': _darkModeEnabled,
          'autoSync': _autoSyncEnabled,
          'language': _selectedLanguage,
          'currency': _currencySymbol,
          'dateFormat': _dateFormat,
        };

        await _settingsService.saveSettings(widget.userMobile, settings);

        // Apply theme after saving
        _applyTheme();
        
        // Configure auto sync based on new setting
        _configureAutoSync();

        if (mounted) {
          // Optional: Show a subtle indicator that settings were saved
          // You can uncomment this if you want visual feedback
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: const Text('Settings saved'),
          //     backgroundColor: Theme.of(context).colorScheme.secondary,
          //     duration: const Duration(seconds: 1),
          //     behavior: SnackBarBehavior.floating,
          //   ),
          // );
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Error saving settings: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    });
  }

  Future<void> _syncNow() async {
    if (widget.userMobile.isEmpty) return;
    
    setState(() => _isSyncing = true);
    
    try {
      _autoSyncService.startAutoSync(widget.userMobile);
    } catch (e) {
      _showErrorSnackBar('Manual sync failed: $e');
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _clearCache() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(
          'Clear Cache',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to clear all cached data? This will not delete your saved data.',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.tertiary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        await _settingsService.clearLocalCache();
        _showSuccessSnackBar('Cache cleared successfully');
      } catch (e) {
        _showErrorSnackBar('Error clearing cache: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _backupData() async {
    setState(() => _isLoading = true);

    try {
      final backupData = await _fetchBackupData();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userMobile)
          .collection('backups')
          .doc(DateTime.now().millisecondsSinceEpoch.toString())
          .set({
        'timestamp': FieldValue.serverTimestamp(),
        'data': backupData,
      });

      _showSuccessSnackBar('Backup created successfully');
    } catch (e) {
      _showErrorSnackBar('Error creating backup: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchBackupData() async {
    try {
      final inventorySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userMobile)
          .collection('inventory')
          .get();

      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userMobile)
          .collection('transactions')
          .get();

      final settingsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userMobile)
          .collection('settings')
          .doc('preferences')
          .get();

      return {
        'inventory': inventorySnapshot.docs.map((doc) => doc.data()).toList(),
        'transactions':
            transactionsSnapshot.docs.map((doc) => doc.data()).toList(),
        'settings': settingsDoc.data() ?? {},
        'backupDate': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error fetching backup data: $e');
      return {'error': 'Failed to fetch data for backup'};
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.background : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        // REMOVED: Save button from actions - now auto-save
        actions: [
          // Optional: Show saving indicator
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _buildSettingsContent(isSmallScreen),
    );
  }

  Widget _buildSettingsContent(bool isSmallScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.userMobile.isEmpty) {
      return _buildLoginPrompt(isSmallScreen);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        children: [
          // App Preferences Section
          _buildSettingsSection(
            icon: Icons.settings,
            title: 'App Preferences',
            children: [
              _buildDivider(isSmallScreen),
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Switch to dark theme',
                value: _darkModeEnabled,
                onChanged: (value) {
                  setState(() => _darkModeEnabled = value);
                  _applyTheme(); // Apply immediately
                  _autoSaveSettings(); // Auto-save
                },
              ),
              _buildDivider(isSmallScreen),
              _buildSwitchTile(
                icon: Icons.sync_outlined,
                title: 'Auto Sync',
                subtitle: 'Automatically sync data with cloud',
                value: _autoSyncEnabled,
                onChanged: (value) {
                  setState(() => _autoSyncEnabled = value);
                  _autoSaveSettings(); // Auto-save
                },
              ),
              if (_autoSyncEnabled) ...[
                _buildDivider(isSmallScreen),
                _buildSyncStatusTile(isSmallScreen),
              ],
              
            ],
          ),

          SizedBox(height: isSmallScreen ? 16 : 20),

          // Data Management Section
          _buildSettingsSection(
            icon: Icons.storage_outlined,
            title: 'Data Management',
            children: [
              _buildActionTile(
                icon: Icons.delete_sweep_outlined,
                iconColor: colorScheme.tertiary,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                onTap: _clearCache,
              ),
              _buildDivider(isSmallScreen),
              _buildActionTile(
                icon: Icons.backup_outlined,
                iconColor: colorScheme.secondary,
                title: 'Backup Data',
                subtitle: 'Create a backup of your data',
                onTap: _backupData,
              ),
            ],
          ),

          SizedBox(height: isSmallScreen ? 16 : 20),

          // About Section
          _buildSettingsSection(
            icon: Icons.info_outline,
            title: 'About',
            children: [
              _buildInfoTile(
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: '1.0.0+1',
              ),
              _buildDivider(isSmallScreen),
              _buildActionTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: Colors.purple,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                onTap: () => _showComingSoon('Privacy Policy'),
              ),
              _buildDivider(isSmallScreen),
              _buildActionTile(
                icon: Icons.description_outlined,
                iconColor: Colors.teal,
                title: 'Terms of Service',
                subtitle: 'Read our terms of service',
                onTap: () => _showComingSoon('Terms of Service'),
              ),
              _buildDivider(isSmallScreen),
              _buildInfoTile(
                icon: Icons.copyright_outlined,
                title: 'Copyright',
                subtitle: '© 2026 Inventory Manager',
              ),
            ],
          ),

          SizedBox(height: isSmallScreen ? 24 : 32),

          // Footer
          Text(
            'Inventory Manager v1.0.0',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Made with ❤️ in India',
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
        ],
      ),
    );
  }

  Widget _buildSyncStatusTile(bool isSmallScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
        vertical: 8,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _isSyncing 
                  ? colorScheme.tertiary.withOpacity(0.1)
                  : colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isSyncing ? Icons.sync : Icons.sync_problem_outlined,
              color: _isSyncing ? colorScheme.tertiary : colorScheme.secondary,
              size: isSmallScreen ? 20 : 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSyncing ? 'Syncing...' : 'Sync Status',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 15,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isSyncing ? 'Please wait...' : 'Last sync: $_lastSyncTime',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (!_isSyncing)
            ElevatedButton(
              onPressed: _syncNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('SYNC NOW'),
            ),
          if (_isSyncing)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: isSmallScreen ? 20 : 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 13,
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 12,
          vertical: isSmallScreen ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHighest : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: value,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 14,
                  color: colorScheme.onSurface,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          underline: const SizedBox(),
          icon: Icon(
            Icons.arrow_drop_down,
            color: colorScheme.primary,
            size: isSmallScreen ? 22 : 24,
          ),
          dropdownColor: isDark ? colorScheme.surface : Colors.white,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
      ),
    );
  }

  Widget _buildSettingsSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isSmallScreen ? 16 : 20,
              isSmallScreen ? 16 : 20,
              isSmallScreen ? 16 : 20,
              isSmallScreen ? 8 : 10,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: colorScheme.primary,
                    size: isSmallScreen ? 20 : 22,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 10 : 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: isSmallScreen ? 20 : 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 13,
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: colorScheme.primary,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: isSmallScreen ? 20 : 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 13,
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: isSmallScreen ? 14 : 16,
        color: colorScheme.onSurface.withOpacity(0.4),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: isSmallScreen ? 20 : 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 13,
          color: colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
      ),
    );
  }

  Widget _buildDivider(bool isSmallScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
      ),
      child: Divider(
        height: 1,
        color: colorScheme.outline,
      ),
    );
  }

  Widget _buildLoginPrompt(bool isSmallScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.settings,
                size: isSmallScreen ? 60 : 70,
                color: colorScheme.primary.withOpacity(0.5),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            Text(
              'Please Login',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 10),
            Text(
              'You need to login to access settings',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 15,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 24 : 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              },
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text(
                'Go to Login',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 24 : 30,
                  vertical: isSmallScreen ? 12 : 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    final theme = Theme.of(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }
}