import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/destination_card.dart';

class SavedPlacesScreen extends StatelessWidget {
  const SavedPlacesScreen({super.key});

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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(children: [
                  GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Text('Saved Places', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.72),
              itemCount: 6,
              itemBuilder: (_, i) => DestinationCard(
                imageUrl: 'https://picsum.photos/400/300?random=${70 + i}',
                name: ['Kyoto', 'Santorini', 'Bali', 'Maldives', 'Paris', 'Dubai'][i],
                location: ['Japan', 'Greece', 'Indonesia', 'Maldives', 'France', 'UAE'][i],
                saved: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
