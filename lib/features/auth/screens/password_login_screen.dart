// lib/features/auth/screens/password_login_screen.dart
import 'package:flutter/material.dart';
import '../services/password_auth_service.dart';
import '../../session/session_service_new.dart';

class PasswordLoginScreen extends StatefulWidget {
  final String mobile;
  final VoidCallback onLoginSuccess;

  const PasswordLoginScreen({
    super.key,
    required this.mobile,
    required this.onLoginSuccess,
  });

  @override
  State<PasswordLoginScreen> createState() => _PasswordLoginScreenState();
}

class _PasswordLoginScreenState extends State<PasswordLoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final PasswordAuthService _passwordService = PasswordAuthService();
  
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _passwordError;

  Future<void> _loginWithPassword() async {
    final password = _passwordController.text;
    
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _passwordError = null;
    });
    
    try {
      final isValid = await _passwordService.verifyPassword(
        widget.mobile,
        password,
      );
      
      if (isValid) {
        // Save session and proceed
        await SessionServiceNew.saveLogin(widget.mobile);
        if (mounted) {
          widget.onLoginSuccess();
        }
      } else {
        setState(() => _passwordError = 'Invalid password');
      }
    } catch (e) {
      setState(() => _passwordError = 'Login error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    // Implement password reset functionality
    // Could send OTP to mobile number
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: const Text('Password reset will be sent to your mobile number'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login - ${widget.mobile}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              'Enter Password',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Welcome back! Enter your password for ${widget.mobile}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
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
              onSubmitted: (value) => _loginWithPassword(),
            ),
            
            const SizedBox(height: 10),
            
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                child: const Text('Forgot Password?'),
              ),
            ),
            
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _loginWithPassword,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}