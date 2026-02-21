import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) context.go('/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.blueGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 40),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOut),
              const SizedBox(height: 20),
              Text('aigo', style: GoogleFonts.dmSans(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -2))
                  .animate().fadeIn(delay: 300.ms, duration: 500.ms),
              const SizedBox(height: 8),
              Text('Your AI Travel Companion', style: GoogleFonts.dmSans(fontSize: 16, color: Colors.white.withValues(alpha: 0.8)))
                  .animate().fadeIn(delay: 600.ms, duration: 500.ms),
              const SizedBox(height: 40),
              SizedBox(
                width: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(3, (i) => Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), shape: BoxShape.circle))
                    .animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(delay: (200 * i).ms).scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), delay: (200 * i).ms, duration: 600.ms)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
