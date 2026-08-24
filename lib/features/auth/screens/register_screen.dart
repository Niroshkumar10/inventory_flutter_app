import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/required_field_label.dart';
import '../../../core/utils/focus_utils.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../../session/session_service_new.dart';
import '../services/password_auth_service.dart';
import 'package:inventory_app/core/utils/app_logger.dart';

class RegisterScreen extends StatefulWidget {
  final void Function(String mobile) onRegisterSuccess;

  const RegisterScreen({
    super.key,
    required this.onRegisterSuccess,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _mobileController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _mobileFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _locationFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _userService = UserService();
  final _passwordService = PasswordAuthService();

  @override
  void initState() {
    super.initState();
    _mobileFocus.addListener(() => setState(() {}));
    _nameFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _confirmPasswordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mobileFocus.dispose();
    _nameFocus.dispose();
    _locationFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  // ─── validators ────────────────────────────────────────────────────────────

  String? _validateMobile(String? value) {
    final cleaned = value?.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim() ?? '';
    if (cleaned.isEmpty) return 'Mobile number is required';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Name is required';
    if (s.length < 2) return 'Name must be at least 2 characters';
    if (s.length > 50) return 'Name must be less than 50 characters';
    if (!RegExp(r'^[a-zA-Z\s\.\-]+$').hasMatch(s)) {
      return 'Only letters, spaces, dots and hyphens allowed';
    }
    return null;
  }

  String? _validateLocation(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Location is required';
    if (s.length < 3) return 'At least 3 characters';
    if (s.length > 100) return 'Too long';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 5) return 'At least 5 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm password';
    if (v != _passwordController.text) {
      return 'Password should match the above password';
    }
    return null;
  }

  String _cleanMobile() =>
      _mobileController.text.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();

  // ─── submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final mobile = _cleanMobile();
    setState(() => _isLoading = true);

    try {
      final exists = await _userService.userExists(mobile);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Account already exists. Please login instead.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ));
          setState(() => _isLoading = false);
        }
        return;
      }

      final newUser = UserModel(
        userId: mobile,
        mobile: mobile,
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        password: _passwordController.text,
        createdAt: DateTime.now(),
      );

      await _userService.saveUser(newUser);
      await _passwordService.setPassword(mobile, newUser.password!);

      appLogger.i('✅ Registered: $mobile');

      try {
        final authUser = await _userService.ensureAuthUser();
        await _userService.ensureUserProfile(uid: authUser.uid, mobile: mobile);
      } catch (e) {
        appLogger.w('⚠️ Firebase Auth skipped: $e');
      }

      await SessionServiceNew.saveLogin(mobile);

      if (mounted) widget.onRegisterSuccess(mobile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? cs.surface : const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Create Account',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── header ─────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_add, size: 40, color: cs.primary),
                      ),
                      const SizedBox(height: 12),
                      Text('Register your account',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface)),
                      const SizedBox(height: 4),
                      Text('Fill in the details below',
                          style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── mobile ─────────────────────────────────────────────
                _label('Mobile Number *', cs),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _mobileController,
                  focusNode: _mobileFocus,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: cs.onSurface),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: _decoration(cs, isDark,
                      hint: '10-digit mobile number',
                      prefixIcon: Icons.phone,
                      prefix: '+91  ',
                      helperText:
                          _mobileFocus.hasFocus ? 'Enter only numbers' : null),
                  validator: _validateMobile,
                  onChanged: (value) {
                    // Mobile is always 10 digits — advance the instant it's
                    // complete, same as an OTP box.
                    if (value.length == 10) {
                      advanceFocus(context, _nameFocus);
                    }
                  },
                  onFieldSubmitted: (_) => advanceFocus(context, _nameFocus),
                ),

                const SizedBox(height: 20),

                // ── full name ──────────────────────────────────────────
                _label('Full Name *', cs),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: cs.onSurface),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z\s\.\-]')),
                  ],
                  decoration: _decoration(cs, isDark,
                      hint: 'Enter your full name',
                      prefixIcon: Icons.person_outline,
                      helperText:
                          _nameFocus.hasFocus ? 'Enter only letters' : null),
                  validator: _validateName,
                  onFieldSubmitted: (_) => advanceFocus(context, _locationFocus),
                ),

                const SizedBox(height: 20),

                // ── location ───────────────────────────────────────────
                _label('Location *', cs),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _locationController,
                  focusNode: _locationFocus,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: cs.onSurface),
                  decoration: _decoration(cs, isDark,
                      hint: 'City or area',
                      prefixIcon: Icons.location_on_outlined),
                  validator: _validateLocation,
                  onFieldSubmitted: (_) => advanceFocus(context, _passwordFocus),
                ),

                const SizedBox(height: 20),

                // ── password ───────────────────────────────────────────
                _label('Password *', cs),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: cs.onSurface),
                  decoration: _decoration(cs, isDark,
                      hint: 'Enter your password',
                      prefixIcon: Icons.lock_outline,
                      helperText: _passwordFocus.hasFocus
                          ? 'Enter only characters, numbers and symbols. Atleast 5 characters'
                          : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      )),
                  validator: _validatePassword,
                  onFieldSubmitted: (_) => advanceFocus(context, _confirmPasswordFocus),
                ),

                const SizedBox(height: 20),

                // ── confirm password ───────────────────────────────────
                _label('Confirm Password *', cs),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocus,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: cs.onSurface),
                  decoration: _decoration(cs, isDark,
                      hint: 'Re-enter password',
                      prefixIcon: Icons.lock_outline,
                      helperText: _confirmPasswordFocus.hasFocus
                          ? 'Password should match the above password'
                          : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      )),
                  validator: _validateConfirm,
                  onFieldSubmitted: (_) => _submit(),
                ),

                const SizedBox(height: 32),

                // ── submit ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: isDark ? 4 : 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Create Account',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 16),

                // ── back to login link ─────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Login',
                            style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  Widget _label(String text, ColorScheme cs) => requiredFieldLabel(text,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurface.withValues(alpha: 0.7),
          letterSpacing: 0.3));

  InputDecoration _decoration(
    ColorScheme cs,
    bool isDark, {
    String? hint,
    IconData? prefixIcon,
    String? prefix,
    String? helperText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 14),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon,
              size: 20, color: cs.onSurface.withValues(alpha: 0.5))
          : null,
      prefixText: prefix,
      prefixStyle: TextStyle(color: cs.onSurface, fontSize: 14),
      suffixIcon: suffixIcon,
      helperText: helperText,
      helperStyle: TextStyle(color: cs.error, fontSize: 11.5),
      helperMaxLines: 2,
      filled: true,
      fillColor: isDark ? cs.surfaceContainerHighest : Colors.white,
      counterText: '',
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.6))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 1.8)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error, width: 1.8)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
