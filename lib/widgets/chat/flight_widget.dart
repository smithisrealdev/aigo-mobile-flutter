import 'package:flutter/material.dart';

import '../../models/chat/widget_models.dart';
import '../../theme/app_colors.dart';

class FlightWidget extends StatelessWidget {
  final List<FlightInfo> flights;
  final bool isDark;

  const FlightWidget({super.key, required this.flights, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    if (flights.isEmpty) return const SizedBox.shrink();

    final bgColor = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
        : const Color(0xFFEFF6FF);
    final borderColor = isDark
        ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
        : const Color(0xFFBFDBFE);
    final headerTextColor = isDark
        ? const Color(0xFF93C5FD)
        : const Color(0xFF1D4ED8);
    final primaryTextColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark
        ? Colors.white70
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flight_takeoff, size: 16, color: Colors.blue.shade500),
              const SizedBox(width: 6),
              const Text(
                'FLIGHT OPTIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 10,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Estimated prices',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...flights.map(
            (flight) => _buildFlightCard(
              flight,
              bgColor,
              borderColor,
              headerTextColor,
              primaryTextColor,
              secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlightCard(
    FlightInfo flight,
    Color bgColor,
    Color borderColor,
    Color headerTextColor,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (flight.iataCode.isNotEmpty)
                    Image.network(
                      'https://images.kiwi.com/airlines/64/${flight.iataCode}.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.flight,
                        size: 24,
                        color: Colors.blue,
                      ),
                    )
                  else
                    const Icon(Icons.flight, size: 24, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    flight.airline,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: headerTextColor,
                    ),
                  ),
                ],
              ),
              _buildTypeBadge(flight.type, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      flight.departure,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    Text(
                      flight.from,
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          flight.duration,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(color: Colors.blue, thickness: 1),
                        ),
                        Icon(Icons.arrow_right, size: 16, color: Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      flight.arrival,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    Text(
                      flight.to,
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor.withValues(alpha: 0.5)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flight.price,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: headerTextColor,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb,
                          size: 10,
                          color: secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Estimated price',
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type, bool isDark) {
    if (type.toLowerCase() == 'return') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.orange.shade900.withValues(alpha: 0.3)
              : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '↩ Return',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
          ),
        ),
      );
    } else if (type.toLowerCase() == 'outbound') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.blue.shade900.withValues(alpha: 0.3)
              : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '✈ Outbound',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
          ),
        ),
      );
    }
    return Text(type, style: const TextStyle(fontSize: 12, color: Colors.grey));
  }
}
