import 'dart:math' as math;
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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isSignIn = true;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _gearCtrl;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _gearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    _gearCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final sw = MediaQuery.of(context).size.width;

    // Shrink header on sign-up to give form more room
    final headerH = _isSignIn ? (260.0 + pad.top) : (195.0 + pad.top);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // ── Blue branded header ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            height: headerH,
            width: sw,
            child: Stack(
              children: [
                // Gradient bg with rounded bottom
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2B6FFF), Color(0xFF1A5EFF), Color(0xFF0044E6)],
                        stops: [0.0, 0.4, 1.0],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(36),
                        bottomRight: Radius.circular(36),
                      ),
                    ),
                  ),
                ),
                // Decorative elements
                AnimatedBuilder(
                  animation: _gearCtrl,
                  builder: (_, _) => CustomPaint(
                    size: Size(sw, headerH),
                    painter: _LoginDecoPainter(gearValue: _gearCtrl.value),
                  ),
                ),
                // Logo + tagline centered
                Positioned(
                  left: 0,
                  right: 0,
                  top: pad.top + (_isSignIn ? 44 : 20),
                  child: Column(
                    children: [
                      SvgPicture.asset(
                        'assets/images/logo_white.svg',
                        height: _isSignIn ? 56 : 44,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 13, color: Colors.white70),
                            const SizedBox(width: 5),
                            Text('Powered by AI', style: GoogleFonts.dmSans(
                              fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70,
                            )),
                          ],
                        ),
                      ),
                      if (_isSignIn) ...[
                        const SizedBox(height: 6),
                        Text('Travels far and near', style: GoogleFonts.dmSans(
                          fontSize: 13, color: Colors.white54, fontStyle: FontStyle.italic, letterSpacing: 0.3,
                        )),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Form area ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Overlap card — less overlap on sign-up
                  Transform.translate(
                    offset: Offset(0, _isSignIn ? -28 : -18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.fromLTRB(20, _isSignIn ? 22 : 22, 20, _isSignIn ? 24 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // #9: Card heading
                          Text(
                            _isSignIn ? 'Welcome back' : 'Get started',
                            style: GoogleFonts.dmSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isSignIn ? 'Sign in to continue your journey' : 'Create an account to explore',
                            style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 18),

                          // #8: Pill toggle — lighter active style
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
                          const SizedBox(height: 18),

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
                            const SizedBox(height: 12),
                          ],

                          // Form fields
                          if (_isSignIn) _buildSignInForm() else _buildSignUpForm(),
                        ],
                      ),
                    ),
                  ),

                  // #5: OR divider — more breathing room
                  Transform.translate(
                    offset: const Offset(0, -14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade200, thickness: 0.8)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Text('OR', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade400, letterSpacing: 1)),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade200, thickness: 0.8)),
                        ],
                      ),
                    ),
                  ),

                  // #6: Google button — local icon
                  SizedBox(
                    height: 46,
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        backgroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google "G" as styled text instead of network image
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300, width: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text('G', style: GoogleFonts.dmSans(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: const Color(0xFF4285F4),
                            )),
                          ),
                          const SizedBox(width: 10),
                          Text('Continue with Google', style: GoogleFonts.dmSans(
                            fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
                          )),
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
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // #8: Tab uses white bg (not blue) to reduce hierarchy conflict with Sign In button
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
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.brandBlue : AppColors.textSecondary,
          ),
        ),
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
          controller: _passwordController,
          hint: 'Password',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: Colors.grey.shade400),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 10),
        // #3: Custom checkbox — lighter
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _rememberMe ? AppColors.brandBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _rememberMe ? AppColors.brandBlue : Colors.grey.shade300,
                    width: 1.2,
                  ),
                ),
                child: _rememberMe
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
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
        const SizedBox(height: 18),
        _gradientButton(_isLoading ? 'Signing in...' : 'Sign in', _isLoading ? () {} : _handleEmailAuth),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _inputField(controller: _nameController, hint: 'Full name', icon: Icons.person_outline),
        const SizedBox(height: 10),
        _inputField(controller: _emailController, hint: 'Email address', icon: Icons.email_outlined),
        const SizedBox(height: 14),
        // Security section micro-label
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 5),
              Text('Security', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade400, letterSpacing: 0.5)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _inputField(
          controller: _passwordController,
          hint: 'Password',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: Colors.grey.shade400),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        // Password strength indicator
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
                    backgroundColor: Colors.grey.shade200,
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
          controller: _confirmController,
          hint: 'Confirm password',
          icon: Icons.shield_outlined,
          obscure: _obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: Colors.grey.shade400),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        const SizedBox(height: 16),
        _gradientButton(_isLoading ? 'Creating account...' : 'Create Account', _isLoading ? () {} : _handleEmailAuth),
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
      style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(fontSize: 14, color: Colors.grey.shade400),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 20, color: Colors.grey.shade400),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF0F1F3),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200, width: 0.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200, width: 0.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.5)),
      ),
    );
  }

  Widget _gradientButton(String label, VoidCallback onPressed) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: AppColors.blueGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: MaterialButton(
        onPressed: onPressed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }
}

