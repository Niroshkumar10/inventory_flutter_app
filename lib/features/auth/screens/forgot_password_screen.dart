import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/password_auth_service.dart';
import 'package:inventory_app/core/utils/app_logger.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // 0 = enter mobile, 1 = set new password
  int _step = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  String? _mobileError;
  String? _passwordError;
  String? _confirmError;
  String? _generalError;

  final _userService = UserService();
  final _passwordService = PasswordAuthService();

  // Mobile verified in step 1, used in step 2
  late String _verifiedMobile;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String _cleanMobile() =>
      _mobileController.text.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();

  // ─── Step 1: verify mobile ────────────────────────────────────────────────

  Future<void> _verifyMobile() async {
    final cleaned = _cleanMobile();
    if (cleaned.isEmpty || !RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      setState(() => _mobileError = 'Enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _mobileError = null;
      _generalError = null;
    });

    try {
      final exists = await _userService.userExists(cleaned);
      if (!exists) {
        setState(() {
          _generalError = 'No account found with this mobile number.';
          _isLoading = false;
        });
        return;
      }

      _verifiedMobile = cleaned;
      setState(() {
        _step = 1;
        _isLoading = false;
      });
    } catch (e) {
      appLogger.d('ForgotPassword verify error: $e');
      setState(() {
        _generalError = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  // ─── Step 2: set new password ─────────────────────────────────────────────

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    String? passErr;
    String? confirmErr;

    if (password.isEmpty) {
      passErr = 'Password is required';
    } else if (password.length < 6) {
      passErr = 'At least 6 characters';
    } else if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(password)) {
      passErr = 'Must contain both letters and numbers';
    }

    if (confirm.isEmpty) {
      confirmErr = 'Please confirm your password';
    } else if (confirm != password) {
      confirmErr = 'Passwords do not match';
    }

    if (passErr != null || confirmErr != null) {
      setState(() {
        _passwordError = passErr;
        _confirmError = confirmErr;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _passwordError = null;
      _confirmError = null;
      _generalError = null;
    });

    try {
      final success =
          await _passwordService.setPassword(_verifiedMobile, password);
      if (!success) {
        setState(() {
          _generalError = 'Failed to reset password. Please try again.';
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Password reset successfully! Please login.'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      appLogger.d('ForgotPassword reset error: $e');
      setState(() {
        _generalError = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  // ─── build ────────────────────────────────────────────────────────────────

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
        title: Text(
          'Reset Password',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                // ── icon ───────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_reset, size: 48, color: cs.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  _step == 0 ? 'Forgot Password?' : 'Set New Password',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface),
                ),
                const SizedBox(height: 6),
                Text(
                  _step == 0
                      ? 'Enter your registered mobile number'
                      : 'Create a new password for $_verifiedMobile',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.6)),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // ── card ────────────────────────────────────────────────
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
                  child: _step == 0
                      ? _buildStep1(cs, isDark)
                      : _buildStep2(cs, isDark),
                ),

                // ── step indicator ─────────────────────────────────────
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(active: _step >= 0, cs: cs),
                    const SizedBox(width: 8),
                    _dot(active: _step >= 1, cs: cs),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── step 1 widget ────────────────────────────────────────────────────────

  Widget _buildStep1(ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Mobile Number', cs),
        const SizedBox(height: 6),
        TextFormField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          style: TextStyle(color: cs.onSurface),
          decoration: _inputDecoration(
            cs, isDark,
            hint: '10-digit mobile number',
            prefixIcon: Icons.phone,
            prefix: '+91  ',
            errorText: _mobileError,
          ),
          onChanged: (_) => setState(() {
            _mobileError = null;
            _generalError = null;
          }),
          onFieldSubmitted: (_) => _verifyMobile(),
        ),

        if (_generalError != null) ...[
          const SizedBox(height: 12),
          _errorBox(_generalError!, cs),
        ],

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyMobile,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Verify Mobile',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ─── step 2 widget ────────────────────────────────────────────────────────

  Widget _buildStep2(ColorScheme cs, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('New Password', cs),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: cs.onSurface),
          decoration: _inputDecoration(
            cs, isDark,
            hint: 'Min 6 chars, letters + numbers',
            prefixIcon: Icons.lock_outline,
            errorText: _passwordError,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: cs.onSurface.withValues(alpha: 0.5),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onChanged: (_) => setState(() => _passwordError = null),
        ),

        const SizedBox(height: 16),

        _label('Confirm Password', cs),
        const SizedBox(height: 6),
        TextFormField(
          controller: _confirmController,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          style: TextStyle(color: cs.onSurface),
          decoration: _inputDecoration(
            cs, isDark,
            hint: 'Re-enter new password',
            prefixIcon: Icons.lock_outline,
            errorText: _confirmError,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                color: cs.onSurface.withValues(alpha: 0.5),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          onChanged: (_) => setState(() => _confirmError = null),
          onFieldSubmitted: (_) => _resetPassword(),
        ),

        if (_generalError != null) ...[
          const SizedBox(height: 12),
          _errorBox(_generalError!, cs),
        ],

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Reset Password',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _step = 0;
              _passwordError = null;
              _confirmError = null;
              _generalError = null;
            }),
            child: Text('Change mobile number',
                style: TextStyle(color: cs.primary, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  Widget _dot({required bool active, required ColorScheme cs}) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: active ? 20 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.outline,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _label(String text, ColorScheme cs) => Text(text,
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.onSurface.withValues(alpha: 0.7),
          letterSpacing: 0.3));

  Widget _errorBox(String message, ColorScheme cs) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: TextStyle(color: cs.error, fontSize: 13))),
          ],
        ),
      );

  InputDecoration _inputDecoration(
    ColorScheme cs,
    bool isDark, {
    required String hint,
    required IconData prefixIcon,
    String? prefix,
    String? errorText,
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
      filled: true,
      fillColor: isDark ? cs.surface : Colors.grey.shade50,
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
