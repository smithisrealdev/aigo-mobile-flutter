import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.blueGradient),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  children: [
                    Row(children: [
                      GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20)),
                      const SizedBox(width: 12),
                      Text('Budget', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 140, height: 140,
                      child: CustomPaint(
                        painter: _DonutPainter(0.85),
                        child: Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('\$1,280', style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text('of \$1,500', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Spending by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _budgetBar('🏨 Accommodation', 520, 600, AppColors.brandBlue),
                _budgetBar('🍜 Food & Dining', 340, 400, AppColors.warning),
                _budgetBar('🚃 Transport', 220, 250, AppColors.success),
                _budgetBar('🎯 Activities', 200, 250, Colors.purple),
                const SizedBox(height: 24),
                const Text('Recent Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _expense('Sushi Dai', '🍣', '\$45', 'Today'),
                _expense('JR Rail Pass', '🚃', '\$200', 'Yesterday'),
                _expense('Hotel Gracery', '🏨', '\$180', 'Yesterday'),
                _expense('teamLab Borderless', '🎨', '\$32', 'Mar 16'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetBar(String label, double spent, double total, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const Spacer(), Text('\$${spent.toInt()} / \$${total.toInt()}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: spent / total, backgroundColor: color.withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation(color), minHeight: 8),
          ),
        ],
      ),
    );
  }

  Widget _expense(String title, String emoji, String amount, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ])),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  _DonutPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final bg = Paint()..color = Colors.white.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round;
    final fg = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - 6, bg);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 6), -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
