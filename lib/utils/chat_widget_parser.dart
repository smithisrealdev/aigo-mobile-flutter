import '../models/chat/widget_models.dart';

class ChatWidgetParser {
  static ParsedWidgets parse(String text) {
    String cleanText = text;
    final flights = <FlightInfo>[];
    final hotels = <HotelInfo>[];
    final services = <ServiceInfo>[];
    final tickets = <TicketInfo>[];
    final collapsibleSections = <CollapsibleSection>[];
    BudgetSummaryInfo? budgetSummary;

    // Flights
    final flightBlockRegex = RegExp(
      r'\[FLIGHTS\]([\s\S]*?)\[\/FLIGHTS\]',
      multiLine: true,
    );
    for (final match in flightBlockRegex.allMatches(cleanText)) {
      final block = match.group(1) ?? '';

      final itemRegex = RegExp(
        r'\[FLIGHT(?:\s+([^\]]*))?\]([\s\S]*?)\[\/FLIGHT\]',
        multiLine: true,
      );
      for (final itemMatch in itemRegex.allMatches(block)) {
        final attrs = itemMatch.group(1) ?? '';
        final body = itemMatch.group(2)?.trim() ?? '';

        String getVal(String key) {
          final r1 = RegExp('$key:\\s*(.+)', caseSensitive: false);
          final m1 = r1.firstMatch(body);
          if (m1 != null) return m1.group(1)?.trim() ?? '';

          final r2 = RegExp('$key="([^"]+)"', caseSensitive: false);
          final m2 = r2.firstMatch(attrs);
          if (m2 != null) return m2.group(1)?.trim() ?? '';
          return '';
        }

        flights.add(
          FlightInfo(
            airline: getVal('airline'),
            iataCode: getVal('iata').isNotEmpty
                ? getVal('iata')
                : getVal('iataCode'),
            from: getVal('from'),
            to: getVal('to'),
            departure: getVal('departure').isNotEmpty
                ? getVal('departure')
                : getVal('depart'),
            arrival: getVal('arrival').isNotEmpty
                ? getVal('arrival')
                : getVal('arrive'),
            duration: getVal('duration'),
            price: getVal('price'),
            type: getVal('type').isNotEmpty
                ? getVal('type')
                : (getVal('stops').isNotEmpty ? getVal('stops') : 'direct'),
            searchUrl: getVal('url').isNotEmpty
                ? getVal('url')
                : getVal('searchUrl').isNotEmpty
                ? getVal('searchUrl')
                : null,
          ),
        );
      }
    }
    cleanText = cleanText.replaceAll(flightBlockRegex, '');

    // Hotels
    final hotelBlockRegex = RegExp(
      r'\[HOTELS\]([\s\S]*?)\[\/HOTELS\]',
      multiLine: true,
    );
    for (final match in hotelBlockRegex.allMatches(cleanText)) {
      final block = match.group(1) ?? '';

      final itemRegex = RegExp(
        r'\[HOTEL(?:\s+([^\]]*))?\]([\s\S]*?)\[\/HOTEL\]',
        multiLine: true,
      );
      for (final itemMatch in itemRegex.allMatches(block)) {
        final body = itemMatch.group(2)?.trim() ?? '';

        String getVal(String key) {
          final r = RegExp('$key:\\s*(.+)', caseSensitive: false);
          final m = r.firstMatch(body);
          return m != null ? m.group(1)?.trim() ?? '' : '';
        }

        final highlightsRaw = getVal('highlights').isNotEmpty
            ? getVal('highlights')
            : getVal('amenities');
        final highlights = highlightsRaw.isNotEmpty
            ? highlightsRaw
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
            : <String>[];

        hotels.add(
          HotelInfo(
            name: getVal('name'),
            area: getVal('area').isNotEmpty
                ? getVal('area')
                : getVal('location'),
            rating: getVal('rating').isNotEmpty
                ? getVal('rating')
                : getVal('stars'),
            price: getVal('price'),
            perNight: true,
            highlights: highlights,
            searchUrl: getVal('url').isNotEmpty
                ? getVal('url')
                : getVal('searchUrl').isNotEmpty
                ? getVal('searchUrl')
                : null,
            imageUrl: getVal('image').isNotEmpty
                ? getVal('image')
                : getVal('imageUrl').isNotEmpty
                ? getVal('imageUrl')
                : null,
            bookingUrl: getVal('booking').isNotEmpty
                ? getVal('booking')
                : getVal('bookingUrl').isNotEmpty
                ? getVal('bookingUrl')
                : null,
          ),
        );
      }
    }
    cleanText = cleanText.replaceAll(hotelBlockRegex, '');

    // Services
    final serviceBlockRegex = RegExp(
      r'\[SERVICES\]([\s\S]*?)\[\/SERVICES\]',
      multiLine: true,
    );
    for (final match in serviceBlockRegex.allMatches(cleanText)) {
      final block = match.group(1) ?? '';

      final itemRegex = RegExp(
        r'\[SERVICE\]([\s\S]*?)\[\/SERVICE\]',
        multiLine: true,
      );
      for (final itemMatch in itemRegex.allMatches(block)) {
        final body = itemMatch.group(1)?.trim() ?? '';

        String getVal(String key) {
          final r = RegExp(
            '$key:\\s*(.+?)(?=\\s+(?:type|name|description|price|provider|url):|\$)',
            caseSensitive: false,
            multiLine: true,
          );
          final m = r.firstMatch(body);
          return m != null ? m.group(1)?.trim() ?? '' : '';
        }

        final name = getVal('name');
        if (name.isEmpty) continue;

        var type = getVal('type').toLowerCase();
        if (type.isEmpty) type = 'other';

        services.add(
          ServiceInfo(
            name: name,
            type: type,
            description: getVal('description'),
            price: getVal('price'),
            provider: getVal('provider'),
            url: getVal('url'),
          ),
        );
      }
    }
    cleanText = cleanText.replaceAll(serviceBlockRegex, '');

    // Tickets
    final ticketBlockRegex = RegExp(
      r'\[TICKETS\]([\s\S]*?)\[\/TICKETS\]',
      multiLine: true,
    );
    for (final match in ticketBlockRegex.allMatches(cleanText)) {
      final block = match.group(1) ?? '';

      final parts = block.split(RegExp(r'\[TICKET\]'));
      for (final p in parts) {
        final body = p.replaceAll(RegExp(r'\[\/TICKET\]'), '').trim();
        if (body.isEmpty) continue;

        String getVal(String key) {
          final r = RegExp(
            '$key:\\s*(.+?)(?=\\s+(?:name|city|category|price|description|url):|}|\\[|\$)',
            caseSensitive: false,
            multiLine: true,
          );
          final m = r.firstMatch(body);
          return m != null ? m.group(1)?.trim() ?? '' : '';
        }

        final name = getVal('name');
        if (name.isEmpty) continue;

        tickets.add(
          TicketInfo(
            name: name,
            city: getVal('city'),
            category: getVal('category').isNotEmpty
                ? getVal('category')
                : 'attraction',
            price: getVal('price'),
            description: getVal('description'),
            url: getVal('url').isNotEmpty
                ? getVal('url')
                : 'https://www.tiqets.com/en/search?q=${Uri.encodeComponent('$name ${getVal('city')}')}',
          ),
        );
      }
    }
    cleanText = cleanText.replaceAll(ticketBlockRegex, '');

    // Budget Summary
    // Just extract the block to trigger the UI if needed
    final budgetBlockRegex = RegExp(
      r'\[BUDGET_SUMMARY\]([\s\S]*?)\[\/BUDGET_SUMMARY\]',
      multiLine: true,
    );
    for (final match in budgetBlockRegex.allMatches(cleanText)) {
      budgetSummary = BudgetSummaryInfo(match.group(1) ?? '');
    }
    cleanText = cleanText.replaceAll(budgetBlockRegex, '');

    // Collapsible Sections
    int sectionId = 0;

    void extractSections(
      RegExp regex,
      CollapsibleType type,
      int minLength,
      String Function(RegExpMatch) getTitle,
    ) {
      if (collapsibleSections.length >= 5) return;

      while (true) {
        if (collapsibleSections.length >= 5) break;
        final match = regex.firstMatch(cleanText);
        if (match == null) break;

        final fullMatch = match.group(0) ?? '';
        final sectionContent =
            (match.groupCount >= 4 ? match.group(4) : match.group(3)) ?? '';

        if (sectionContent.trim().length >= minLength) {
          final title = getTitle(match);
          if (!collapsibleSections.any((s) => s.title == title)) {
            collapsibleSections.add(
              CollapsibleSection(
                id: 'section-${sectionId++}',
                title: title,
                content: sectionContent.trim(),
                type: type,
              ),
            );
            // Replace with a placeholder to keep inline or just remove it.
            // In Flutter we'll just remove it and append sections at the end for simplicity,
            // or replace with an empty string and rely on the widget rendering them at the bottom.
            cleanText = cleanText.replaceFirst(fullMatch, '\n\n');
          } else {
            // Prevent infinite loop if already added (should not happen since we replaceFirst)
            cleanText = cleanText.replaceFirst(fullMatch, '\n\n');
          }
        } else {
          cleanText = cleanText.replaceFirst(fullMatch, '\n\n');
        }
      }
    }

    // Day
    extractSections(
      RegExp(
        r'(?:^|\n)(#{1,3}\s*)?(?:(?:Day|วันที่)\s*(\d+)[:\s]*([^\n]+))\n((?:(?!(?:Day|วันที่)\s*\d|^#{1,3}\s)[\s\S])*?)(?=(?:\n(?:Day|วันที่)\s*\d|\n#{1,3}\s|$))',
        caseSensitive: false,
      ),
      CollapsibleType.day,
      150,
      (m) =>
          'Day ${m.group(2)}${(m.group(3)?.trim().isNotEmpty ?? false) ? ': ${m.group(3)?.trim()}' : ''}',
    );

    // Restaurant
    extractSections(
      RegExp(
        r'(?:^|\n)(#{1,3}\s*)?(?:🍽️|🍜|🍣|🍱|🍛|🍲|Restaurant|ร้านอาหาร|Food|อาหาร)[:\s]*([^\n]+)\n((?:(?!^#{1,3}\s)[\s\S])*?)(?=(?:\n#{1,3}\s|$))',
        caseSensitive: false,
      ),
      CollapsibleType.restaurant,
      100,
      (m) => (m.group(2)?.trim().isNotEmpty ?? false)
          ? m.group(2)!.trim()
          : 'Restaurant Details',
    );

    // Transport
    extractSections(
      RegExp(
        r'(?:^|\n)(#{1,3}\s*)?(?:🚃|🚅|🚌|🚕|🚶|Transportation|การเดินทาง|How to get there|วิธีไป|Getting there|Route)[:\s]*([^\n]*)\n((?:(?!^#{1,3}\s)[\s\S])*?)(?=(?:\n#{1,3}\s|$))',
        caseSensitive: false,
      ),
      CollapsibleType.transport,
      100,
      (m) => (m.group(2)?.trim().isNotEmpty ?? false)
          ? m.group(2)!.trim()
          : 'Transportation Details',
    );

    // Accommodation
    extractSections(
      RegExp(
        r'(?:^|\n)(#{1,3}\s*)?(?:🏨|🛏️|Hotel|โรงแรม|Accommodation|ที่พัก|Where to stay)[:\s]*([^\n]*)\n((?:(?!^#{1,3}\s)[\s\S])*?)(?=(?:\n#{1,3}\s|$))',
        caseSensitive: false,
      ),
      CollapsibleType.accommodation,
      100,
      (m) => (m.group(2)?.trim().isNotEmpty ?? false)
          ? m.group(2)!.trim()
          : 'Accommodation Details',
    );

    // Details
    extractSections(
      RegExp(
        r'(?:^|\n)(#{1,3}\s*)?(?:📋|ℹ️|Details|รายละเอียด|More info|ข้อมูลเพิ่มเติม)[:\s]*([^\n]*)\n((?:(?!^#{1,3}\s)[\s\S])*?)(?=(?:\n#{1,3}\s|$))',
        caseSensitive: false,
      ),
      CollapsibleType.details,
      100,
      (m) => (m.group(2)?.trim().isNotEmpty ?? false)
          ? m.group(2)!.trim()
          : 'Additional Details',
    );

    return ParsedWidgets(
      flights: flights,
      hotels: hotels,
      services: services,
      tickets: tickets,
      budgetSummary: budgetSummary,
      collapsibleSections: collapsibleSections,
      cleanText: cleanText.trim(),
    );
  }
}
