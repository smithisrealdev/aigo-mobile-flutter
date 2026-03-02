import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/alert_service.dart';
import '../services/trip_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<TripAlert> _alerts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await TripService.instance.listTrips();
      final allAlerts = <TripAlert>[];
      for (final trip in trips) {
        final alerts = await AlertService.instance.getAlerts(trip.id);
        allAlerts.addAll(alerts);
      }
      allAlerts.sort((a, b) =>
          (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      setState(() {
        _alerts = allAlerts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final tripIds = _alerts.map((a) => a.tripId).toSet();
    for (final tripId in tripIds) {
      await AlertService.instance.markAllAsRead(tripId);
    }
    await _loadAlerts();
  }

  Future<void> _markAsRead(TripAlert alert) async {
    if (!alert.isRead) {
      await AlertService.instance.markAsRead(alert.id);
      await _loadAlerts();
    }
  }

  bool _isToday(String? dateStr) {
    if (dateStr == null) return false;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'weather':
        return Icons.cloud;
      case 'price_drop':
        return Icons.local_offer;
      case 'schedule_change':
        return Icons.schedule;
      case 'reminder':
        return Icons.notifications_active;
      default:
        return Icons.info_outline;
    }
  }

  Color _colorForSeverity(String severity) {
    switch (severity) {
      case 'critical':
        return AppColors.error;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.brandBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayAlerts = _alerts.where((a) => _isToday(a.createdAt)).toList();
    final earlierAlerts =
        _alerts.where((a) => !_isToday(a.createdAt)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1))),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: const Icon(Icons.arrow_back_ios,
                          color: AppColors.textPrimary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text('Notifications',
                        style: GoogleFonts.dmSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const Spacer(),
                    TextButton(
                      onPressed: _alerts.any((a) => !a.isRead)
                          ? _markAllRead
                          : null,
                      child: Text('Mark all read',
                          style: TextStyle(
                              color: _alerts.any((a) => !a.isRead)
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text('Failed to load notifications',
                                style: GoogleFonts.dmSans(
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: _loadAlerts,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _alerts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.notifications_none,
                                    size: 64, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text('No notifications yet',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 16,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAlerts,
                            child: ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                if (todayAlerts.isNotEmpty) ...[
                                  _sectionTitle('Today'),
                                  ...todayAlerts
                                      .map((a) => _alertCard(a)),
                                  const SizedBox(height: 20),
                                ],
                                if (earlierAlerts.isNotEmpty) ...[
                                  _sectionTitle('Earlier'),
                                  ...earlierAlerts
                                      .map((a) => _alertCard(a)),
                                ],
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
      );

  Widget _alertCard(TripAlert alert) {
    final color = _colorForSeverity(alert.severity);
    final icon = _iconForType(alert.type);

    return GestureDetector(
      onTap: () => _markAsRead(alert),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(alert.title,
                            style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ),
                      if (!alert.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.brandBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(_timeAgo(alert.createdAt),
                          style: GoogleFonts.dmSans(
                              color: AppColors.textSecondary,
                              fontSize: 11)),
                    ],
                  ),
                  if (alert.message != null) ...[
                    const SizedBox(height: 4),
                    Text(alert.message!,
                        style: GoogleFonts.dmSans(
                            color: AppColors.textSecondary,
                            fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
