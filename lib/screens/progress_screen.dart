import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with TickerProviderStateMixin {
  int _currentStep = 0;
  late final AnimationController _progressCtrl;

  static const _steps = [
    _Step(Icons.search, 'Researching destination', 'Analyzing travel data and local insights'),
    _Step(Icons.attractions, 'Finding activities', 'Discovering top attractions and experiences'),
    _Step(Icons.schedule, 'Optimizing schedule', 'Building the perfect day-by-day plan'),
    _Step(Icons.check_circle_outline, 'Finalizing itinerary', 'Adding final touches and recommendations'),
  ];

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _advanceSteps();
  }

  Future<void> _advanceSteps() async {
    for (var i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      setState(() => _currentStep = i + 1);
      _progressCtrl.forward(from: 0);
    }
    // Auto-navigate back when done
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final progress = _currentStep / _steps.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, pad.top + 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.blueBorder, width: 1)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Text('Generating Itinerary', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.brandBlue)),
                const SizedBox(height: 4),
                Text('AI is planning your perfect trip', style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${(progress * 100).toInt()}% complete', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              itemCount: _steps.length,
              itemBuilder: (_, i) {
                final done = i < _currentStep;
                final active = i == _currentStep;
                return _buildStepRow(_steps[i], done, active, i);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(_Step step, bool done, bool active, int index) {
    final isLast = index == _steps.length - 1;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: done ? AppColors.success : (active ? AppColors.brandBlue : Colors.grey.shade200),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done ? Icons.check : step.icon,
                  size: 18,
                  color: done || active ? Colors.white : AppColors.textSecondary,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: done ? AppColors.success : Colors.grey.shade200,
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    step.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: done || active ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(step.subtitle, style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textSecondary)),
                  if (active)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            minHeight: 3,
                            color: AppColors.brandBlue,
                            backgroundColor: Color(0xFFE2E4E9),
                          ),
                        ),
                      ),
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

class _Step {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Step(this.icon, this.title, this.subtitle);
}
