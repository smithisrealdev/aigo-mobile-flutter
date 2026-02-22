import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/alert_service.dart';
import '../theme/app_colors.dart';

/// Trip alerts widget with severity indicators.
class TripAlertsWidget extends ConsumerWidget {
  final String tripId;
  const TripAlertsWidget({super.key, required this.tripId});

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning_amber;
      default:
        return Icons.info_outline;
    }
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return AppColors.error;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.brandBlue;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'weather':
        return Icons.cloud;
      case 'price_drop':
        return Icons.trending_down;
      case 'schedule_change':
        return Icons.schedule;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(tripAlertsProvider(tripId));

    return alertsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('Error: $e'),
      data: (alerts) {
        if (alerts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text('No alerts',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: alerts.map((alert) {
            final color = _severityColor(alert.severity);
            return GestureDetector(
              onTap: () async {
                if (!alert.isRead) {
                  await AlertService.instance.markAsRead(alert.id);
                  ref.invalidate(tripAlertsProvider(tripId));
                  ref.invalidate(unreadAlertsCountProvider(tripId));
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: alert.isRead
                      ? Colors.white
                      : color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: alert.isRead
                        ? AppColors.border
                        : color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_typeIcon(alert.type),
                          color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(alert.title,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: alert.isRead
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                        color: AppColors.textPrimary)),
                              ),
                              Icon(_severityIcon(alert.severity),
                                  color: color, size: 16),
                            ],
                          ),
                          if (alert.message != null)
                            Text(alert.message!,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (!alert.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Unread alerts count badge.
class UnreadAlertsBadge extends ConsumerWidget {
  final String tripId;
  final Widget child;
  const UnreadAlertsBadge(
      {super.key, required this.tripId, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadAlertsCountProvider(tripId));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        countAsync.when(
          data: (count) {
            if (count == 0) return const SizedBox.shrink();
            return Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text('$count',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    textAlign: TextAlign.center),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
