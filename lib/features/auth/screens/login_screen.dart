import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../../session/session_service_new.dart';
import '../services/password_auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  String? _mobileError;
  String? _passwordError;
  String? _nameError;
  String? _locationError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  String? _generalError;

  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _newUserFormKey = GlobalKey<FormState>();

  final UserService _userService = UserService();
  final PasswordAuthService _passwordService = PasswordAuthService();

  // ================= VALIDATION METHODS =================
  String? _validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return 'Please enter a valid 10-digit mobile number';
    }
    
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
      return 'Password must contain both letters and numbers';
    }
    
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    
    return null;
  }

  String? _validateName(String? value) {
    final trimmedValue = value?.trim() ?? '';
    
    if (trimmedValue.isEmpty) {
      return 'Name is required';
    }
    
    if (trimmedValue.length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    if (trimmedValue.length > 50) {
      return 'Name must be less than 50 characters';
    }
    
    if (!RegExp(r'^[a-zA-Z\s\.\-]+$').hasMatch(trimmedValue)) {
      return 'Name can only contain letters, spaces, dots, and hyphens';
    }
    
    return null;
  }

  String? _validateLocation(String? value) {
    final trimmedValue = value?.trim() ?? '';
    
    if (trimmedValue.isEmpty) {
      return 'Location is required';
    }
    
    if (trimmedValue.length < 3) {
      return 'Location must be at least 3 characters';
    }
    
    if (trimmedValue.length > 100) {
      return 'Location must be less than 100 characters';
    }
    
    return null;
  }

  // ================= REGISTRATION DIALOG =================
  Future<UserModel?> _showRegistrationDialog() async {
    _nameController.clear();
    _locationController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _nameError = null;
    _locationError = null;
    _newPasswordError = null;
    _confirmPasswordError = null;

    return showDialog<UserModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New User Registration'),
              content: SingleChildScrollView(
                child: Form(
                  key: _newUserFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mobile Number (pre-filled, read-only)
                      TextFormField(
                        controller: _mobileController,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number *',
                          hintText: 'Enter 10-digit mobile number',
                          prefixIcon: const Icon(Icons.phone),
                          prefixText: '+91 ',
                          border: const OutlineInputBorder(),
                          errorText: _mobileError,
                        ),
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        enabled: false, // Disable editing during registration
                        onChanged: (value) {
                          if (_mobileError != null) {
                            setState(() => _mobileError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          hintText: 'Enter your full name',
                          errorText: _nameError,
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (value) {
                          if (_nameError != null) {
                            setState(() => _nameError = null);
                          }
                        },
                        validator: _validateName,
                      ),
                      const SizedBox(height: 16),
                      
                      // Location Field
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Location *',
                          hintText: 'Enter your city or area',
                          errorText: _locationError,
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (value) {
                          if (_locationError != null) {
                            setState(() => _locationError = null);
                          }
                        },
                        validator: _validateLocation,
                      ),
                      const SizedBox(height: 16),
                      
                      // Password Field
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          hintText: 'Create a password (min 6 characters)',
                          errorText: _newPasswordError,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() => _obscureNewPassword = !_obscureNewPassword);
                            },
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (value) {
                          if (_newPasswordError != null) {
                            setState(() => _newPasswordError = null);
                          }
                        },
                        validator: _validateNewPassword,
                      ),
                      const SizedBox(height: 16),
                      
                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password *',
                          hintText: 'Re-enter your password',
                          errorText: _confirmPasswordError,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                            },
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: (value) {
                          if (_confirmPasswordError != null) {
                            setState(() => _confirmPasswordError = null);
                          }
                        },
                        validator: _validateConfirmPassword,
                        onFieldSubmitted: (value) {
                          _submitRegistration(setState);
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'All fields marked with * are required',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => _submitRegistration(setState),
                  child: const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _submitRegistration(StateSetter setState) {
    if (_newUserFormKey.currentState!.validate()) {
      final mobile = _mobileController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final name = _nameController.text.trim();
      final location = _locationController.text.trim();
      final password = _newPasswordController.text;
      
      // Additional validation
      final nameValidation = _validateName(name);
      final locationValidation = _validateLocation(location);
      final passwordValidation = _validateNewPassword(password);
      final confirmValidation = _validateConfirmPassword(_confirmPasswordController.text);
      
      if (nameValidation != null) {
        setState(() => _nameError = nameValidation);
        return;
      }
      
      if (locationValidation != null) {
        setState(() => _locationError = locationValidation);
        return;
      }
      
      if (passwordValidation != null) {
        setState(() => _newPasswordError = passwordValidation);
        return;
      }
      
      if (confirmValidation != null) {
        setState(() => _confirmPasswordError = confirmValidation);
        return;
      }
      
      Navigator.pop(
        context,
        UserModel(
          userId: mobile,
          mobile: mobile,
          name: name,
          location: location,
          password: password,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  // ================= LOGIN METHOD =================
  Future<void> _login() async {
    // Validate mobile number
    final mobileValidation = _validateMobile(_mobileController.text.trim());
    if (mobileValidation != null) {
      setState(() {
        _mobileError = mobileValidation;
        _generalError = null;
      });
      return;
    }

    // Validate password
    final passwordValidation = _validatePassword(_passwordController.text);
    if (passwordValidation != null) {
      setState(() {
        _passwordError = passwordValidation;
        _generalError = null;
      });
      return;
    }

    final mobile = _mobileController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _mobileError = null;
      _passwordError = null;
      _generalError = null;
    });

    try {
      print('📱 Attempting login for mobile: $mobile');

      final exists = await _userService.userExists(mobile);
      
      if (!exists) {
        setState(() {
          _generalError = 'Account not found. Please register first.';
          _isLoading = false;
        });
        return;
      }
      
      // Verify password
      final isValidPassword = await _passwordService.verifyPassword(mobile, password);
      
      if (!isValidPassword) {
        setState(() {
          _passwordError = 'Invalid password';
          _isLoading = false;
        });
        return;
      }
      
      // Password is correct, complete login
      await _completeLogin(mobile);

    } catch (e) {
      setState(() => _generalError = 'Login error: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  // ================= REGISTER METHOD =================
  Future<void> _register() async {
    // Validate mobile number
    final mobileValidation = _validateMobile(_mobileController.text.trim());
    if (mobileValidation != null) {
      setState(() {
        _mobileError = mobileValidation;
        _generalError = null;
      });
      return;
    }

    final mobile = _mobileController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');

    setState(() {
      _isLoading = true;
      _mobileError = null;
      _generalError = null;
    });

    try {
      print('📱 Checking if user exists for registration: $mobile');

      final exists = await _userService.userExists(mobile);
      
      if (exists) {
        setState(() {
          _generalError = 'Account already exists. Please login instead.';
          _isLoading = false;
        });
        return;
      }
      
      // Show registration dialog
      setState(() => _isLoading = false);
      
      final newUser = await _showRegistrationDialog();

      if (newUser == null) {
        return;
      }

      setState(() => _isLoading = true);

      // Save user with password
      await _userService.saveUser(newUser);
      
      // Hash and store password separately
      await _passwordService.setPassword(mobile, newUser.password!);
      
      print('✅ New user registered successfully');
      
      // Complete login after registration
      await _completeLogin(mobile);

    } catch (e) {
      setState(() => _generalError = 'Registration error: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  // ================= COMPLETE LOGIN PROCESS =================
  Future<void> _completeLogin(String mobile) async {
    try {
      // Firebase Auth (optional)
      try {
        final authUser = await _userService.ensureAuthUser();
        await _userService.ensureUserProfile(
          uid: authUser.uid,
          mobile: mobile,
        );
      } catch (e) {
        print('⚠️ Firebase Auth skipped: $e');
      }

      // Save session
      await SessionServiceNew.saveLogin(mobile);
      
      if (mounted) {
        widget.onLoginSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generalError = 'Login error: ${e.toString()}');
        setState(() => _isLoading = false);
      }
    }
  }

  // ================= UI WITH TWO BUTTONS =================
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
                      // Mobile Number Field
                      TextFormField(
                        controller: _mobileController,
                        decoration: InputDecoration(
                          labelText: 'Mobile Number *',
                          hintText: 'Enter 10-digit mobile number',
                          prefixIcon: const Icon(Icons.phone),
                          prefixText: '+91 ',
                          border: const OutlineInputBorder(),
                          errorText: _mobileError,
                        ),
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        onChanged: (value) {
                          if (_mobileError != null) {
                            setState(() => _mobileError = null);
                          }
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password *',
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
                      ),

                      if (_generalError != null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _generalError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // LOGIN BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // REGISTER BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _register,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'REGISTER',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'How to use:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• LOGIN: Existing users can login with mobile number and password\n'
                      '• REGISTER: New users can create an account with name, location, and password\n'
                      '• Password must be at least 6 characters with letters and numbers',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}