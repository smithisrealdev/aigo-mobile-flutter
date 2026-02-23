class Review {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? tripId;
  final String? placeId;
  final String? placeName;
  final double rating;
  final String comment;
  final List<String> photos;
  final DateTime createdAt;
  final int helpfulCount;
  final bool isVerified;

  Review({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.tripId,
    this.placeId,
    this.placeName,
    required this.rating,
    required this.comment,
    this.photos = const [],
    required this.createdAt,
    this.helpfulCount = 0,
    this.isVerified = false,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String? ?? 'Anonymous',
        userAvatar: json['user_avatar'] as String?,
        tripId: json['trip_id'] as String?,
        placeId: json['place_id'] as String?,
        placeName: json['place_name'] as String?,
        rating: (json['rating'] as num).toDouble(),
        comment: json['comment'] as String? ?? '',
        photos: (json['photos'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        createdAt: DateTime.parse(json['created_at'] as String),
        helpfulCount: json['helpful_count'] as int? ?? 0,
        isVerified: json['is_verified'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'user_name': userName,
        'user_avatar': userAvatar,
        'trip_id': tripId,
        'place_id': placeId,
        'place_name': placeName,
        'rating': rating,
        'comment': comment,
        'photos': photos,
        'created_at': createdAt.toIso8601String(),
        'helpful_count': helpfulCount,
        'is_verified': isVerified,
      };

  Review copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? tripId,
    String? placeId,
    String? placeName,
    double? rating,
    String? comment,
    List<String>? photos,
    DateTime? createdAt,
    int? helpfulCount,
    bool? isVerified,
  }) =>
      Review(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        userAvatar: userAvatar ?? this.userAvatar,
        tripId: tripId ?? this.tripId,
        placeId: placeId ?? this.placeId,
        placeName: placeName ?? this.placeName,
        rating: rating ?? this.rating,
        comment: comment ?? this.comment,
        photos: photos ?? this.photos,
        createdAt: createdAt ?? this.createdAt,
        helpfulCount: helpfulCount ?? this.helpfulCount,
        isVerified: isVerified ?? this.isVerified,
      );
}
