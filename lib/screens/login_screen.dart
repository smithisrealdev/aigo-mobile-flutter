import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            decoration: const BoxDecoration(
              gradient: AppColors.blueGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('aigo', style: GoogleFonts.dmSans(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
                  const SizedBox(height: 4),
                  Text('Welcome back', style: GoogleFonts.dmSans(fontSize: 16, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const TextField(decoration: InputDecoration(hintText: 'Email address', prefixIcon: Icon(Icons.email_outlined))),
                  const SizedBox(height: 16),
                  const TextField(obscureText: true, decoration: InputDecoration(hintText: 'Password', prefixIcon: Icon(Icons.lock_outline), suffixIcon: Icon(Icons.visibility_off_outlined))),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: const Text('Forgot Password?', style: TextStyle(color: AppColors.brandBlue)))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Sign In'),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    const Expanded(child: Divider(color: AppColors.border)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('or continue with', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ]),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _SocialButton(icon: Icons.g_mobiledata, label: 'Google', onTap: () => context.go('/home'))),
                      const SizedBox(width: 16),
                      Expanded(child: _SocialButton(icon: Icons.apple, label: 'Apple', onTap: () => context.go('/home'))),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? ", style: TextStyle(color: AppColors.textSecondary)),
                      GestureDetector(onTap: () {}, child: const Text('Sign Up', style: TextStyle(color: AppColors.brandBlue, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SocialButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
