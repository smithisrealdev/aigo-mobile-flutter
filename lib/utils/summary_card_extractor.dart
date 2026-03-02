/// Extracts trip summary information from AI responses for visual cards.
/// Mirrors web's ChatMessage.tsx summary card extraction.
library;

class TripSummaryCard {
  final String? destination;
  final String? flag;
  final String? duration;
  final String? budget;
  final String? weather;
  final String? travelers;
  final String? season;

  const TripSummaryCard({
    this.destination,
    this.flag,
    this.duration,
    this.budget,
    this.weather,
    this.travelers,
    this.season,
  });

  bool get hasData =>
      destination != null ||
      duration != null ||
      budget != null ||
      weather != null ||
      travelers != null;
}

class SummaryCardExtractor {
  // Country → flag emoji mapping (common destinations)
  static const _countryFlags = {
    'japan': '🇯🇵', 'tokyo': '🇯🇵', 'kyoto': '🇯🇵', 'osaka': '🇯🇵',
    'thailand': '🇹🇭', 'bangkok': '🇹🇭', 'chiang mai': '🇹🇭', 'phuket': '🇹🇭',
    'france': '🇫🇷', 'paris': '🇫🇷',
    'italy': '🇮🇹', 'rome': '🇮🇹', 'milan': '🇮🇹', 'venice': '🇮🇹',
    'spain': '🇪🇸', 'barcelona': '🇪🇸', 'madrid': '🇪🇸',
    'korea': '🇰🇷', 'seoul': '🇰🇷',
    'vietnam': '🇻🇳', 'hanoi': '🇻🇳',
    'indonesia': '🇮🇩', 'bali': '🇮🇩',
    'singapore': '🇸🇬',
    'usa': '🇺🇸', 'new york': '🇺🇸', 'los angeles': '🇺🇸',
    'uk': '🇬🇧', 'london': '🇬🇧',
    'australia': '🇦🇺', 'sydney': '🇦🇺',
    'greece': '🇬🇷', 'santorini': '🇬🇷',
    'turkey': '🇹🇷', 'istanbul': '🇹🇷',
    'germany': '🇩🇪', 'berlin': '🇩🇪',
    'malaysia': '🇲🇾', 'kuala lumpur': '🇲🇾',
    'philippines': '🇵🇭', 'manila': '🇵🇭',
    'portugal': '🇵🇹', 'lisbon': '🇵🇹',
    'switzerland': '🇨🇭', 'zurich': '🇨🇭',
    'maldives': '🇲🇻',
    'egypt': '🇪🇬', 'cairo': '🇪🇬',
    'morocco': '🇲🇦', 'marrakech': '🇲🇦',
    'india': '🇮🇳', 'delhi': '🇮🇳',
    'china': '🇨🇳', 'beijing': '🇨🇳', 'shanghai': '🇨🇳',
    'taiwan': '🇹🇼', 'taipei': '🇹🇼',
    'hong kong': '🇭🇰',
    'cambodia': '🇰🇭', 'siem reap': '🇰🇭',
    'laos': '🇱🇦', 'vientiane': '🇱🇦',
    'myanmar': '🇲🇲', 'nepal': '🇳🇵',
    'sri lanka': '🇱🇰',
    'new zealand': '🇳🇿',
    'canada': '🇨🇦',
    'mexico': '🇲🇽',
    'brazil': '🇧🇷',
    'argentina': '🇦🇷',
    'peru': '🇵🇪',
    'colombia': '🇨🇴',
    'czech republic': '🇨🇿', 'prague': '🇨🇿',
    'austria': '🇦🇹', 'vienna': '🇦🇹',
    'netherlands': '🇳🇱', 'amsterdam': '🇳🇱',
    'croatia': '🇭🇷', 'dubrovnik': '🇭🇷',
    'iceland': '🇮🇸',
    'norway': '🇳🇴',
    'sweden': '🇸🇪',
    'denmark': '🇩🇰',
    'finland': '🇫🇮',
  };

  static String? _getFlag(String? destination) {
    if (destination == null) return null;
    final lower = destination.toLowerCase();
    for (final entry in _countryFlags.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return '📍';
  }

  /// Extract trip summary data from AI response text.
  static TripSummaryCard? extract(String text) {
    String? destination;
    String? duration;
    String? budget;
    String? weather;
    String? travelers;
    String? season;

    // Destination patterns
    final destMatch = RegExp(
      r'(?:Destination|จุดหมาย|สถานที่)\s*:?\s*([^\n,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (destMatch != null) destination = destMatch.group(1)?.trim();

    // Duration patterns (English + Thai)
    final durMatch = RegExp(
      r'(?:Duration|ระยะเวลา)\s*:?\s*(\d+)\s*(?:days?|วัน|nights?|คืน)',
      caseSensitive: false,
    ).firstMatch(text);
    if (durMatch != null) {
      final num = durMatch.group(1);
      final unit = text.substring(durMatch.start, durMatch.end).toLowerCase();
      duration = unit.contains('night') || unit.contains('คืน')
          ? '$num nights'
          : '$num days';
    }
    // Fallback: "X days Y nights" pattern
    if (durMatch == null) {
      final fallback = RegExp(r'(\d+)\s*(?:days?|วัน)(?:\s*(?:\/|and|&)\s*(\d+)\s*(?:nights?|คืน))?',
          caseSensitive: false).firstMatch(text);
      if (fallback != null) {
        final d = fallback.group(1);
        final n = fallback.group(2);
        duration = n != null ? '${d}D/${n}N' : '$d days';
      }
    }

    // Budget patterns
    final budgetMatch = RegExp(
      r'(?:Budget|งบ(?:ประมาณ)?)\s*:?\s*([\$€£฿]?\s*[\d,]+(?:\s*[-–]\s*[\$€£฿]?\s*[\d,]+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (budgetMatch != null) budget = budgetMatch.group(1)?.trim();

    // Weather/temperature patterns
    final weatherMatch = RegExp(
      r'(?:Weather|อากาศ|Temperature|อุณหภูมิ)\s*:?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (weatherMatch != null) weather = weatherMatch.group(1)?.trim();

    // Travelers patterns
    final travelersMatch = RegExp(
      r'(?:Travelers?|ผู้เดินทาง|คน)\s*:?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (travelersMatch != null) travelers = travelersMatch.group(1)?.trim();

    // Season patterns
    final seasonMatch = RegExp(
      r'(?:Season|ฤดู|Best time)\s*:?\s*([^\n]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (seasonMatch != null) season = seasonMatch.group(1)?.trim();

    final card = TripSummaryCard(
      destination: destination,
      flag: _getFlag(destination),
      duration: duration,
      budget: budget,
      weather: weather,
      travelers: travelers,
      season: season,
    );

    return card.hasData ? card : null;
  }
}
