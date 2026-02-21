import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/activity_card.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});
  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  int _selectedDay = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.brandBlue,
        onPressed: () {},
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.blueGradient),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      children: [
                        GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20)),
                        const SizedBox(width: 12),
                        Text('Trip to Tokyo', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(children: [
                      Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                      SizedBox(width: 6),
                      Text('Mar 15 - Mar 22, 2025', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(height: 16),
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
                            color: _selectedDay == i ? Colors.white : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Text('Day ${i + 1}', style: TextStyle(
                            color: _selectedDay == i ? AppColors.brandBlue : Colors.white,
                            fontWeight: FontWeight.w600, fontSize: 14,
                          )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const ActivityCard(time: '8:00 AM', title: 'Tsukiji Fish Market', subtitle: 'Fresh sushi breakfast', icon: Icons.restaurant, iconColor: AppColors.warning, imageUrl: 'https://picsum.photos/100/100?random=30'),
                _timelineDivider(),
                const ActivityCard(time: '10:30 AM', title: 'Senso-ji Temple', subtitle: 'Ancient Buddhist temple', icon: Icons.temple_buddhist, iconColor: AppColors.error, imageUrl: 'https://picsum.photos/100/100?random=31'),
                _timelineDivider(),
                const ActivityCard(time: '1:00 PM', title: 'Shibuya Crossing', subtitle: 'World famous intersection', icon: Icons.directions_walk, iconColor: AppColors.brandBlue, imageUrl: 'https://picsum.photos/100/100?random=32'),
                _timelineDivider(),
                const ActivityCard(time: '3:30 PM', title: 'Meiji Shrine', subtitle: 'Peaceful forest shrine', icon: Icons.park, iconColor: AppColors.success, imageUrl: 'https://picsum.photos/100/100?random=33'),
                _timelineDivider(),
                const ActivityCard(time: '6:00 PM', title: 'Shinjuku Gyoen', subtitle: 'Beautiful garden park', icon: Icons.nature, iconColor: AppColors.success, imageUrl: 'https://picsum.photos/100/100?random=34'),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 23),
      child: Row(
        children: [
          Container(width: 2, height: 24, color: AppColors.border),
        ],
      ),
    );
  }
}
