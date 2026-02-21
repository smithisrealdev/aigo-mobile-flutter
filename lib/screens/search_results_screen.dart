import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/quick_chip.dart';
import '../widgets/destination_card.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key});
  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  bool _isGrid = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: TextField(decoration: InputDecoration(hintText: 'Search "Beach"', prefixIcon: const Icon(Icons.search), contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border))))),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: const [
                  QuickChip(label: 'All', selected: true), SizedBox(width: 8),
                  QuickChip(label: '🏖️ Beach'), SizedBox(width: 8),
                  QuickChip(label: '💰 Budget'), SizedBox(width: 8),
                  QuickChip(label: '⭐ Top Rated'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(children: [
                const Text('24 results', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _isGrid = !_isGrid),
                  child: Icon(_isGrid ? Icons.grid_view : Icons.list, color: AppColors.textSecondary, size: 20),
                ),
              ]),
            ),
            Expanded(
              child: _isGrid
                  ? GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.72),
                      itemCount: 8,
                      itemBuilder: (_, i) => DestinationCard(
                        imageUrl: 'https://picsum.photos/400/300?random=${80 + i}',
                        name: ['Maldives', 'Phuket', 'Cancún', 'Zanzibar', 'Maui', 'Seychelles', 'Fiji', 'Boracay'][i],
                        location: ['Indian Ocean', 'Thailand', 'Mexico', 'Tanzania', 'Hawaii', 'Africa', 'Pacific', 'Philippines'][i],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: 8,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DestinationCard(
                          imageUrl: 'https://picsum.photos/400/300?random=${80 + i}',
                          name: ['Maldives', 'Phuket', 'Cancún', 'Zanzibar', 'Maui', 'Seychelles', 'Fiji', 'Boracay'][i],
                          location: ['Indian Ocean', 'Thailand', 'Mexico', 'Tanzania', 'Hawaii', 'Africa', 'Pacific', 'Philippines'][i],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
