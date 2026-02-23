import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../services/recommendation_service.dart';

class TravelTipsScreen extends StatefulWidget {
  final String? destination;
  const TravelTipsScreen({super.key, this.destination});

  @override
  State<TravelTipsScreen> createState() => _TravelTipsScreenState();
}

class _TravelTipsScreenState extends State<TravelTipsScreen> {
  AIRecommendationResult? _travelMode;
  AIRecommendationResult? _deals;
  AIRecommendationResult? _tickets;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    final dest = widget.destination;
    if (dest == null || dest.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        RecommendationService.instance.recommendTravelMode(destination: dest),
        RecommendationService.instance.recommendDeals(destination: dest),
        RecommendationService.instance
            .recommendTickets(destination: dest),
      ]);
      setState(() {
        _travelMode = results[0];
        _deals = results[1];
        _tickets = results[2];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  static const _genericTips = [
    _GenericSection('Getting Around', Icons.directions_transit, [
      'Research local transportation options before you go',
      'Download offline maps for your destination',
      'Consider day passes for public transit',
    ]),
    _GenericSection('Save Money', Icons.savings, [
      'Book accommodations and flights early',
      'Eat where locals eat for better prices',
      'Look for free walking tours',
    ]),
    _GenericSection('Must-Know Tips', Icons.lightbulb, [
      'Always have a copy of important documents',
      'Learn a few phrases in the local language',
      'Check visa requirements well in advance',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final hasDestination =
        widget.destination != null && widget.destination!.isNotEmpty;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.maybePop(context),
                          child: const Icon(Icons.arrow_back_ios,
                              color: AppColors.textPrimary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Travel Tips',
                              style: GoogleFonts.dmSans(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                    if (hasDestination) ...[
                      const SizedBox(height: 8),
                      Text(widget.destination!,
                          style: GoogleFonts.dmSans(
                              fontSize: 15,
                              color: Colors.white70)),
                    ],
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
                            Text('Failed to load tips',
                                style: GoogleFonts.dmSans(
                                    color: AppColors.textSecondary)),
                            TextButton(
                                onPressed: _loadTips,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTips,
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: hasDestination
                              ? _buildAiSections()
                              : _buildGenericSections(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAiSections() {
    return [
      if (_travelMode != null)
        _buildRecommendationCard(
          'Getting Around',
          Icons.directions_transit,
          _travelMode!,
        ),
      if (_deals != null)
        _buildRecommendationCard(
          'Deals & Tickets',
          Icons.local_offer,
          _deals!,
        ),
      if (_tickets != null)
        _buildRecommendationCard(
          'Must-Do Activities',
          Icons.star,
          _tickets!,
        ),
      if (_travelMode == null && _deals == null && _tickets == null)
        ..._buildGenericSections(),
    ];
  }

  Widget _buildRecommendationCard(
      String title, IconData icon, AIRecommendationResult result) {
    final items = result.structured?.items ?? [];
    final text = result.recommendation;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brandBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.brandBlue, size: 20),
        ),
        title: Text(title,
            style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w600)),
        children: [
          if (items.isNotEmpty)
            ...items.map((item) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle,
                      color: AppColors.success, size: 18),
                  title: Text(
                      item.label.isNotEmpty ? item.label : item.value,
                      style: GoogleFonts.dmSans(
                          fontSize: 14, color: AppColors.textPrimary)),
                  subtitle: item.detail != null
                      ? Text(item.detail!,
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.textSecondary))
                      : null,
                ))
          else if (text != null && text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(text,
                  style: GoogleFonts.dmSans(
                      fontSize: 14, color: AppColors.textPrimary)),
            ),
          if (result.structured?.tip != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(result.structured!.tip!,
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildGenericSections() {
    return _genericTips
        .map((section) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                shape: const Border(),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(section.icon, color: AppColors.brandBlue, size: 20),
                ),
                title: Text(section.title,
                    style: GoogleFonts.dmSans(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                children: section.tips
                    .map((t) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle,
                              color: AppColors.success, size: 18),
                          title: Text(t,
                              style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  color: AppColors.textPrimary)),
                        ))
                    .toList(),
              ),
            ))
        .toList();
  }
}

class _GenericSection {
  final String title;
  final IconData icon;
  final List<String> tips;
  const _GenericSection(this.title, this.icon, this.tips);
}