// ══════════════════════════════════
// Login header decorations — richer, more visible
// ══════════════════════════════════
class _LoginDecoPainter extends CustomPainter {
  final double gearValue;
  _LoginDecoPainter({required this.gearValue});

  static const _orange = Color(0xFFFFB347);
  static const _orangeDark = Color(0xFFD4882A);

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;
    final fill = Paint()..style = PaintingStyle.fill;

    // ── Large gear top-right (cropped, visible) ──
    canvas.save();
    canvas.translate(sw + 8, -10);
    canvas.rotate(gearValue * 2 * math.pi * 0.2);
    _drawGear(canvas, 0, 0, 55, _orange, _orangeDark);
    canvas.restore();

    // ── Medium gear bottom-left (partially visible) ──
    canvas.save();
    canvas.translate(-12, sh - 10);
    canvas.rotate(-gearValue * 2 * math.pi * 0.15);
    _drawGear(canvas, 0, 0, 36, Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05));
    canvas.restore();

    // ── Small gear mid-right ──
    canvas.save();
    canvas.translate(sw - 36, sh * 0.48);
    canvas.rotate(gearValue * 2 * math.pi * 0.12);
    _drawGear(canvas, 0, 0, 14, Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04));
    canvas.restore();

    // ── Floating squares ──
    _drawSquare(canvas, sw * 0.14, sh * 0.3, 12, Colors.white.withValues(alpha: 0.1));
    _drawSquare(canvas, sw * 0.82, sh * 0.65, 9, _orange.withValues(alpha: 0.25));

    // ── Subtle circles ──
    fill.color = Colors.white.withValues(alpha: 0.04);
    canvas.drawCircle(Offset(sw * 0.78, sh * 0.25), 55, fill);
    canvas.drawCircle(Offset(sw * 0.2, sh * 0.7), 35, fill);

    // ── Dotted arc top ──
    fill.color = Colors.white.withValues(alpha: 0.12);
    for (var i = 0; i < 5; i++) {
      final angle = -0.6 + i * 0.18;
      final x = sw * 0.68 + 40 * math.cos(angle);
      final y = sh * 0.2 + 40 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 1.8, fill);
    }

    // ── White dots ──
    fill.color = Colors.white.withValues(alpha: 0.15);
    canvas.drawCircle(Offset(sw * 0.25, sh * 0.22), 3, fill);
    canvas.drawCircle(Offset(sw * 0.7, sh * 0.72), 2.5, fill);

    // ── Orange accent dots (clear, no ambiguity) ──
    fill.color = _orange.withValues(alpha: 0.45);
    canvas.drawCircle(Offset(sw * 0.12, sh * 0.52), 4.5, fill);
    fill.color = _orange.withValues(alpha: 0.3);
    canvas.drawCircle(Offset(sw * 0.88, sh * 0.38), 3.5, fill);
  }

  void _drawGear(Canvas canvas, double x, double y, double r, Color color, Color darkColor) {
    final fill = Paint()..style = PaintingStyle.fill;
    fill.color = darkColor;
    _gearPath(canvas, x + 1.5, y + 2.5, r, fill);
    fill.color = color;
    _gearPath(canvas, x, y, r, fill);
    fill.color = darkColor;
    canvas.drawCircle(Offset(x, y), r * 0.28, fill);
    // Highlight
    fill.color = Colors.white.withValues(alpha: 0.12);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(x, y), width: r * 1.1, height: r * 1.1),
      -math.pi, math.pi * 0.4, true, fill,
    );
  }

  void _gearPath(Canvas canvas, double x, double y, double r, Paint paint) {
    const teeth = 8;
    final path = Path();
    for (var i = 0; i < teeth; i++) {
      final a1 = i * 2 * math.pi / teeth;
      final a2 = (i + 0.15) * 2 * math.pi / teeth;
      final a3 = (i + 0.35) * 2 * math.pi / teeth;
      final a4 = (i + 0.65) * 2 * math.pi / teeth;
      final a5 = (i + 0.85) * 2 * math.pi / teeth;
      final oR = r;
      final iR = r * 0.7;
      if (i == 0) path.moveTo(x + iR * math.cos(a1), y + iR * math.sin(a1));
      path.lineTo(x + iR * math.cos(a2), y + iR * math.sin(a2));
      path.quadraticBezierTo(
        x + oR * 1.05 * math.cos((a2 + a3) / 2), y + oR * 1.05 * math.sin((a2 + a3) / 2),
        x + oR * math.cos(a3), y + oR * math.sin(a3),
      );
      path.lineTo(x + oR * math.cos(a4), y + oR * math.sin(a4));
      path.quadraticBezierTo(
        x + oR * 1.05 * math.cos((a4 + a5) / 2), y + oR * 1.05 * math.sin((a4 + a5) / 2),
        x + iR * math.cos(a5), y + iR * math.sin(a5),
      );
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawSquare(Canvas canvas, double x, double y, double sz, Color color) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(math.pi / 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: sz * 2, height: sz * 2),
        Radius.circular(sz * 0.3),
      ),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LoginDecoPainter old) => true;
}

class _PasswordStrength {
  final String label;
  final double value;
  final Color color;
  _PasswordStrength(this.label, this.value, this.color);
}
