import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/chat/widget_models.dart';
import '../../theme/app_colors.dart';

class ServiceWidget extends StatelessWidget {
  final List<ServiceInfo> services;
  final bool isDark;

  const ServiceWidget({super.key, required this.services, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();

    // Group services by type label
    final grouped = <String, List<ServiceInfo>>{};
    for (final s in services) {
      final label = _getLabelForType(s.type);
      grouped.putIfAbsent(label, () => []).add(s);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...grouped.entries.map(
            (entry) => _buildServiceGroup(entry.key, entry.value),
          ),
          Center(
            child: Text(
              'Powered by AiGo Partners • Prices are approximate',
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceGroup(String label, List<ServiceInfo> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _getEmojiForLabel(label),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((s) => _buildServiceCard(s)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildServiceCard(ServiceInfo service) {
    final colorKey = _getColorForType(service.type);
    final bgColor = _getBgColor(colorKey, isDark);
    final borderColor = _getBorderColor(colorKey, isDark);
    final iconColor = _getIconColor(colorKey, isDark);
    final primaryTextColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark
        ? Colors.white70
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(service.url);
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
            Icon(_getIconForType(service.type), size: 16, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  if (service.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        service.description,
                        style: TextStyle(
                          fontSize: 10,
                          color: secondaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (service.price.isNotEmpty)
              Row(
                children: [
                  Text(
                    service.price,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 12, color: secondaryTextColor),
                ],
              )
            else
              Icon(Icons.open_in_new, size: 12, color: secondaryTextColor),
          ],
        ),
      ),
    );
  }

  String _getLabelForType(String type) {
    switch (type.toLowerCase()) {
      case 'car rental':
        return 'Car Rental';
      case 'bike rental':
        return 'Bike Rental';
      case 'insurance':
        return 'Insurance';
      case 'esim':
        return 'eSIM';
      case 'sim card':
        return 'SIM Card';
      case 'cruise':
        return 'Cruise/Ferry';
      case 'transfer':
        return 'Transfer';
      case 'train':
        return 'Train';
      case 'bus':
        return 'Bus';
      default:
        return 'Service';
    }
  }

  String _getEmojiForLabel(String label) {
    if (label == 'eSIM' || label == 'SIM Card') return '📱';
    if (label == 'Insurance') return '🛡️';
    if (label == 'Car Rental' || label == 'Bike Rental') return '🚗';
    if (label == 'Cruise/Ferry') return '🚢';
    return '🚌';
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'car rental':
      case 'bike rental':
        return Icons.directions_car;
      case 'insurance':
        return Icons.security;
      case 'esim':
      case 'sim card':
        return Icons.smartphone;
      case 'cruise':
        return Icons.directions_boat;
      case 'transfer':
        return Icons.directions_bus;
      case 'train':
        return Icons.train;
      case 'bus':
        return Icons.directions_bus;
      default:
        return Icons.local_offer;
    }
  }

  String _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'car rental':
        return 'blue';
      case 'bike rental':
        return 'green';
      case 'insurance':
        return 'red';
      case 'esim':
      case 'sim card':
        return 'purple';
      case 'cruise':
        return 'cyan';
      case 'transfer':
        return 'orange';
      case 'train':
      case 'bus':
        return 'amber';
      default:
        return 'blue';
    }
  }

  Color _getBgColor(String colorKey, bool isDark) {
    switch (colorKey) {
      case 'blue':
        return isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
            : const Color(0xFFEFF6FF);
      case 'green':
        return isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.2)
            : const Color(0xFFECFDF5);
      case 'red':
        return isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.2)
            : const Color(0xFFFEF2F2);
      case 'purple':
        return isDark
            ? const Color(0xFF581C87).withValues(alpha: 0.2)
            : const Color(0xFFFAF5FF);
      case 'cyan':
        return isDark
            ? const Color(0xFF164E63).withValues(alpha: 0.2)
            : const Color(0xFFECFEFF);
      case 'orange':
        return isDark
            ? const Color(0xFF7C2D12).withValues(alpha: 0.2)
            : const Color(0xFFFFF7ED);
      case 'amber':
        return isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.2)
            : const Color(0xFFFFFBEB);
      default:
        return isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.2)
            : const Color(0xFFEFF6FF);
    }
  }

  Color _getBorderColor(String colorKey, bool isDark) {
    switch (colorKey) {
      case 'blue':
        return isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
            : const Color(0xFFBFDBFE);
      case 'green':
        return isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.5)
            : const Color(0xFFA7F3D0);
      case 'red':
        return isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.5)
            : const Color(0xFFFECACA);
      case 'purple':
        return isDark
            ? const Color(0xFF581C87).withValues(alpha: 0.5)
            : const Color(0xFFE9D5FF);
      case 'cyan':
        return isDark
            ? const Color(0xFF164E63).withValues(alpha: 0.5)
            : const Color(0xFFA5F3FC);
      case 'orange':
        return isDark
            ? const Color(0xFF7C2D12).withValues(alpha: 0.5)
            : const Color(0xFFFED7AA);
      case 'amber':
        return isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.5)
            : const Color(0xFFFDE68A);
      default:
        return isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
            : const Color(0xFFBFDBFE);
    }
  }

  Color _getIconColor(String colorKey, bool isDark) {
    switch (colorKey) {
      case 'blue':
        return Colors.blue.shade500;
      case 'green':
        return Colors.green.shade500;
      case 'red':
        return Colors.red.shade500;
      case 'purple':
        return Colors.purple.shade500;
      case 'cyan':
        return Colors.cyan.shade500;
      case 'orange':
        return Colors.orange.shade500;
      case 'amber':
        return Colors.amber.shade500;
      default:
        return Colors.blue.shade500;
    }
  }
}
