import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/chat/widget_models.dart';
import '../../theme/app_colors.dart';

class TicketWidget extends StatelessWidget {
  final List<TicketInfo> tickets;
  final bool isDark;

  const TicketWidget({super.key, required this.tickets, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) return const SizedBox.shrink();

    final bgColor = isDark
        ? const Color(0xFF2E2E2E).withValues(alpha: 0.5)
        : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF4B5563)
        : const Color(0xFFE5E7EB);
    final primaryColor = isDark ? AppColors.brandBlueDark : AppColors.brandBlue;
    final hoverBgColor = isDark
        ? primaryColor.withValues(alpha: 0.1)
        : primaryColor.withValues(alpha: 0.05);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_activity,
                size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Activity Tickets',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...tickets.map(
            (t) => _buildTicketCard(
              t,
              bgColor,
              borderColor,
              hoverBgColor,
              primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Powered by Tiqets • Prices are approximate',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(
    TicketInfo ticket,
    Color bgColor,
    Color borderColor,
    Color hoverBgColor,
    Color primaryColor,
  ) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark
        ? Colors.white70
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(ticket.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getCategoryIcon(ticket.category),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (ticket.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        ticket.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (ticket.city.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 10,
                            color: secondaryTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ticket.city,
                            style: TextStyle(
                              fontSize: 10,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (ticket.price.isNotEmpty)
                  Text(
                    ticket.price,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                const SizedBox(height: 4),
                Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: secondaryTextColor.withValues(alpha: 0.6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'museum':
        return '🏛️';
      case 'theme_park':
        return '🎢';
      case 'tour':
        return '🚶';
      case 'experience':
        return '✨';
      case 'landmark':
        return '🏰';
      case 'show':
        return '🎭';
      case 'attraction':
        return '🎫';
      default:
        return '🎫';
    }
  }
}
