import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

class ScaffoldWithNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    if (loc.startsWith('/home')) return 0;
    if (loc.startsWith('/explore')) return 1;
    if (loc.startsWith('/ai-chat')) return 2;
    if (loc.startsWith('/trips')) return 3;
    if (loc.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int idx) {
    const routes = ['/home', '/explore', '/ai-chat', '/trips', '/profile'];
    context.go(routes[idx]);
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(icon: Icons.home_rounded, label: 'Home', active: idx == 0, onTap: () => _onTap(context, 0)),
                  _NavItem(icon: Icons.explore_rounded, label: 'Explore', active: idx == 1, onTap: () => _onTap(context, 1)),
                  _CenterFab(active: idx == 2, onTap: () => _onTap(context, 2)),
                  _NavItem(icon: Icons.luggage_rounded, label: 'Trips', active: idx == 3, onTap: () => _onTap(context, 3)),
                  _NavItem(icon: Icons.person_rounded, label: 'Profile', active: idx == 4, onTap: () => _onTap(context, 4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? AppColors.brandBlue : AppColors.textSecondary, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? AppColors.brandBlue : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _CenterFab extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _CenterFab({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: AppColors.blueGradient,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.brandBlue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
      ),
    );
  }
}
