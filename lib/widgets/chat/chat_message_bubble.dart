import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../utils/chat_image_utils.dart';
import '../../utils/info_box_detector.dart';
import '../../utils/summary_card_extractor.dart';
import 'chat_image_gallery.dart';
import 'code_block_widget.dart';
import 'smart_info_box.dart';
import 'summary_card_widget.dart';
import 'flight_widget.dart';
import 'hotel_widget.dart';
import 'service_widget.dart';
import 'ticket_widget.dart';
import 'budget_summary_widget.dart';
import 'collapsible_section_widget.dart';
import '../../utils/chat_widget_parser.dart';

/// Rich AI message bubble with markdown, images, info boxes, summary cards.
/// Replaces the old plain Text widget for AI responses.
class ChatMessageBubble extends StatelessWidget {
  final String content;
  final List<String> resolvedImageUrls;
  final bool isDark;

  const ChatMessageBubble({
    super.key,
    required this.content,
    this.resolvedImageUrls = const [],
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Parse domain widgets (Flights, Hotels, Services, Tickets, Budget)
    final parsedWidgets = ChatWidgetParser.parse(content);
    var displayText = parsedWidgets.cleanText;

    // 2. Extract info boxes
    final extracted = InfoBoxDetector.extractInfoBoxes(displayText);
    final infoBoxes = extracted.boxes;
    displayText = extracted.remainingText;

    // 3. Extract summary card
    final summaryCard = SummaryCardExtractor.extract(displayText);

    // 4. Extract code blocks for custom rendering
    final codeBlocks = _extractCodeBlocks(displayText);
    var markdownText = _removeCodeBlocks(displayText);

    // 5. Clean up IMAGE: placeholders from markdown display
    // If we have resolved URLs, show gallery separately
    if (resolvedImageUrls.isNotEmpty) {
      markdownText = ChatImageUtils.removeAllImages(markdownText);
    } else {
      // Strip IMAGE: placeholders to just place names
      markdownText = ChatImageUtils.stripImages(markdownText);
    }

    // 6. Clean markers
    markdownText = markdownText
        .replaceAll(RegExp(r'\[TRIP_SUMMARY\][\s\S]*?\[/TRIP_SUMMARY\]'), '')
        .replaceAll('[READY_TO_GENERATE]', '')
        .replaceAll(RegExp(r'<<<AIGO_PATCH>>>[\s\S]*?<<<AIGO_PATCH>>>'), '')
        .replaceAll(
          RegExp(r'<<<AIGO_SUGGESTIONS>>>[\s\S]*?<<<AIGO_SUGGESTIONS>>>'),
          '',
        )
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Domain widgets
        if (parsedWidgets.flights.isNotEmpty)
          FlightWidget(flights: parsedWidgets.flights, isDark: isDark),
        if (parsedWidgets.hotels.isNotEmpty)
          HotelWidget(hotels: parsedWidgets.hotels, isDark: isDark),
        if (parsedWidgets.services.isNotEmpty)
          ServiceWidget(services: parsedWidgets.services, isDark: isDark),
        if (parsedWidgets.tickets.isNotEmpty)
          TicketWidget(tickets: parsedWidgets.tickets, isDark: isDark),
        if (parsedWidgets.budgetSummary != null)
          BudgetSummaryWidget(
            budgetInfo: parsedWidgets.budgetSummary!,
            isDark: isDark,
          ),

        // Summary card (if extracted)
        if (summaryCard != null) SummaryCardWidget(data: summaryCard),

        // Info boxes
        ...infoBoxes.map((box) => SmartInfoBox(data: box)),

        // Main markdown text
        if (markdownText.isNotEmpty)
          MarkdownBody(
            data: markdownText,
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

        // Code blocks with syntax highlighting
        ...codeBlocks.map(
          (block) =>
              CodeBlockWidget(code: block.code, language: block.language),
        ),

        // Collapsible sections
        if (parsedWidgets.collapsibleSections.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: isDark ? Colors.white54 : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tap sections for details',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white54
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...parsedWidgets.collapsibleSections.map(
                  (section) => CollapsibleSectionWidget(
                    section: section,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),

        // Image gallery
        if (resolvedImageUrls.isNotEmpty)
          ChatImageGallery(imageUrls: resolvedImageUrls),
      ],
    );
  }

  MarkdownStyleSheet _buildStyle(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final codeBackground = isDark
        ? const Color(0xFF2E2E2E)
        : const Color(0xFFF5F5F5);

    return MarkdownStyleSheet(
      p: TextStyle(color: textColor, fontSize: 15, height: 1.6),
      h1: TextStyle(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      h2: TextStyle(
        color: textColor,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      h3: TextStyle(
        color: textColor,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      strong: TextStyle(fontWeight: FontWeight.w700, color: textColor),
      em: TextStyle(fontStyle: FontStyle.italic, color: textColor),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: isDark ? const Color(0xFFE5C07B) : const Color(0xFFE01E5A),
        backgroundColor: codeBackground,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      blockquote: TextStyle(
        color: textColor.withValues(alpha: 0.7),
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
      listBullet: TextStyle(color: textColor, fontSize: 15),
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

  // ── Code block extraction ──

  static final _codeBlockRegex = RegExp(r'```(\w*)\n([\s\S]*?)```');

  List<_CodeBlock> _extractCodeBlocks(String text) {
    return _codeBlockRegex.allMatches(text).map((m) {
      return _CodeBlock(
        language: m.group(1)?.isNotEmpty == true ? m.group(1) : null,
        code: m.group(2)?.trimRight() ?? '',
      );
    }).toList();
  }

  String _removeCodeBlocks(String text) {
    return text.replaceAll(_codeBlockRegex, '').trim();
  }
}

class _CodeBlock {
  final String? language;
  final String code;
  const _CodeBlock({this.language, required this.code});
}
