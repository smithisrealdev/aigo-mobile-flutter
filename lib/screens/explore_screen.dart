import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/quick_chip.dart';
import '../widgets/destination_card.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search destinations...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.brandBlue, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.tune, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: const [
                  QuickChip(label: 'All', selected: true), SizedBox(width: 8),
                  QuickChip(label: '🏖️ Beaches'), SizedBox(width: 8),
                  QuickChip(label: '⛰️ Mountains'), SizedBox(width: 8),
                  QuickChip(label: '🏛️ Culture'), SizedBox(width: 8),
                  QuickChip(label: '🍜 Food'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.72,
                ),
                itemCount: 8,
                itemBuilder: (_, i) => DestinationCard(
                  imageUrl: 'https://picsum.photos/400/300?random=${i + 10}',
                  name: ['Kyoto', 'Santorini', 'Machu Picchu', 'Dubai', 'Sydney', 'Maldives', 'Iceland', 'Bangkok'][i],
                  location: ['Japan', 'Greece', 'Peru', 'UAE', 'Australia', 'Maldives', 'Iceland', 'Thailand'][i],
                  rating: [4.9, 4.8, 4.7, 4.6, 4.8, 4.9, 4.5, 4.7][i],
                  saved: i % 3 == 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
