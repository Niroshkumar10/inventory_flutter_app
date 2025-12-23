import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_screen.dart';
import './features/auth/screens/login_screen.dart';
import '../features/session/session_service_new.dart';
import '../features/inventory/services/inventory_repo_service.dart'; // Add this import

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _userMobile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final mobile = await SessionServiceNew.getUserId();
      setState(() {
        _userMobile = mobile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show login if no userMobile
    if (_userMobile == null || _userMobile!.isEmpty) {
      return LoginScreen(
        onLoginSuccess: () {
          // Refresh the auth state after login
          _checkAuth();
        },
      );
    }
    final inventoryService = InventoryService(_userMobile!);
    
    // Show dashboard with userMobile
    return DashboardScreen(userMobile: _userMobile!,
    inventoryService: inventoryService,);
  }
}