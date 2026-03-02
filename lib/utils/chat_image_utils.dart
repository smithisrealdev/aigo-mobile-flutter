/// Utilities for extracting, normalizing, and replacing IMAGE placeholders
/// in AI chat responses. Mirrors web's src/lib/chatImageUtils.ts
library;

final _mdImageRegex = RegExp(r'!\[([^\]]*)\]\(IMAGE:([^)]+)\)');
final _brokenUrlRegex = RegExp(
  r'!\[([^\]]*)\]\((https?://[^\s)]*(?:unsplash|googleusercontent|placeholder)[^\s)]*)\)',
);

class ChatImageUtils {
  /// Extract IMAGE:query placeholders from markdown text.
  /// Returns list of search queries like ['Central Park', 'Times Square'].
  static List<String> extractImageQueries(String text) {
    return _mdImageRegex
        .allMatches(text)
        .map((m) => m.group(2) ?? '')
        .where((q) => q.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Check if text contains image references.
  static bool hasImages(String text) => _mdImageRegex.hasMatch(text);

  /// Replace IMAGE:query placeholders with cached URLs.
  /// Maintains markdown structure: ![query](cached_url)
  static String replaceWithCachedUrls(
    String text,
    Map<String, String> imageMap,
  ) {
    var result = text;
    for (final entry in imageMap.entries) {
      result = result.replaceAll('IMAGE:${entry.key}', entry.value);
    }
    return result;
  }

  /// Strip all image markdown, keeping place names as emoji references.
  /// Used as fallback when images are not loaded yet.
  static String stripImages(String text) {
    return text
        .replaceAllMapped(_mdImageRegex, (m) {
          final place = m.group(2) ?? m.group(1) ?? '';
          return place.isNotEmpty ? '📍 $place' : '';
        })
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Extract image URLs from standard markdown image syntax.
  /// Returns list of URLs from ![alt](url) patterns (non-IMAGE: ones).
  static List<String> extractResolvedImageUrls(String text) {
    final regex = RegExp(r'!\[([^\]]*)\]\((https?://[^\s)]+)\)');
    return regex
        .allMatches(text)
        .map((m) => m.group(2) ?? '')
        .where((u) => u.isNotEmpty && !u.startsWith('IMAGE:'))
        .toList();
  }

  /// Normalize broken/hallucinated image URLs to IMAGE: placeholders.
  static String normalizeEmptyImageUrls(String text) {
    return text.replaceAllMapped(_brokenUrlRegex, (m) {
      final alt = m.group(1) ?? 'image';
      return '![${alt}](IMAGE:$alt)';
    });
  }

  /// Remove all markdown image syntax from text.
  static String removeAllImages(String text) {
    return text
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
