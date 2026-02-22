// ──────────────────────────────────────────────
// PublicGuide model (mirrors `public_guides` table)
// ──────────────────────────────────────────────

class PublicGuide {
  final String id;
  final String title;
  final String? slug;
  final String? description;
  final String destination;
  final String? region;
  final String? authorName;
  final String? authorDate;
  final String? badge;
  final String? coverImage;
  final bool isFeatured;
  final int totalDays;
  final int views;
  final List<String> tags;
  final Map<String, dynamic>? itineraryData;
  final String? createdAt;
  final String? updatedAt;

  PublicGuide({
    required this.id,
    required this.title,
    this.slug,
    this.description,
    required this.destination,
    this.region,
    this.authorName,
    this.authorDate,
    this.badge,
    this.coverImage,
    this.isFeatured = false,
    this.totalDays = 1,
    this.views = 0,
    this.tags = const [],
    this.itineraryData,
    this.createdAt,
    this.updatedAt,
  });

  factory PublicGuide.fromJson(Map<String, dynamic> json) => PublicGuide(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        slug: json['slug'] as String?,
        description: json['description'] as String?,
        destination: json['destination'] as String? ?? '',
        region: json['region'] as String?,
        authorName: json['author_name'] as String?,
        authorDate: json['author_date'] as String?,
        badge: json['badge'] as String?,
        coverImage: json['cover_image'] as String?,
        isFeatured: json['is_featured'] as bool? ?? false,
        totalDays: json['total_days'] as int? ?? 1,
        views: json['views'] as int? ?? 0,
        tags: (json['tags'] as List?)?.cast<String>() ?? [],
        itineraryData: json['itinerary_data'] as Map<String, dynamic>?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );
}
