import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/chat/widget_models.dart';
import '../../theme/app_colors.dart';

class CollapsibleSectionWidget extends StatelessWidget {
  final CollapsibleSection section;
  final bool isDark;

  const CollapsibleSectionWidget({
    super.key,
    required this.section,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    Color bgColor;
    Color borderColor;

    switch (section.type) {
      case CollapsibleType.restaurant:
        icon = Icons.restaurant;
        iconColor = isDark ? Colors.orange[400]! : Colors.orange[600]!;
        bgColor = isDark
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.orange[50]!;
        borderColor = isDark
            ? Colors.orange.withValues(alpha: 0.2)
            : Colors.orange[200]!;
        break;
      case CollapsibleType.transport:
        icon = Icons.directions_transit;
        iconColor = isDark ? Colors.blue[400]! : Colors.blue[600]!;
        bgColor = isDark
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.blue[50]!;
        borderColor = isDark
            ? Colors.blue.withValues(alpha: 0.2)
            : Colors.blue[200]!;
        break;
      case CollapsibleType.day:
        icon = Icons.calendar_today_outlined;
        iconColor = isDark ? Colors.deepPurple[400]! : Colors.deepPurple[600]!;
        bgColor = isDark
            ? Colors.deepPurple.withValues(alpha: 0.1)
            : Colors.deepPurple[50]!;
        borderColor = isDark
            ? Colors.deepPurple.withValues(alpha: 0.2)
            : Colors.deepPurple[200]!;
        break;
      case CollapsibleType.accommodation:
        icon = Icons.hotel;
        iconColor = isDark ? Colors.teal[400]! : Colors.teal[600]!;
        bgColor = isDark
            ? Colors.teal.withValues(alpha: 0.1)
            : Colors.teal[50]!;
        borderColor = isDark
            ? Colors.teal.withValues(alpha: 0.2)
            : Colors.teal[200]!;
        break;
      case CollapsibleType.details:
        icon = Icons.info_outline;
        iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
        bgColor = isDark
            ? Colors.grey.withValues(alpha: 0.1)
            : Colors.grey[50]!;
        borderColor = isDark
            ? Colors.grey.withValues(alpha: 0.2)
            : Colors.grey[200]!;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent, // remove ExpansionTile borders
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            childrenPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white60,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            title: Text(
              section.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            iconColor: isDark ? Colors.white54 : AppColors.textSecondary,
            collapsedIconColor: isDark
                ? Colors.white54
                : AppColors.textSecondary,
            children: [
              Container(
                margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  border: Border(
                    left: BorderSide(color: borderColor, width: 3),
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                    bottomLeft: Radius.circular(4),
                    topLeft: Radius.circular(4),
                  ),
                ),
                child: MarkdownBody(
                  data: section.content,
                  selectable: true,
                  styleSheet: _buildStyle(context),
                  onTapLink: (text, href, title) {
                    if (href != null) {
                      launchUrl(
                        Uri.parse(href),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildStyle(BuildContext context) {
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.9)
        : AppColors.textPrimary.withValues(alpha: 0.9);
    final codeBackground = isDark
        ? const Color(0xFF2E2E2E)
        : const Color(0xFFF5F5F5);

    return MarkdownStyleSheet(
      p: TextStyle(color: textColor, fontSize: 13, height: 1.5),
      h1: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      h2: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      h3: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      strong: TextStyle(fontWeight: FontWeight.w700, color: textColor),
      em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: isDark ? const Color(0xFFE5C07B) : const Color(0xFFE01E5A),
        backgroundColor: codeBackground,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(8),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
      blockquote: TextStyle(
        color: textColor.withValues(alpha: 0.7),
        fontSize: 13,
        fontStyle: FontStyle.italic,
      ),
      listBullet: TextStyle(color: textColor, fontSize: 13),
      listIndent: 20,
      a: TextStyle(
        color: AppColors.brandBlue,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.brandBlue.withValues(alpha: 0.4),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
    );
  }
}
