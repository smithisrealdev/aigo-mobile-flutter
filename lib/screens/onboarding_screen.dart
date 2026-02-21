import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = [
    {'icon': Icons.auto_awesome, 'title': 'AI-Powered Planning', 'desc': 'Let our AI create perfect itineraries tailored to your preferences and travel style.'},
    {'icon': Icons.explore, 'title': 'Discover Hidden Gems', 'desc': 'Explore curated destinations and local experiences recommended just for you.'},
    {'icon': Icons.groups, 'title': 'Travel Smarter', 'desc': 'Budget tracking, packing lists, and real-time tips — all in one place.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.blueGradientVertical),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: 3,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(32)),
                          child: Icon(_pages[i]['icon'] as IconData, color: Colors.white, size: 56),
                        ),
                        const SizedBox(height: 48),
                        Text(_pages[i]['title'] as String, textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 16),
                        Text(_pages[i]['desc'] as String, textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 16, color: Colors.white.withValues(alpha: 0.8), height: 1.5)),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => Container(
                  width: _page == i ? 24 : 8, height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: _page == i ? 1.0 : 0.4), borderRadius: BorderRadius.circular(4)),
                )),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _page < 2 ? _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : context.go('/login'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.brandBlue, padding: const EdgeInsets.symmetric(vertical: 18)),
                    child: Text(_page < 2 ? 'Next' : 'Get Started', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              if (_page < 2)
                TextButton(onPressed: () => context.go('/login'), child: const Text('Skip', style: TextStyle(color: Colors.white70))),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
