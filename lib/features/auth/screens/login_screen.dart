import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../../session/session_service_new.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _isLoading = false;
  String? _mobileError;
  String? _nameError;
  String? _locationError;
  String? _generalError;

  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _newUserFormKey = GlobalKey<FormState>();

  final UserService _userService = UserService();

  // ================= VALIDATION METHODS =================
  String? _validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    
    // Remove any spaces, dashes, or parentheses
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    
    // Check if it's a valid Indian mobile number (10 digits starting with 6-9)
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return 'Please enter a valid 10-digit mobile number';
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
    
    // Allow only letters, spaces, and common punctuation
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

  // ================= NEW USER DIALOG WITH VALIDATION =================
  Future<UserModel?> _askNewUserDetails(String mobile) async {
    _nameController.clear();
    _locationController.clear();
    _nameError = null;
    _locationError = null;

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
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name *',
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
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Location *',
                          hintText: 'Enter your city or area',
                          errorText: _locationError,
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: (value) {
                          if (_locationError != null) {
                            setState(() => _locationError = null);
                          }
                        },
                        validator: _validateLocation,
                        onFieldSubmitted: (value) {
                          _submitNewUserForm(mobile, setState);
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Fields marked with * are required',
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
                  onPressed: () => _submitNewUserForm(mobile, setState),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _submitNewUserForm(String mobile, StateSetter setState) {
    // Validate the form
    if (_newUserFormKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final location = _locationController.text.trim();
      
      // Additional validation
      final nameValidation = _validateName(name);
      final locationValidation = _validateLocation(location);
      
      if (nameValidation != null) {
        setState(() => _nameError = nameValidation);
        return;
      }
      
      if (locationValidation != null) {
        setState(() => _locationError = locationValidation);
        return;
      }
      
      Navigator.pop(
        context,
        UserModel(
          userId: mobile,
          mobile: mobile,
          name: name,
          location: location,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  // ================= ENHANCED LOGIN LOGIC =================
  Future<void> _login() async {
    // Validate mobile number first
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

        // Validate new user data before saving
        final nameValidation = _validateName(newUser.name);
        final locationValidation = _validateLocation(newUser.location);
        
        if (nameValidation != null || locationValidation != null) {
          setState(() {
            _generalError = 'Invalid user details provided';
            _isLoading = false;
          });
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
      setState(() => _generalError = 'Login error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= ENHANCED UI WITH VALIDATION =================
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
                        validator: _validateMobile,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter a valid 10-digit mobile number',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
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

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
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
                                  'Login / Register',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ================= ADDITIONAL INFO =================
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
                          'How to login:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Enter your 10-digit mobile number\n'
                      '• If you are a new user, you will be asked to provide additional details\n'
                      '• Existing users will be logged in directly',
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

  // ================= TEST BUTTONS =================
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

  // ================= CLEANUP =================
  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}