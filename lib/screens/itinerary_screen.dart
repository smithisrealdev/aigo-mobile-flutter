import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/trip_map_view.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});
  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDay = 0;
  bool _fabExpanded = false;
  bool _isBookmarked = false;
  bool _showMap = false;

  // Per-day budget data (spent, total)
  final List<Map<String, dynamic>> _dayBudgets = [
    {'spent': 850, 'total': 1200, 'title': 'Exploring Asakusa & Shibuya', 'date': 'Mar 15'},
    {'spent': 1100, 'total': 1200, 'title': 'Akihabara & Ueno Park', 'date': 'Mar 16'},
    {'spent': 400, 'total': 1000, 'title': 'Day trip to Kamakura', 'date': 'Mar 17'},
    {'spent': 900, 'total': 1200, 'title': 'Shinjuku & Harajuku', 'date': 'Mar 18'},
    {'spent': 600, 'total': 800, 'title': 'Odaiba & TeamLab', 'date': 'Mar 19'},
    {'spent': 750, 'total': 1000, 'title': 'Tsukiji & Ginza', 'date': 'Mar 20'},
    {'spent': 500, 'total': 1200, 'title': 'Free day & Departure', 'date': 'Mar 21'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _buildExpandableFab(),
      body: GestureDetector(
        onTap: () {
          if (_fabExpanded) setState(() => _fabExpanded = false);
        },
        child: Column(
          children: [
            _buildHeroHeader(),
            // Map / List toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  _viewToggleButton('List', Icons.list, !_showMap),
                  const SizedBox(width: 8),
                  _viewToggleButton('Map', Icons.map, _showMap),
                ],
              ),
            ),
            Expanded(
              child: _showMap
                  ? TripMapView(
                      activities: const [
                        MapActivity(name: 'Tsukiji Fish Market', time: '8:00 AM', lat: 35.6654, lng: 139.7707),
                        MapActivity(name: 'Senso-ji Temple', time: '10:30 AM', lat: 35.7148, lng: 139.7967),
                        MapActivity(name: 'Shibuya Crossing', time: '1:00 PM', lat: 35.6595, lng: 139.7004),
                        MapActivity(name: 'Meiji Shrine', time: '3:30 PM', lat: 35.6764, lng: 139.6993),
                        MapActivity(name: 'Shinjuku Gyoen', time: '6:00 PM', lat: 35.6852, lng: 139.7100),
                      ],
                    )
                  : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  _buildAiChipsRow(),
                  const SizedBox(height: 16),
                  _buildAiInsightCard(),
                  const SizedBox(height: 16),
                  _buildDayHeader(),
                  const SizedBox(height: 12),
                  ..._buildActivityList(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 1. Hero Header ────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.blueGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Trip to Tokyo',
                      style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  // Bookmark icon
                  IconButton(
                    icon: Icon(
                      _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: Colors.white,
                    ),
                    onPressed: () => setState(() => _isBookmarked = !_isBookmarked),
                  ),
                  // Share pill
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.share, color: Colors.white, size: 15),
                          SizedBox(width: 6),
                          Text('Share', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  const Text('Mar 15 - Mar 22, 2025', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 16),
                  const Icon(Icons.location_on, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  const Text('Tokyo, Japan', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Collaboration row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('👤 ', style: TextStyle(fontSize: 13)),
                  const Text('Just you', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      '+ Invite',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Day tabs
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: 7,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedDay == i ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Day ${i + 1}',
                      style: TextStyle(
                        color: _selectedDay == i ? AppColors.brandBlue : Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── 2. AI Feature Chips ───────────────────────────────────────────

  Widget _viewToggleButton(String label, IconData icon, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showMap = label == 'Map'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.brandBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppColors.brandBlue : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiChipsRow() {
    return Row(
      children: [
        _aiChip('✨ AI Generated', AppColors.brandBlue),
        const SizedBox(width: 8),
        _aiChip('👤 Tailored for you', AppColors.success),
        const SizedBox(width: 8),
        _aiChip('📶 Offline ready', const Color(0xFF6B7280)),
      ],
    );
  }

  Widget _aiChip(String label, Color color) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // ─── 3. AI Insight Card ────────────────────────────────────────────
  Widget _buildAiInsightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✨ Optimized for your travel style',
            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Nature', 'Slow Travel', 'Local Food'].map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(tag, style: const TextStyle(fontSize: 12, color: AppColors.brandBlue, fontWeight: FontWeight.w500)),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          const Text(
            'Based on your preferences',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Text('🔄', style: TextStyle(fontSize: 14)),
                  label: const Text('Regenerate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandBlue,
                    side: const BorderSide(color: AppColors.brandBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Text('✨', style: TextStyle(fontSize: 14)),
                  label: const Text('Optimize'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 5. Day Header with Budget ─────────────────────────────────────
  Widget _buildDayHeader() {
    final day = _dayBudgets[_selectedDay];
    final spent = day['spent'] as int;
    final total = day['total'] as int;
    final pct = (spent / total).clamp(0.0, 1.0);
    final barColor = pct < 0.6 ? AppColors.success : (pct < 0.85 ? AppColors.warning : AppColors.error);

    return Row(
      children: [
        // Day badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.brandBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Day ${_selectedDay + 1}',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        // Date + title
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(day['date'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(
                day['title'] as String,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Budget indicator
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '฿$spent/฿$total',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 60,
              height: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation(barColor),
                  minHeight: 3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── 6. Activity List ──────────────────────────────────────────────
  List<Widget> _buildActivityList() {
    const activities = [
      {'time': '8:00 AM', 'title': 'Tsukiji Fish Market', 'sub': 'Fresh sushi breakfast', 'icon': 'restaurant', 'color': 'warning', 'img': '30'},
      {'time': '10:30 AM', 'title': 'Senso-ji Temple', 'sub': 'Ancient Buddhist temple', 'icon': 'temple', 'color': 'error', 'img': '31'},
      {'time': '1:00 PM', 'title': 'Shibuya Crossing', 'sub': 'World famous intersection', 'icon': 'walk', 'color': 'blue', 'img': '32'},
      {'time': '3:30 PM', 'title': 'Meiji Shrine', 'sub': 'Peaceful forest shrine', 'icon': 'park', 'color': 'success', 'img': '33'},
      {'time': '6:00 PM', 'title': 'Shinjuku Gyoen', 'sub': 'Beautiful garden park', 'icon': 'nature', 'color': 'success', 'img': '34'},
    ];

    final iconMap = {
      'restaurant': Icons.restaurant,
      'temple': Icons.temple_buddhist,
      'walk': Icons.directions_walk,
      'park': Icons.park,
      'nature': Icons.nature,
    };
    final colorMap = {
      'warning': AppColors.warning,
      'error': AppColors.error,
      'blue': AppColors.brandBlue,
      'success': AppColors.success,
    };

    final widgets = <Widget>[];
    for (var i = 0; i < activities.length; i++) {
      final a = activities[i];
      widgets.add(_buildEnhancedActivityCard(
        time: a['time']!,
        title: a['title']!,
        subtitle: a['sub']!,
        icon: iconMap[a['icon']]!,
        iconColor: colorMap[a['color']]!,
        imageUrl: 'https://images.unsplash.com/photo-1528164344705-47542687000d?w=100&h=100&fit=crop',
        showSwapBadge: i == 0,
      ));
      if (i < activities.length - 1) widgets.add(_timelineDivider());
    }
    return widgets;
  }

  Widget _buildEnhancedActivityCard({
    required String time,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    String? imageUrl,
    bool showSwapBadge = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Drag indicator
          const Icon(Icons.drag_indicator, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 8),
          // Icon box
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    if (showSwapBadge)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brandBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Tap to Swap', style: TextStyle(fontSize: 10, color: AppColors.brandBlue, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Row(
        children: [
          Container(width: 2, height: 24, color: AppColors.border),
        ],
      ),
    );
  }

  // ─── 7. Expandable FAB ─────────────────────────────────────────────
  Widget _buildExpandableFab() {
    final fabItems = [
      {'icon': Icons.edit, 'label': 'Edit', 'color': AppColors.brandBlue},
      {'icon': Icons.map, 'label': 'Map', 'color': AppColors.success},
      {'icon': Icons.chat_bubble_outline, 'label': 'AI Chat', 'color': AppColors.warning},
      {'icon': Icons.auto_awesome, 'label': 'AI Optimize', 'color': AppColors.brandBlue},
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded)
          ...fabItems.reversed.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                    ),
                    child: Text(
                      item['label'] as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: FloatingActionButton(
                      heroTag: item['label'],
                      mini: false,
                      backgroundColor: item['color'] as Color,
                      elevation: 4,
                      onPressed: () => setState(() => _fabExpanded = false),
                      child: Icon(item['icon'] as IconData, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            );
          }),
        FloatingActionButton(
          heroTag: 'main_fab',
          backgroundColor: AppColors.brandBlue,
          onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
          child: AnimatedRotation(
            turns: _fabExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}
