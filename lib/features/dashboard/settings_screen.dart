// lib/features/dashboard/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../session/session_service_new.dart';
import '../../core/theme/app_theme.dart';
import '../inventory/services/inventory_repo_service.dart';
class SettingsScreen extends StatefulWidget {
  final String userMobile;
  
  const SettingsScreen({
    Key? key,
    required this.userMobile,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoSyncEnabled = true;
  bool _biometricEnabled = false;
  String _selectedLanguage = 'English';
  String _currencySymbol = '₹ (INR)';
  String _dateFormat = 'DD/MM/YYYY';
  
  final List<String> _languages = ['English', 'Hindi', 'Gujarati', 'Marathi', 'Tamil'];
  final List<String> _currencies = ['₹ (INR)', '\$ (USD)', '€ (EUR)', '£ (GBP)'];
  final List<String> _dateFormats = ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'];
  
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    if (widget.userMobile.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userMobile)
          .collection('settings')
          .doc('preferences')
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _notificationsEnabled = data['notifications'] ?? true;
          _darkModeEnabled = data['darkMode'] ?? false;
          _autoSyncEnabled = data['autoSync'] ?? true;
          _biometricEnabled = data['biometric'] ?? false;
          _selectedLanguage = data['language'] ?? 'English';
          _currencySymbol = data['currency'] ?? '₹ (INR)';
          _dateFormat = data['dateFormat'] ?? 'DD/MM/YYYY';
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (widget.userMobile.isEmpty) return;
    
    setState(() => _isSaving = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userMobile)
          .collection('settings')
          .doc('preferences')
          .set({
            'notifications': _notificationsEnabled,
            'darkMode': _darkModeEnabled,
            'autoSync': _autoSyncEnabled,
            'biometric': _biometricEnabled,
            'language': _selectedLanguage,
            'currency': _currencySymbol,
            'dateFormat': _dateFormat,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _clearCache() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear all cached data? This will not delete your saved data.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Simulate cache clearing
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preparing your data for export...'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // Simulate export
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data exported successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, size: 20),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSettingsContent(isSmallScreen, isDarkMode),
    );
  }

  Widget _buildSettingsContent(bool isSmallScreen, bool isDarkMode) {
    if (widget.userMobile.isEmpty) {
      return _buildLoginPrompt(isSmallScreen);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        children: [
          // App Preferences Section - FIXED ICON
          _buildSettingsSection(
            icon: Icons.settings_applications, // Changed from app_settings
            title: 'App Preferences',
            children: [
              _buildSwitchTile(
                icon: Icons.notifications,
                title: 'Push Notifications',
                subtitle: 'Receive alerts for bills and inventory',
                value: _notificationsEnabled,
                onChanged: (value) => setState(() => _notificationsEnabled = value),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                subtitle: 'Switch to dark theme',
                value: _darkModeEnabled,
                onChanged: (value) => setState(() => _darkModeEnabled = value),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.sync,
                title: 'Auto Sync',
                subtitle: 'Automatically sync data with cloud',
                value: _autoSyncEnabled,
                onChanged: (value) => setState(() => _autoSyncEnabled = value),
              ),
              _buildDivider(),
              _buildSwitchTile(
                icon: Icons.fingerprint,
                title: 'Biometric Login',
                subtitle: 'Use fingerprint/face to unlock',
                value: _biometricEnabled,
                onChanged: (value) => setState(() => _biometricEnabled = value),
              ),
            ],
          ),

          SizedBox(height: isSmallScreen ? 16 : 20),

          // Regional Settings Section
          _buildSettingsSection(
            icon: Icons.public, // Changed from language to public
            title: 'Regional Settings',
            children: [
              _buildDropdownTile(
                icon: Icons.language,
                title: 'Language',
                value: _selectedLanguage,
                items: _languages,
                onChanged: (value) => setState(() => _selectedLanguage = value!),
              ),
              _buildDivider(),
              _buildDropdownTile(
                icon: Icons.attach_money, // Changed from currency_rupee
                title: 'Currency',
                value: _currencySymbol,
                items: _currencies,
                onChanged: (value) => setState(() => _currencySymbol = value!),
              ),
              _buildDivider(),
              _buildDropdownTile(
                icon: Icons.calendar_today,
                title: 'Date Format',
                value: _dateFormat,
                items: _dateFormats,
                onChanged: (value) => setState(() => _dateFormat = value!),
              ),
            ],
          ),

          SizedBox(height: isSmallScreen ? 16 : 20),

          // Data Management Section
          _buildSettingsSection(
            icon: Icons.storage, // Changed from data_usage
            title: 'Data Management',
            children: [
              _buildActionTile(
                icon: Icons.delete_sweep,
                iconColor: Colors.orange,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                onTap: _clearCache,
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.download,
                iconColor: Colors.blue,
                title: 'Export Data',
                subtitle: 'Download your data as CSV',
                onTap: _exportData,
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.backup,
                iconColor: Colors.green,
                title: 'Backup Data',
                subtitle: 'Create a backup of your data',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backup feature coming soon!'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
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
              _buildDivider(),
              _buildActionTile(
                icon: Icons.privacy_tip,
                iconColor: Colors.purple,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Privacy policy coming soon!'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildDivider(),
              _buildActionTile(
                icon: Icons.description,
                iconColor: Colors.teal,
                title: 'Terms of Service',
                subtitle: 'Read our terms of service',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Terms of service coming soon!'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              _buildDivider(),
              _buildInfoTile(
                icon: Icons.copyright,
                title: 'Copyright',
                subtitle: '© 2024 Inventory Manager',
              ),
            ],
          ),

          SizedBox(height: isSmallScreen ? 24 : 32),

          // Footer
          Text(
            'Inventory Manager v1.0.0',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Made with ❤️ in India',
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
                Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                  size: isSmallScreen ? 22 : 24,
                ),
                SizedBox(width: isSmallScreen ? 10 : 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
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
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    
    return SwitchListTile(
      secondary: Icon(
        icon,
        color: Theme.of(context).primaryColor,
        size: isSmallScreen ? 22 : 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 13,
          color: Colors.grey[600],
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).primaryColor,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
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
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).primaryColor,
        size: isSmallScreen ? 22 : 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 12,
          vertical: isSmallScreen ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[100],
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
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          underline: const SizedBox(),
          icon: Icon(
            Icons.arrow_drop_down,
            color: Theme.of(context).primaryColor,
            size: isSmallScreen ? 22 : 24,
          ),
        ),
      ),
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
          fontSize: isSmallScreen ? 14 : 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: isSmallScreen ? 14 : 16,
        color: Colors.grey[400],
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
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).primaryColor,
        size: isSmallScreen ? 22 : 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: isSmallScreen ? 12 : 13,
          color: Colors.grey[600],
        ),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
      ),
    );
  }

  Widget _buildDivider() {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20,
      ),
      child: const Divider(height: 1),
    );
  }

  Widget _buildLoginPrompt(bool isSmallScreen) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              size: isSmallScreen ? 70 : 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            Text(
              'Please Login',
              style: TextStyle(
                fontSize: isSmallScreen ? 22 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 8 : 10),
            Text(
              'You need to login to access settings',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 24 : 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
              icon: const Icon(Icons.login),
              label: const Text('Go to Login'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 24 : 30,
                  vertical: isSmallScreen ? 12 : 15,
                ),
                minimumSize: Size(isSmallScreen ? 180 : 200, isSmallScreen ? 45 : 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}