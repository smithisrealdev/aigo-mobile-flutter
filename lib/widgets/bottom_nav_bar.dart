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
    if (loc.startsWith('/saved')) return 2;
    if (loc.startsWith('/trips')) return 3;
    if (loc.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int idx) {
    const routes = ['/home', '/explore', '/saved', '/trips', '/profile'];
    context.go(routes[idx]);
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
        ),
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', active: idx == 0, onTap: () => _onTap(context, 0)),
              _NavItem(icon: Icons.search_rounded, label: 'Explore', active: idx == 1, onTap: () => _onTap(context, 1)),
              _NavItem(icon: Icons.bookmark_outline_rounded, label: 'Saved', active: idx == 2, onTap: () => _onTap(context, 2)),
              _NavItem(icon: Icons.calendar_today_rounded, label: 'Trips', active: idx == 3, onTap: () => _onTap(context, 3)),
              _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', active: idx == 4, onTap: () => _onTap(context, 4)),
            ],
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
    final color = active ? AppColors.brandBlue : const Color(0xFF9CA3AF);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w400, color: color)),
          ],
        ),
      ),
    );
  }
}
