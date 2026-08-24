import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/focus_utils.dart';
import '../services/user_service.dart';
import '../../session/session_service_new.dart';
import '../services/password_auth_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'package:inventory_app/core/utils/app_logger.dart';

class LoginScreen extends StatefulWidget {
  final void Function(String mobile) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  final _mobileFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String? _mobileError;
  String? _passwordError;
  String? _generalError;

  final _userService = UserService();
  final _passwordService = PasswordAuthService();

  @override
  void initState() {
    super.initState();
    _mobileFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _mobileFocus.dispose();
    _passwordFocus.dispose();
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 5) return 'At least 5 characters';
    return null;
  }

  String _cleanMobile() =>
      _mobileController.text.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();

  // ─── login ─────────────────────────────────────────────────────────────────

  Future<void> _login() async {
    final mobileErr = _validateMobile(_mobileController.text);
    final passErr = _validatePassword(_passwordController.text);

    if (mobileErr != null || passErr != null) {
      setState(() {
        _mobileError = mobileErr;
        _passwordError = passErr;
        _generalError = null;
      });
      return;
    }

    final mobile = _cleanMobile();

    setState(() {
      _isLoading = true;
      _mobileError = null;
      _passwordError = null;
      _generalError = null;
    });

    try {
      appLogger.d('Login attempt: $mobile');

      final exists = await _userService.userExists(mobile);
      if (!exists) {
        setState(() {
          _generalError = 'Account not found. Please register first.';
          _isLoading = false;
        });
        return;
      }

      final valid =
          await _passwordService.verifyPassword(mobile, _passwordController.text);
      if (!valid) {
        setState(() {
          _passwordError = 'Incorrect password';
          _isLoading = false;
        });
        return;
      }

      await _completeLogin(mobile);
    } catch (e) {
      setState(() {
        _generalError = 'Login error: $e';
        _isLoading = false;
      });
    }
  }

  // ─── navigate to register ──────────────────────────────────────────────────

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          onRegisterSuccess: widget.onLoginSuccess,
        ),
      ),
    );
  }

  // ─── complete login ─────────────────────────────────────────────────────────

  Future<void> _completeLogin(String mobile) async {
    try {
      try {
        final authUser = await _userService.ensureAuthUser();
        await _userService.ensureUserProfile(
            uid: authUser.uid, mobile: mobile);
      } catch (e) {
        appLogger.w('⚠️ Firebase Auth skipped: $e');
      }

      await SessionServiceNew.saveLogin(mobile);

      if (mounted) widget.onLoginSuccess(mobile);
    } catch (e) {
      if (mounted) {
        setState(() {
          _generalError = 'Login error: $e';
          _isLoading = false;
        });
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── branding ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.store, size: 52, color: cs.primary),
                ),
                const SizedBox(height: 16),
                Text('Inventory App',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
                const SizedBox(height: 6),
                Text('Manage your business with ease',
                    style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withValues(alpha: 0.6))),

                const SizedBox(height: 40),

                // ── card ──────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? cs.surfaceContainerHighest : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Text('Welcome back',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface)),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: Text('Login to your account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withValues(alpha: 0.6))),
                      ),

                      const SizedBox(height: 24),

                      // mobile
                      _label('Mobile Number', cs),
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
                        decoration: _inputDecoration(
                          cs, isDark,
                          hint: '10-digit mobile number',
                          prefixIcon: Icons.phone,
                          prefix: '+91  ',
                          errorText: _mobileError,
                          helperText:
                              _mobileFocus.hasFocus ? 'Enter only numbers' : null,
                        ),
                        onChanged: (value) {
                          if (_mobileError != null || _generalError != null) {
                            setState(() {
                              _mobileError = null;
                              _generalError = null;
                            });
                          }
                          // Mobile is always 10 digits — advance the instant
                          // it's complete, same as an OTP box.
                          if (value.length == 10) {
                            advanceFocus(context, _passwordFocus);
                          }
                        },
                        onFieldSubmitted: (_) => advanceFocus(context, _passwordFocus),
                      ),

                      const SizedBox(height: 16),

                      // password
                      _label('Password', cs),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(color: cs.onSurface),
                        decoration: _inputDecoration(
                          cs, isDark,
                          hint: 'Enter your password',
                          prefixIcon: Icons.lock_outline,
                          errorText: _passwordError,
                          helperText: _passwordFocus.hasFocus
                              ? 'Enter only characters, numbers and symbols. Atleast 5 characters'
                              : null,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: cs.onSurface.withValues(alpha: 0.5),
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        onChanged: (_) {
                          if (_passwordError != null) {
                            setState(() => _passwordError = null);
                          }
                        },
                        onFieldSubmitted: (_) => _login(),
                      ),

                      // general error
                      if (_generalError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cs.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: cs.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: cs.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_generalError!,
                                    style: TextStyle(
                                        color: cs.error, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.primary,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // login button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: isDark ? 4 : 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Login',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── register prompt ───────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? cs.surfaceContainerHighest : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text("Don't have an account?",
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface)),
                      const SizedBox(height: 4),
                      Text(
                        'Enter your mobile number above, then tap Register',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.55)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _goToRegister,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.primary,
                            side: BorderSide(color: cs.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: cs.primary, strokeWidth: 2))
                              : Text('Register',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: cs.primary)),
                        ),
                      ),
                    ],
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

  Widget _label(String text, ColorScheme cs) => Text(text,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurface.withValues(alpha: 0.7),
          letterSpacing: 0.3));

  InputDecoration _inputDecoration(
    ColorScheme cs,
    bool isDark, {
    required String hint,
    required IconData prefixIcon,
    String? prefix,
    String? errorText,
    String? helperText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 14),
      prefixIcon:
          Icon(prefixIcon, size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
      prefixText: prefix,
      prefixStyle: TextStyle(color: cs.onSurface, fontSize: 14),
      suffixIcon: suffixIcon,
      errorText: errorText,
      helperText: helperText,
      helperStyle: TextStyle(color: cs.error, fontSize: 11.5),
      helperMaxLines: 2,
      filled: true,
      fillColor: isDark ? cs.surface : Colors.grey.shade50,
      counterText: '',
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outline)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: cs.outline.withValues(alpha: 0.6))),
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
