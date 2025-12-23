import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../../session/session_service_new.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _isLoading = false;
  String _error = '';

  final UserService _userService = UserService();

  // ================= NEW USER DIALOG =================
  Future<UserModel?> _askNewUserDetails(String mobile) async {
    _nameController.clear();
    _locationController.clear();

    return showDialog<UserModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('New User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.trim().isEmpty) return;

                Navigator.pop(
                  context,
                  UserModel(
                    userId: mobile,
                    mobile: mobile,
                    name: _nameController.text.trim(),
                    location: _locationController.text.trim(),
                    createdAt: DateTime.now(),
                  ),
                );
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  // ================= LOGIN LOGIC =================
  Future<void> _login() async {
    final mobile = _mobileController.text.trim();

    if (mobile.isEmpty) {
      setState(() => _error = 'Please enter mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      print('📱 Checking user for mobile: $mobile');

      final exists = await _userService.userExists(mobile);
      print('👤 User exists: $exists');

      // ===== ASK DETAILS ONLY FOR NEW USER =====
      if (!exists) {
        final newUser = await _askNewUserDetails(mobile);

        if (newUser == null) {
          setState(() => _isLoading = false);
          return;
        }

        await _userService.saveUser(newUser);
        print('✅ New user saved');
      }

      // ===== FIREBASE AUTH (OPTIONAL) =====
      try {
        final authUser = await _userService.ensureAuthUser();
        await _userService.ensureUserProfile(
          uid: authUser.uid,
          mobile: mobile,
        );
      } catch (e) {
        print('⚠️ Firebase Auth skipped: $e');
      }

      // ===== SAVE SESSION =====
      await SessionServiceNew.saveLogin(mobile);

      widget.onLoginSuccess();

    } catch (e) {
      setState(() => _error = 'Login error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                'Inventory App',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      TextField(
                        controller: _mobileController,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),

                      if (_error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _error,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text('Login / Register'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),


             
            ],
          ),
        ),
      ),
    );
  }

  Widget _testButton(String mobile) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: () {
          _mobileController.text = mobile;
          _login();
        },
        child: Text('Test $mobile'),
      ),
    );
  }
}
