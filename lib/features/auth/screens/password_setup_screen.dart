// lib/features/auth/screens/password_setup_screen.dart
import 'package:flutter/material.dart';
import '../services/password_auth_service.dart';

class PasswordSetupScreen extends StatefulWidget {
  final String mobile;
  final VoidCallback onPasswordSet;

  const PasswordSetupScreen({
    super.key,
    required this.mobile,
    required this.onPasswordSet,
  });

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _passwordError;
  String? _confirmError;

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    // Optional: Add stronger password validation
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
      return 'Password must contain both letters and numbers';
    }
    
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    
    return null;
  }

  Future<void> _setupPassword() async {
    // Validate password
    final passwordValidation = _validatePassword(_passwordController.text);
    if (passwordValidation != null) {
      setState(() => _passwordError = passwordValidation);
      return;
    }
    
    // Validate confirmation
    final confirmValidation = _validateConfirmPassword(_confirmPasswordController.text);
    if (confirmValidation != null) {
      setState(() => _confirmError = confirmValidation);
      return;
    }
    
    setState(() {
      _isLoading = true;
      _passwordError = null;
      _confirmError = null;
    });
    
    try {
      final passwordService = PasswordAuthService();
      final success = await passwordService.setPassword(
        widget.mobile,
        _passwordController.text,
      );
      
      if (success && mounted) {
        widget.onPasswordSet();
      } else if (mounted) {
        setState(() {
          _passwordError = 'Failed to set password. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _passwordError = 'Error: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _skipForNow() {
    widget.onPasswordSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Password'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Set a Password for Your Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Setting a password allows you to login securely',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password *',
                hintText: 'Enter password (min 6 characters)',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                border: const OutlineInputBorder(),
                errorText: _passwordError,
              ),
              onChanged: (value) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm Password *',
                hintText: 'Re-enter your password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                ),
                border: const OutlineInputBorder(),
                errorText: _confirmError,
              ),
              onChanged: (value) {
                if (_confirmError != null) {
                  setState(() => _confirmError = null);
                }
              },
              onSubmitted: (value) => _setupPassword(),
            ),
            
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _setupPassword,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Set Password & Continue'),
            ),
            
            const SizedBox(height: 10),
            
            TextButton(
              onPressed: _skipForNow,
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}