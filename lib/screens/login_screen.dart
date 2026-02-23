import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../config/supabase_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignIn = true;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmController = TextEditingController();

  Future<void> _showForgotPassword() async {
    final resetEmailController = TextEditingController(text: _emailController.text);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reset Password', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Enter your email and we\'ll send you a reset link.', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email address',
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final email = resetEmailController.text.trim();
                  if (email.isEmpty) return;
                  try {
                    await SupabaseConfig.client.auth.resetPasswordForEmail(email);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Check your email for reset link')),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Send Reset Link', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
    resetEmailController.dispose();
  }

  Future<void> _handleEmailAuth() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      if (_isSignIn) {
        await AuthService.instance.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        if (_passwordController.text != _confirmController.text) {
          setState(() { _errorMessage = 'Passwords do not match'; _isLoading = false; });
          return;
        }
        await AuthService.instance.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
        );
      }
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() { _errorMessage = e.toString(); });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() { _errorMessage = e.toString(); });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, pad.top + 60, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              SvgPicture.asset(
                'assets/images/logo_white.svg',
                height: 56,
                colorFilter: const ColorFilter.mode(Color(0xFF111827), BlendMode.srcIn),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 13, color: AppColors.brandBlue),
                    const SizedBox(width: 5),
                    Text('Powered by AI', style: GoogleFonts.dmSans(
                      fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.brandBlue,
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Heading
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _isSignIn ? 'Welcome back' : 'Get started',
                  style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _isSignIn ? 'Sign in to continue your journey' : 'Create an account to explore',
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),

              // Pill toggle
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(child: _tabButton('Sign in', _isSignIn, () => setState(() => _isSignIn = true))),
                    Expanded(child: _tabButton('Sign up', !_isSignIn, () => setState(() => _isSignIn = false))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Error
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.red.shade700))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Form fields
              if (_isSignIn) _buildSignInForm() else _buildSignUpForm(),

              const SizedBox(height: 24),

              // OR divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade200, thickness: 0.8)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text('OR', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade400, letterSpacing: 1)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade200, thickness: 0.8)),
                ],
              ),
              const SizedBox(height: 24),

              // Google button
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300, width: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text('G', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF4285F4))),
                      ),
                      const SizedBox(width: 10),
                      Text('Continue with Google', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bottom link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignIn ? "Don't have an account? " : 'Already have an account? ',
                    style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isSignIn = !_isSignIn),
                    child: Text(
                      _isSignIn ? 'Sign up' : 'Sign in',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.brandBlue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active ? [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ] : null,
        ),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: active ? AppColors.brandBlue : AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildSignInForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _inputField(controller: _emailController, hint: 'Email address', icon: Icons.email_outlined),
        const SizedBox(height: 12),
        _inputField(
          controller: _passwordController, hint: 'Password', icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF9CA3AF)),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: _rememberMe ? AppColors.brandBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _rememberMe ? AppColors.brandBlue : const Color(0xFFD1D5DB), width: 1.2),
                ),
                child: _rememberMe ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 8),
            Text('Remember me', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
            const Spacer(),
            GestureDetector(
              onTap: () => _showForgotPassword(),
              child: Text('Forgot password?', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.brandBlue, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _primaryButton(_isLoading ? 'Signing in...' : 'Sign in', _isLoading ? () {} : _handleEmailAuth),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _inputField(controller: _nameController, hint: 'Full name', icon: Icons.person_outline),
        const SizedBox(height: 12),
        _inputField(controller: _emailController, hint: 'Email address', icon: Icons.email_outlined),
        const SizedBox(height: 12),
        _inputField(
          controller: _passwordController, hint: 'Password', icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF9CA3AF)),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _passwordController,
          builder: (context2, value, child2) {
            final strength = _calcStrength(value.text);
            if (value.text.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: strength.value,
                    minHeight: 3,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation(strength.color),
                  ),
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(strength.label, style: GoogleFonts.dmSans(fontSize: 11, color: strength.color, fontWeight: FontWeight.w500)),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        _inputField(
          controller: _confirmController, hint: 'Confirm password', icon: Icons.shield_outlined,
          obscure: _obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF9CA3AF)),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        const SizedBox(height: 20),
        _primaryButton(_isLoading ? 'Creating account...' : 'Create Account', _isLoading ? () {} : _handleEmailAuth),
      ],
    );
  }

  _PasswordStrength _calcStrength(String pw) {
    if (pw.length < 4) return _PasswordStrength('Weak', 0.2, Colors.red.shade400);
    var score = 0;
    if (pw.length >= 8) score++;
    if (pw.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) score++;
    if (RegExp(r'[0-9]').hasMatch(pw)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) score++;
    if (score <= 1) return _PasswordStrength('Weak', 0.25, Colors.red.shade400);
    if (score <= 2) return _PasswordStrength('Fair', 0.5, Colors.orange.shade400);
    if (score <= 3) return _PasswordStrength('Good', 0.75, Colors.blue.shade400);
    return _PasswordStrength('Strong', 1.0, Colors.green.shade500);
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF9CA3AF)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.5)),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _PasswordStrength {
  final String label;
  final double value;
  final Color color;
  _PasswordStrength(this.label, this.value, this.color);
}
