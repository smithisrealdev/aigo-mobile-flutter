import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class PackingListScreen extends StatefulWidget {
  const PackingListScreen({super.key});
  @override
  State<PackingListScreen> createState() => _PackingListScreenState();
}

class _PackingListScreenState extends State<PackingListScreen> {
  final _categories = {
    'Essentials': [_Item('Passport', true), _Item('Phone charger', true), _Item('Travel adapter', false), _Item('Wallet', true)],
    'Clothing': [_Item('T-shirts (5)', true), _Item('Jeans (2)', false), _Item('Jacket', false), _Item('Sneakers', true)],
    'Toiletries': [_Item('Toothbrush', true), _Item('Sunscreen', false), _Item('Shampoo', true)],
    'Electronics': [_Item('Camera', false), _Item('Headphones', true), _Item('Power bank', false)],
  };

  int get _packed => _categories.values.expand((e) => e).where((e) => e.packed).length;
  int get _total => _categories.values.expand((e) => e).length;

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
                      Text('Packing List', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 100, height: 100,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: _packed / _total,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                          ),
                          Center(child: Text('$_packed/$_total', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.brandBlue.withValues(alpha: 0.08), AppColors.brandBlue.withValues(alpha: 0.02)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_awesome, color: AppColors.brandBlue, size: 20)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AI Suggestion', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text("Don't forget a rain jacket — Tokyo has 60% rain chance!", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ])),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: _categories.entries.map((cat) => _buildCategory(cat.key, cat.value)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(String name, List<_Item> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        title: Row(children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const Spacer(),
          Text('${items.where((e) => e.packed).length}/${items.length}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ]),
        children: items.map((item) => CheckboxListTile(
          value: item.packed,
          onChanged: (v) => setState(() => item.packed = v!),
          title: Text(item.name, style: TextStyle(decoration: item.packed ? TextDecoration.lineThrough : null, color: item.packed ? AppColors.textSecondary : AppColors.textPrimary)),
          activeColor: AppColors.brandBlue,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        )).toList(),
      ),
    );
  }
}

class _Item {
  final String name;
  bool packed;
  _Item(this.name, this.packed);
}
