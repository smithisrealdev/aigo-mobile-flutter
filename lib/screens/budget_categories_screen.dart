import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';

// ─── Models ───
class _BudgetCategory {
  final String name;
  final IconData icon;
  final Color color;
  double budget;
  double spent;

  _BudgetCategory({
    required this.name,
    required this.icon,
    required this.color,
    this.budget = 0,
    this.spent = 0,
  });

  double get percentage => budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
  bool get isOverBudget => budget > 0 && spent > budget;
}

final _budgetCategoriesProvider = StateProvider<List<_BudgetCategory>>((ref) => [
      _BudgetCategory(name: 'Food', icon: Icons.restaurant, color: const Color(0xFFEF4444), budget: 500, spent: 230),
      _BudgetCategory(name: 'Transport', icon: Icons.directions_car, color: const Color(0xFF3B82F6), budget: 300, spent: 180),
      _BudgetCategory(name: 'Accommodation', icon: Icons.hotel, color: const Color(0xFF8B5CF6), budget: 800, spent: 650),
      _BudgetCategory(name: 'Activities', icon: Icons.local_activity, color: const Color(0xFF10B981), budget: 400, spent: 120),
      _BudgetCategory(name: 'Shopping', icon: Icons.shopping_bag, color: const Color(0xFFEC4899), budget: 200, spent: 85),
      _BudgetCategory(name: 'Other', icon: Icons.more_horiz, color: const Color(0xFF64748B), budget: 100, spent: 30),
    ]);

// ─── Screen ───
class BudgetCategoriesScreen extends ConsumerWidget {
  const BudgetCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = ref.watch(_budgetCategoriesProvider);
    final totalBudget = categories.fold<double>(0, (s, c) => s + c.budget);
    final totalSpent = categories.fold<double>(0, (s, c) => s + c.spent);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.brandBlue,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1))),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Budget Categories',
                          style: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
                      const SizedBox(height: 8),
                      Row(children: [
                        _summaryChip('\$${totalSpent.toStringAsFixed(0)} spent'),
                        const SizedBox(width: 8),
                        _summaryChip('\$${totalBudget.toStringAsFixed(0)} budget'),
                        const SizedBox(width: 8),
                        _summaryChip('${totalBudget > 0 ? (totalSpent / totalBudget * 100).toStringAsFixed(0) : 0}% used'),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Pie chart visualization
            _PieChartWidget(categories: categories, isDark: isDark),
            const SizedBox(height: 24),

            // Category cards
            Text('Categories', style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
            const SizedBox(height: 12),
            ...categories.map((cat) => _CategoryCard(
                  category: cat,
                  isDark: isDark,
                  onEditBudget: () => _showEditBudgetDialog(context, ref, cat, categories),
                )),
            const SizedBox(height: 80),
          ])),
        ),
      ]),
    );
  }

  static Widget _summaryChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  void _showEditBudgetDialog(BuildContext context, WidgetRef ref, _BudgetCategory cat, List<_BudgetCategory> categories) {
    final controller = TextEditingController(text: cat.budget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Set ${cat.name} Budget', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '\$ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val == null) return;
              cat.budget = val;
              ref.read(_budgetCategoriesProvider.notifier).state = [...categories];
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─── Pie Chart ───
class _PieChartWidget extends StatelessWidget {
  final List<_BudgetCategory> categories;
  final bool isDark;
  const _PieChartWidget({required this.categories, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final totalSpent = categories.fold<double>(0, (s, c) => s + c.spent);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkMode : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        SizedBox(
          height: 180,
          width: 180,
          child: CustomPaint(
            painter: _PieChartPainter(
              categories: categories,
              totalSpent: totalSpent,
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('\$${totalSpent.toStringAsFixed(0)}',
                    style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                Text('Total Spent', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: categories.where((c) => c.spent > 0).map((c) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 6),
                  Text('${c.name} ${totalSpent > 0 ? (c.spent / totalSpent * 100).toStringAsFixed(0) : 0}%',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                ],
              )).toList(),
        ),
      ]),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<_BudgetCategory> categories;
  final double totalSpent;
  _PieChartPainter({required this.categories, required this.totalSpent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerRadius = radius * 0.6;
    var startAngle = -math.pi / 2;

    for (final cat in categories) {
      if (cat.spent <= 0 || totalSpent <= 0) continue;
      final sweep = (cat.spent / totalSpent) * 2 * math.pi;
      final paint = Paint()
        ..color = cat.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius - innerRadius
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (radius + innerRadius) / 2),
        startAngle,
        sweep - 0.02,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Category Card ───
class _CategoryCard extends StatelessWidget {
  final _BudgetCategory category;
  final bool isDark;
  final VoidCallback onEditBudget;
  const _CategoryCard({required this.category, required this.isDark, required this.onEditBudget});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDarkMode : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: category.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(category.icon, size: 20, color: category.color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category.name, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
              Text('\$${category.spent.toStringAsFixed(0)} / \$${category.budget.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
            ],
          )),
          GestureDetector(
            onTap: onEditBudget,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: category.percentage,
            backgroundColor: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
            valueColor: AlwaysStoppedAnimation(category.isOverBudget ? AppColors.error : category.color),
            minHeight: 6,
          ),
        ),
        if (category.isOverBudget) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.warning_amber, size: 14, color: AppColors.error),
            const SizedBox(width: 4),
            Text('Over budget by \$${(category.spent - category.budget).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
          ]),
        ],
      ]),
    );
  }
}
