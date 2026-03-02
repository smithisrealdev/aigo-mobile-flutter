class ChatParameterParser {
  /// Extracts text between specific markdown tags.
  static String extractTag(String text, String tag) {
    final exp = RegExp(
      '\\[$tag\\](.*?)\\[\\/$tag\\]',
      dotAll: true,
      caseSensitive: false,
    );
    return exp.firstMatch(text)?.group(1)?.trim() ?? '';
  }

  static String extractDestination(String text) =>
      extractTag(text, 'DESTINATION');
  static String extractDuration(String text) => extractTag(text, 'DURATION');
  static String extractBudget(String text) => extractTag(text, 'BUDGET');
  static String extractDates(String text) => extractTag(text, 'DATES');
  static String extractTravelers(String text) => extractTag(text, 'TRAVELERS');
}
