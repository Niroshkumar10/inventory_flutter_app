import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:inventory_app/core/navigation/auth_notifier.dart';
import 'package:inventory_app/features/session/session_service_new.dart';
import 'package:inventory_app/core/utils/app_logger.dart';

class ProfileScreen extends StatefulWidget {
  final String userMobile;

  const ProfileScreen({
    super.key,
    required this.userMobile,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;
  bool _isEditing = false;
  bool _controllersInitialized = false;

  // Stream stored once — never recreated on rebuild
  late final Stream<DocumentSnapshot> _userStream;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userMobile)
        .snapshots();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await SessionServiceNew.logout();
      if (mounted) context.read<AuthNotifier>().clearUser();
    } catch (e) {
      appLogger.d('Logout error: $e');
      if (mounted) context.read<AuthNotifier>().clearUser();
    }
  }

  Future<void> _updateProfile() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userMobile)
          .update({
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile updated successfully'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text('Profile',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: cs.onSurface)),
        backgroundColor: cs.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: cs.onSurface),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: widget.userMobile.isEmpty
          ? _buildLoginPrompt(cs)
          : _buildProfileContent(cs, isDark, isSmallScreen),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Profile content (StreamBuilder using the stored stream)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildProfileContent(
      ColorScheme cs, bool isDark, bool isSmallScreen) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream, // ← stable reference, never recreated
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: cs.primary));
        }

        if (snapshot.hasError) {
          return _buildErrorUI(snapshot.error.toString(), cs);
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildUserNotFoundUI(cs, isDark, isSmallScreen);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['name']?.toString() ?? 'User';
        final location = data['location']?.toString() ?? 'Not specified';
        final createdAt = data['createdAt'] as Timestamp?;
        final businessName =
            data['businessName']?.toString() ?? 'My Business';
        final phone = data['phone']?.toString() ?? widget.userMobile;

        // Populate controllers only on first load or after save/cancel
        if (!_controllersInitialized) {
          _nameController.text = name;
          _locationController.text = location;
          _controllersInitialized = true;
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Column(
            children: [
              // ── Profile header ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary,
                      cs.primary.withValues(alpha: 0.7)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: isSmallScreen ? 40 : 45,
                        backgroundColor: Colors.white,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                              fontSize: isSmallScreen ? 36 : 42,
                              color: cs.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(name,
                        style: TextStyle(
                            fontSize: isSmallScreen ? 20 : 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(businessName,
                        style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.white.withValues(alpha: 0.9))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(widget.userMobile,
                          style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Personal information ────────────────────────────────
              _buildInfoCard(
                icon: Icons.person_outline,
                title: 'Personal Information',
                cs: cs,
                isDark: isDark,
                isSmallScreen: isSmallScreen,
                children: _isEditing
                    ? [
                        _buildEditableField(
                            'Full Name', _nameController, cs, isDark,
                            isSmallScreen: isSmallScreen),
                        const SizedBox(height: 16),
                        _buildEditableField(
                            'Location', _locationController, cs, isDark,
                            isSmallScreen: isSmallScreen),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _updateProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.secondary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                child: const Text('Save Changes'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  // Reset controllers to current Firestore values
                                  _nameController.text = name;
                                  _locationController.text = location;
                                  setState(() => _isEditing = false);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: cs.onSurface,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  side: BorderSide(color: cs.outline),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ],
                        ),
                      ]
                    : [
                        _buildInfoRow('Full Name', name, cs,
                            isSmallScreen: isSmallScreen),
                        _buildInfoRow('Mobile', phone, cs,
                            isSmallScreen: isSmallScreen),
                        _buildInfoRow('Location', location, cs,
                            isSmallScreen: isSmallScreen),
                        if (createdAt != null)
                          _buildInfoRow(
                            'Member Since',
                            '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}',
                            cs,
                            isSmallScreen: isSmallScreen,
                          ),
                      ],
              ),

              const SizedBox(height: 16),

              // ── Business information ────────────────────────────────
              _buildInfoCard(
                icon: Icons.business,
                title: 'Business Information',
                cs: cs,
                isDark: isDark,
                isSmallScreen: isSmallScreen,
                children: [
                  _buildInfoRow('Business',
                      businessName, cs,
                      isSmallScreen: isSmallScreen),
                  _buildInfoRow(
                      'GST', data['gst']?.toString() ?? 'Not added', cs,
                      isSmallScreen: isSmallScreen),
                  _buildInfoRow('Address',
                      data['address']?.toString() ?? 'Not added', cs,
                      isSmallScreen: isSmallScreen),
                ],
              ),

              const SizedBox(height: 24),

              // ── Logout ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoggingOut ? null : _logout,
                  icon: _isLoggingOut
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.logout, color: Colors.white),
                  label: Text(
                    _isLoggingOut ? 'Logging out...' : 'Logout from Account',
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reusable widgets
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required ColorScheme cs,
    required bool isDark,
    required bool isSmallScreen,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: isDark ? cs.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme cs,
      {required bool isSmallScreen}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmallScreen ? 100 : 120,
            child: Text(label,
                style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            width: 16,
            child: Text(':',
                style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    ColorScheme cs,
    bool isDark, {
    required bool isSmallScreen,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                color: cs.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(
              fontSize: isSmallScreen ? 14 : 15, color: cs.onSurface),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 14 : 16,
                vertical: isSmallScreen ? 12 : 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.outline)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.outline)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.primary, width: 2)),
            filled: true,
            fillColor: isDark
                ? cs.surfaceContainerHighest
                : Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Edge-case UIs
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoginPrompt(ColorScheme cs) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_off,
                  size: 64, color: cs.primary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text('Not Logged In',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('Please login to view your profile',
                style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.6)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/', (route) => false),
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Go to Login',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorUI(String error, ColorScheme cs) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.error_outline,
                  size: 64, color: cs.error.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text('Something went wrong',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(error,
                style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.6)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Try Again',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserNotFoundUI(
      ColorScheme cs, bool isDark, bool isSmallScreen) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: cs.tertiary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Text(
                widget.userMobile.isNotEmpty
                    ? widget.userMobile[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    fontSize: isSmallScreen ? 40 : 48,
                    color: cs.tertiary,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            Text(widget.userMobile,
                style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('Profile not complete',
                style: TextStyle(
                    fontSize: 16,
                    color: cs.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _isEditing = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 14 : 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Complete Profile',
                    style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoggingOut ? null : _logout,
                icon: _isLoggingOut
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: cs.error))
                    : Icon(Icons.logout, color: cs.error),
                label: Text(_isLoggingOut ? 'Logging out...' : 'Logout',
                    style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        color: cs.error)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 14 : 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: cs.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
