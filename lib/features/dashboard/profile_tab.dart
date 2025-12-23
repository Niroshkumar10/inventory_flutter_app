import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inventory_app/features/session/session_service_new.dart';

class ProfileScreen extends StatefulWidget {
  final String userMobile;
  
  const ProfileScreen({
    Key? key,
    required this.userMobile,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await SessionServiceNew.logout();
      
      // Navigate to login
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      print('Logout error: $e');
      // Still navigate even on error
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: SessionServiceNew.getUserId(),
      builder: (context, snapshot) {
        // Show loading while checking session
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Use the userMobile passed from DashboardScreen
        final mobile = widget.userMobile;
        
        if (mobile.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('Please login to view profile'),
            ),
          );
        }

        // User is logged in, show profile
        return _buildProfileScreen(mobile);
      },
    );
  }

  Widget _buildProfileScreen(String mobile) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_isLoggingOut)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(mobile)  // Use mobile as document ID
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildUserNotFoundUI(mobile);
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name']?.toString() ?? 'User';
          final location = data['location']?.toString() ?? 'Not specified';

          return _buildProfileUI(name, mobile, location);
        },
      ),
    );
  }

  Widget _buildUserNotFoundUI(String mobile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepPurple,
              child: Text(
                mobile.isNotEmpty ? mobile.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Mobile: $mobile',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Profile data not found in database.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoggingOut ? null : _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: _isLoggingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileUI(String name, String mobile, String location) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.deepPurple,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 40,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Mobile: $mobile',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              children: [
                _infoTile(Icons.person, 'Name', name),
                _infoTile(Icons.phone, 'Mobile', mobile),
                _infoTile(Icons.location_on, 'Location', location),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoggingOut ? null : _logout,
              icon: _isLoggingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.logout),
              label: _isLoggingOut
                  ? const Text('Logging out...')
                  : const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(value),
      ),
    );
  }
}