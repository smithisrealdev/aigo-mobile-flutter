import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/price_alert_service.dart';
import '../theme/app_colors.dart';

/// Price alert widget — set target price, toggle on/off, see sparkline.
class PriceAlertWidget extends ConsumerStatefulWidget {
  /// 'flight' or 'hotel'
  final String type;

  /// For flight alerts
  final String? originCode;
  final String? destinationCode;
  final String? departureDate;
  final String? returnDate;

  /// For hotel alerts
  final String? hotelName;
  final String? destination;
  final String? checkInDate;
  final String? checkOutDate;

  /// Current known price
  final double? currentPrice;
  final String? currency;

  const PriceAlertWidget({
    super.key,
    required this.type,
    this.originCode,
    this.destinationCode,
    this.departureDate,
    this.returnDate,
    this.hotelName,
    this.destination,
    this.checkInDate,
    this.checkOutDate,
    this.currentPrice,
    this.currency,
  });

  @override
  ConsumerState<PriceAlertWidget> createState() => _PriceAlertWidgetState();
}

class _PriceAlertWidgetState extends ConsumerState<PriceAlertWidget> {
  final _priceController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _createAlert() async {
    final target = double.tryParse(_priceController.text);
    setState(() => _creating = true);

    if (widget.type == 'flight') {
      await PriceAlertService.instance.createFlightAlert(
        originCode: widget.originCode ?? '',
        destinationCode: widget.destinationCode ?? '',
        departureDate: widget.departureDate ?? '',
        returnDate: widget.returnDate,
        targetPrice: target,
      );
      ref.invalidate(flightAlertsProvider);
    } else {
      await PriceAlertService.instance.createHotelAlert(
        hotelName: widget.hotelName ?? '',
        destination: widget.destination ?? '',
        checkInDate: widget.checkInDate ?? '',
        checkOutDate: widget.checkOutDate ?? '',
        targetPrice: target,
      );
      ref.invalidate(hotelAlertsProvider);
    }

    _priceController.clear();
    setState(() => _creating = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price alert created!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.notifications_active,
                size: 18, color: AppColors.brandBlue),
            const SizedBox(width: 8),
            const Text('Set Price Alert',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (widget.currentPrice != null) ...[
              const Icon(Icons.trending_down,
                  size: 14, color: AppColors.success),
              const SizedBox(width: 4),
              Text(
                '${widget.currency ?? '\$'}${widget.currentPrice!.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Target price',
                  prefixText: widget.currency ?? '\$ ',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _creating ? null : _createAlert,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Alert Me', style: TextStyle(fontSize: 13)),
            ),
          ]),
          // Mini sparkline placeholder — shows price history
          const SizedBox(height: 8),
          _SparklinePreview(type: widget.type),
        ],
      ),
    );
  }
}

/// Shows existing alerts with toggle.
class PriceAlertsList extends ConsumerWidget {
  final String type; // 'flight' or 'hotel'
  const PriceAlertsList({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (type == 'flight') {
      final alertsAsync = ref.watch(flightAlertsProvider);
      return alertsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (alerts) {
          if (alerts.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Flight Alerts',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...alerts.map((a) => _FlightAlertTile(alert: a)),
            ],
          );
        },
      );
    } else {
      final alertsAsync = ref.watch(hotelAlertsProvider);
      return alertsAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (alerts) {
          if (alerts.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Hotel Alerts',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...alerts.map((a) => _HotelAlertTile(alert: a)),
            ],
          );
        },
      );
    }
  }
}

class _FlightAlertTile extends ConsumerWidget {
  final FlightPriceAlert alert;
  const _FlightAlertTile({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${alert.originCode} → ${alert.destinationCode}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              if (alert.lastKnownPrice != null)
                Text(
                  '${alert.lastKnownCurrency ?? '\$'}${alert.lastKnownPrice!.toStringAsFixed(0)}'
                  '${alert.targetPrice != null ? ' / target: ${alert.targetPrice!.toStringAsFixed(0)}' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        Switch(
          value: alert.isActive,
          activeThumbColor: AppColors.brandBlue,
          onChanged: (v) async {
            await PriceAlertService.instance
                .toggleFlightAlert(alert.id, v);
            ref.invalidate(flightAlertsProvider);
          },
        ),
      ]),
    );
  }
}

class _HotelAlertTile extends ConsumerWidget {
  final HotelPriceAlert alert;
  const _HotelAlertTile({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(alert.hotelName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              if (alert.lastKnownPrice != null)
                Text(
                  '${alert.lastKnownCurrency ?? '\$'}${alert.lastKnownPrice!.toStringAsFixed(0)}'
                  '${alert.targetPrice != null ? ' / target: ${alert.targetPrice!.toStringAsFixed(0)}' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        Switch(
          value: alert.isActive,
          activeThumbColor: AppColors.brandBlue,
          onChanged: (v) async {
            await PriceAlertService.instance
                .toggleHotelAlert(alert.id, v);
            ref.invalidate(hotelAlertsProvider);
          },
        ),
      ]),
    );
  }
}

/// Simple sparkline placeholder using CustomPaint.
class _SparklinePreview extends ConsumerWidget {
  final String type;
  const _SparklinePreview({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Just a subtle hint — real sparkline data loaded lazily
    return SizedBox(
      height: 24,
      child: CustomPaint(
        size: const Size(double.infinity, 24),
        painter: _SparklinePainter(),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Placeholder sparkline
    final paint = Paint()
      ..color = AppColors.brandBlue.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = [0.7, 0.5, 0.6, 0.4, 0.3, 0.45, 0.35, 0.25];
    for (var i = 0; i < points.length; i++) {
      final x = i * size.width / (points.length - 1);
      final y = points[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
