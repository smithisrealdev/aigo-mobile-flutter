import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/summary_card_extractor.dart';

/// Displays trip summary information as a visual card grid.
/// Matches web's ChatMessage.tsx summary card rendering.
class SummaryCardWidget extends StatelessWidget {
  final TripSummaryCard data;

  const SummaryCardWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFF0F7FF)],
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFDBEAFE),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: AppColors.brandBlue),
              const SizedBox(width: 6),
              Text(
                'Trip Summary',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.brandBlueLight : AppColors.brandBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grid of info items
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              if (data.destination != null)
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: data.flag ?? '📍',
                  value: data.destination!,
                  isDark: isDark,
                ),
              if (data.duration != null)
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: '📅',
                  value: data.duration!,
                  isDark: isDark,
                ),
              if (data.budget != null)
                _InfoChip(
                  icon: Icons.wallet_outlined,
                  label: '💰',
                  value: data.budget!,
                  isDark: isDark,
                ),
              if (data.weather != null)
                _InfoChip(
                  icon: Icons.cloud_outlined,
                  label: '🌤️',
                  value: data.weather!,
                  isDark: isDark,
                ),
              if (data.travelers != null)
                _InfoChip(
                  icon: Icons.people_outline,
                  label: '👥',
                  value: data.travelers!,
                  isDark: isDark,
                ),
              if (data.season != null)
                _InfoChip(
                  icon: Icons.wb_sunny_outlined,
                  label: '🌸',
                  value: data.season!,
                  isDark: isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
