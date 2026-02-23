import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../services/trip_service.dart';
import '../services/weather_service.dart';
import '../services/exchange_rate_service.dart';

class TripSummaryScreen extends StatefulWidget {
  final Trip? trip;
  const TripSummaryScreen({super.key, this.trip});

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  Trip? _trip;
  Map<String, dynamic> _readiness = {};
  WeatherResponse? _weather;
  ConversionResult? _exchangeRate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    if (_trip == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final futures = await Future.wait([
        TripService.instance.checkTripReadiness(_trip!.id),
        _loadWeather(),
        _loadExchangeRate(),
      ]);
      setState(() {
        _readiness = futures[0] as Map<String, dynamic>;
        _weather = futures[1] as WeatherResponse?;
        _exchangeRate = futures[2] as ConversionResult?;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<WeatherResponse?> _loadWeather() async {
    // Use a geocoding approach or hardcoded coords — for now use edge function
    // The weather service needs lat/lon, so we pass approximate coords
    try {
      return await WeatherService.instance.getForecast(0, 0);
    } catch (_) {
      return null;
    }
  }

  Future<ConversionResult?> _loadExchangeRate() async {
    final trip = _trip;
    if (trip == null || trip.budgetCurrency == null) return null;
    try {
      return await ExchangeRateService.instance.convertToHomeCurrency(
        amount: 1,
        fromCurrency: trip.budgetCurrency!,
        homeCurrency: 'USD',
      );
    } catch (_) {
      return null;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'TBD';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'completed':
        return 'COMPLETED';
      case 'active':
        return 'ACTIVE';
      case 'draft':
        return 'DRAFT';
      default:
        return 'UPCOMING';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'active':
        return AppColors.brandBlue;
      case 'draft':
        return AppColors.textSecondary;
      default:
        return AppColors.warning;
    }
  }

  int get _tripDays {
    final trip = _trip;
    if (trip?.startDate == null || trip?.endDate == null) return 0;
    final s = DateTime.tryParse(trip!.startDate!);
    final e = DateTime.tryParse(trip.endDate!);
    if (s == null || e == null) return 0;
    return e.difference(s).inDays;
  }

  int get _activityCount {
    final data = _trip?.itineraryData;
    if (data == null) return 0;
    final days = data['days'] as List?;
    if (days == null) return 0;
    int count = 0;
    for (final day in days) {
      if (day is Map) {
        final activities = day['activities'] as List?;
        count += activities?.length ?? 0;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;

    if (trip == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('No trip selected',
              style: GoogleFonts.dmSans(color: AppColors.textSecondary)),
        ),
      );
    }

    final budgetTotal = trip.budgetTotal ?? 0;
    final budgetSpent = trip.budgetSpent ?? 0;
    final budgetProgress =
        budgetTotal > 0 ? (budgetSpent / budgetTotal).clamp(0.0, 1.0) : 0.0;
    final readinessScore = _readiness['score'] as num? ?? 0;
    final currency = trip.budgetCurrency ?? 'USD';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero header
            Stack(
              children: [
                if (trip.coverImage != null)
                  CachedNetworkImage(
                    imageUrl: trip.coverImage!,
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      height: 260,
                      decoration:
                          const BoxDecoration(color: AppColors.brandBlue),
                    ),
                  )
                else
                  Container(
                    height: 260,
                    decoration:
                        const BoxDecoration(color: AppColors.brandBlue),
                  ),
                Container(
                  height: 260,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios,
                                color: Colors.white),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.white),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(trip.status),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_statusLabel(trip.status),
                            style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                      ),
                      const SizedBox(height: 8),
                      Text(trip.title,
                          style: GoogleFonts.dmSans(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Text(trip.destination,
                              style: GoogleFonts.dmSans(
                                  color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatDate(trip.startDate)} - ${_formatDate(trip.endDate)}',
                        style: GoogleFonts.dmSans(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('$_tripDays', 'Days', Icons.calendar_today),
                        _stat('$_activityCount', 'Activities',
                            Icons.place),
                        _stat(
                            '${getCurrencySymbol(currency)}${budgetTotal.toInt()}',
                            'Budget',
                            Icons.account_balance_wallet),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Budget progress
                  if (budgetTotal > 0)
                    _card(
                      'Budget',
                      Icons.account_balance_wallet,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Spent: ${getCurrencySymbol(currency)}${budgetSpent.toInt()}',
                                style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'of ${getCurrencySymbol(currency)}${budgetTotal.toInt()}',
                                style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: budgetProgress,
                              backgroundColor: AppColors.border,
                              valueColor: AlwaysStoppedAnimation(
                                  budgetProgress > 0.9
                                      ? AppColors.error
                                      : AppColors.brandBlue),
                              minHeight: 8,
                            ),
                          ),
                          if (_exchangeRate != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.currency_exchange,
                                    size: 14,
                                    color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  '1 $currency = ${_exchangeRate!.rate.toStringAsFixed(2)} USD',
                                  style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Trip Readiness
                  if (!_loading)
                    _card(
                      'Trip Readiness',
                      Icons.verified,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CircularProgressIndicator(
                                      value: readinessScore / 100,
                                      backgroundColor: AppColors.border,
                                      valueColor: AlwaysStoppedAnimation(
                                          readinessScore >= 80
                                              ? AppColors.success
                                              : readinessScore >= 50
                                                  ? AppColors.warning
                                                  : AppColors.error),
                                      strokeWidth: 5,
                                      strokeCap: StrokeCap.round,
                                    ),
                                    Center(
                                      child: Text(
                                        '${readinessScore.toInt()}%',
                                        style: GoogleFonts.dmSans(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  readinessScore >= 80
                                      ? 'Your trip is well prepared!'
                                      : readinessScore >= 50
                                          ? 'Almost there, a few things to check'
                                          : 'Several items need attention',
                                  style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          if (_readiness['missing'] is List) ...[
                            const SizedBox(height: 12),
                            ...(_readiness['missing'] as List)
                                .take(3)
                                .map((item) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(
                                              Icons.warning_amber,
                                              size: 16,
                                              color: AppColors.warning),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.toString(),
                                              style: GoogleFonts.dmSans(
                                                  fontSize: 13,
                                                  color: AppColors
                                                      .textSecondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Weather
                  if (_weather?.forecast != null &&
                      _weather!.forecast!.isNotEmpty)
                    _card(
                      'Weather Forecast',
                      Icons.cloud,
                      child: SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _weather!.forecast!.length.clamp(0, 5),
                          itemBuilder: (_, i) {
                            final f = _weather!.forecast![i];
                            return Container(
                              width: 64,
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    f.date.length >= 10
                                        ? f.date.substring(5, 10)
                                        : f.date,
                                    style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                                  Icon(
                                    f.precipitationProbability > 50
                                        ? Icons.grain
                                        : Icons.wb_sunny,
                                    size: 20,
                                    color: f.precipitationProbability > 50
                                        ? AppColors.brandBlue
                                        : AppColors.warning,
                                  ),
                                  Text(
                                    '${f.tempMax.toInt()}',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          'View Itinerary',
                          Icons.map,
                          () => context.push('/itinerary', extra: trip),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionButton(
                          'AI Chat',
                          Icons.chat,
                          () => context.push('/ai-chat',
                              extra:
                                  'Tell me about my trip to ${trip.destination}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _actionButton(
                      'Share Trip',
                      Icons.share,
                      () {},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.brandBlue, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _card(String title, IconData icon, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.brandBlue, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.dmSans(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.brandBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
