// ──────────────────────────────────────────────
// Trip model  (mirrors `trips` table)
// ──────────────────────────────────────────────
class Trip {
  final String id;
  final String userId;
  final String title;
  final String destination;
  final String? category;
  final String? status;
  final String? startDate;
  final String? endDate;
  final double? budgetTotal;
  final double? budgetSpent;
  final String? budgetCurrency;
  final String? coverImage;
  final bool isPublic;
  final bool isFeatured;
  final Map<String, dynamic>? itineraryData;
  final String? shareToken;
  final int? shareViews;
  final String? sharedAt;
  final String? createdAt;
  final String? updatedAt;

  Trip({
    required this.id,
    required this.userId,
    required this.title,
    required this.destination,
    this.category,
    this.status,
    this.startDate,
    this.endDate,
    this.budgetTotal,
    this.budgetSpent,
    this.budgetCurrency,
    this.coverImage,
    this.isPublic = false,
    this.isFeatured = false,
    this.itineraryData,
    this.shareToken,
    this.shareViews,
    this.sharedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        destination: json['destination'] as String,
        category: json['category'] as String?,
        status: json['status'] as String?,
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        budgetTotal: (json['budget_total'] as num?)?.toDouble(),
        budgetSpent: (json['budget_spent'] as num?)?.toDouble(),
        budgetCurrency: json['budget_currency'] as String?,
        coverImage: json['cover_image'] as String?,
        isPublic: json['is_public'] as bool? ?? false,
        isFeatured: json['is_featured'] as bool? ?? false,
        itineraryData: json['itinerary_data'] as Map<String, dynamic>?,
        shareToken: json['share_token'] as String?,
        shareViews: json['share_views'] as int?,
        sharedAt: json['shared_at'] as String?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'user_id': userId,
        'title': title,
        'destination': destination,
        'category': ?category,
        'status': ?status,
        'start_date': ?startDate,
        'end_date': ?endDate,
        'budget_total': ?budgetTotal,
        'budget_spent': ?budgetSpent,
        'budget_currency': ?budgetCurrency,
        'cover_image': ?coverImage,
        'itinerary_data': ?itineraryData,
        'is_public': isPublic,
      };
}

// ──────────────────────────────────────────────
// ManualExpense  (mirrors `manual_expenses`)
// ──────────────────────────────────────────────
class ManualExpense {
  final String id;
  final String tripId;
  final String userId;
  final String title;
  final double amount;
  final String category;
  final String currency;
  final int? dayIndex;
  final String? expenseDate;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  ManualExpense({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.title,
    required this.amount,
    this.category = 'other',
    this.currency = 'THB',
    this.dayIndex,
    this.expenseDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory ManualExpense.fromJson(Map<String, dynamic> json) => ManualExpense(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String? ?? 'other',
        currency: json['currency'] as String? ?? 'THB',
        dayIndex: json['day_index'] as int?,
        expenseDate: json['expense_date'] as String?,
        notes: json['notes'] as String?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'trip_id': tripId,
        'user_id': userId,
        'title': title,
        'amount': amount,
        'category': category,
        'currency': currency,
        'day_index': ?dayIndex,
        'expense_date': ?expenseDate,
        'notes': ?notes,
      };
}

// ──────────────────────────────────────────────
// PlaceComment
// ──────────────────────────────────────────────
class PlaceComment {
  final String id;
  final String tripId;
  final String placeId;
  final String userId;
  final String content;
  final String? createdAt;
  final String? updatedAt;

  PlaceComment({
    required this.id,
    required this.tripId,
    required this.placeId,
    required this.userId,
    required this.content,
    this.createdAt,
    this.updatedAt,
  });

  factory PlaceComment.fromJson(Map<String, dynamic> json) => PlaceComment(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        placeId: json['place_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'trip_id': tripId,
        'place_id': placeId,
        'user_id': userId,
        'content': content,
      };
}

// ──────────────────────────────────────────────
// PlaceDetailsCache
// ──────────────────────────────────────────────
class PlaceDetailsCache {
  final String id;
  final String placeKey;
  final String placeName;
  final String? placeAddress;
  final String? imageUrl;
  final List<String>? photoUrls;
  final double? rating;
  final int? reviewCount;
  final int? priceLevel;
  final String? phone;
  final String? website;
  final String? googleMapsUrl;
  final Map<String, dynamic>? openingHours;
  final List<dynamic>? reviews;
  final String? createdAt;
  final String? updatedAt;

  PlaceDetailsCache({
    required this.id,
    required this.placeKey,
    required this.placeName,
    this.placeAddress,
    this.imageUrl,
    this.photoUrls,
    this.rating,
    this.reviewCount,
    this.priceLevel,
    this.phone,
    this.website,
    this.googleMapsUrl,
    this.openingHours,
    this.reviews,
    this.createdAt,
    this.updatedAt,
  });

  factory PlaceDetailsCache.fromJson(Map<String, dynamic> json) =>
      PlaceDetailsCache(
        id: json['id'] as String,
        placeKey: json['place_key'] as String,
        placeName: json['place_name'] as String,
        placeAddress: json['place_address'] as String?,
        imageUrl: json['image_url'] as String?,
        photoUrls: (json['photo_urls'] as List?)?.cast<String>(),
        rating: (json['rating'] as num?)?.toDouble(),
        reviewCount: json['review_count'] as int?,
        priceLevel: json['price_level'] as int?,
        phone: json['phone'] as String?,
        website: json['website'] as String?,
        googleMapsUrl: json['google_maps_url'] as String?,
        openingHours: json['opening_hours'] as Map<String, dynamic>?,
        reviews: json['reviews'] as List<dynamic>?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );
}

// ──────────────────────────────────────────────
// DestinationImage
// ──────────────────────────────────────────────
class DestinationImage {
  final String id;
  final String destinationName;
  final String imageUrl;
  final String? region;

  DestinationImage({
    required this.id,
    required this.destinationName,
    required this.imageUrl,
    this.region,
  });

  factory DestinationImage.fromJson(Map<String, dynamic> json) =>
      DestinationImage(
        id: json['id'] as String,
        destinationName: json['destination_name'] as String,
        imageUrl: json['image_url'] as String,
        region: json['region'] as String?,
      );
}

// ──────────────────────────────────────────────
// Reservation
// ──────────────────────────────────────────────
class Reservation {
  final String id;
  final String tripId;
  final String userId;
  final String title;
  final String type;
  final String status;
  final String? confirmationNumber;
  final String? ticketCode;
  final String? reservationDate;
  final String? reservationTime;
  final String? location;
  final double? price;
  final String? currency;
  final String? link;
  final String? notes;
  final String? priority;
  final String? createdAt;
  final String? updatedAt;

  Reservation({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.title,
    required this.type,
    this.status = 'pending',
    this.confirmationNumber,
    this.ticketCode,
    this.reservationDate,
    this.reservationTime,
    this.location,
    this.price,
    this.currency,
    this.link,
    this.notes,
    this.priority,
    this.createdAt,
    this.updatedAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        type: json['type'] as String,
        status: json['status'] as String? ?? 'pending',
        confirmationNumber: json['confirmation_number'] as String?,
        ticketCode: json['ticket_code'] as String?,
        reservationDate: json['reservation_date'] as String?,
        reservationTime: json['reservation_time'] as String?,
        location: json['location'] as String?,
        price: (json['price'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        link: json['link'] as String?,
        notes: json['notes'] as String?,
        priority: json['priority'] as String?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'trip_id': tripId,
        'user_id': userId,
        'title': title,
        'type': type,
        'status': status,
        'confirmation_number': ?confirmationNumber,
        'ticket_code': ?ticketCode,
        'reservation_date': ?reservationDate,
        'reservation_time': ?reservationTime,
        'location': ?location,
        'price': ?price,
        'currency': ?currency,
        'link': ?link,
        'notes': ?notes,
        'priority': ?priority,
      };
}

// ──────────────────────────────────────────────
// TripChecklist
// ──────────────────────────────────────────────
class TripChecklist {
  final String id;
  final String tripId;
  final String userId;
  final String itemName;
  final String itemType;
  final String? itemDescription;
  final String urgency;
  final bool isCompleted;
  final bool aiGenerated;
  final String? dueDate;
  final String? tip;
  final String? createdAt;
  final String? updatedAt;

  TripChecklist({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.itemName,
    required this.itemType,
    this.itemDescription,
    this.urgency = 'low',
    this.isCompleted = false,
    this.aiGenerated = false,
    this.dueDate,
    this.tip,
    this.createdAt,
    this.updatedAt,
  });

  factory TripChecklist.fromJson(Map<String, dynamic> json) => TripChecklist(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        userId: json['user_id'] as String,
        itemName: json['item_name'] as String,
        itemType: json['item_type'] as String,
        itemDescription: json['item_description'] as String?,
        urgency: json['urgency'] as String? ?? 'low',
        isCompleted: json['is_completed'] as bool? ?? false,
        aiGenerated: json['ai_generated'] as bool? ?? false,
        dueDate: json['due_date'] as String?,
        tip: json['tip'] as String?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'trip_id': tripId,
        'user_id': userId,
        'item_name': itemName,
        'item_type': itemType,
        'item_description': ?itemDescription,
        'urgency': urgency,
        'is_completed': isCompleted,
        'ai_generated': aiGenerated,
        'due_date': ?dueDate,
        'tip': ?tip,
      };
}

// ──────────────────────────────────────────────
// TripAlert
// ──────────────────────────────────────────────
class TripAlert {
  final String id;
  final String tripId;
  final String userId;
  final String alertType;
  final String title;
  final String message;
  final String? placeId;
  final String? priority;
  final bool isRead;
  final String? createdAt;

  TripAlert({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.alertType,
    required this.title,
    required this.message,
    this.placeId,
    this.priority,
    this.isRead = false,
    this.createdAt,
  });

  factory TripAlert.fromJson(Map<String, dynamic> json) => TripAlert(
        id: json['id'] as String,
        tripId: json['trip_id'] as String,
        userId: json['user_id'] as String,
        alertType: json['alert_type'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        placeId: json['place_id'] as String?,
        priority: json['priority'] as String?,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: json['created_at'] as String?,
      );
}

// ──────────────────────────────────────────────
// Profile
// ──────────────────────────────────────────────
class UserProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String? homeCurrency;
  final String? selectedMascot;
  final String? createdAt;
  final String? updatedAt;

  UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.homeCurrency,
    this.selectedMascot,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        email: json['email'] as String?,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        homeCurrency: json['home_currency'] as String?,
        selectedMascot: json['selected_mascot'] as String?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );
}

// ──────────────────────────────────────────────
// ChatFeedback
// ──────────────────────────────────────────────
class ChatFeedback {
  final String id;
  final String? userId;
  final String? sessionId;
  final String feedbackType;
  final String messageContent;
  final String? createdAt;

  ChatFeedback({
    required this.id,
    this.userId,
    this.sessionId,
    required this.feedbackType,
    required this.messageContent,
    this.createdAt,
  });

  factory ChatFeedback.fromJson(Map<String, dynamic> json) => ChatFeedback(
        id: json['id'] as String,
        userId: json['user_id'] as String?,
        sessionId: json['session_id'] as String?,
        feedbackType: json['feedback_type'] as String,
        messageContent: json['message_content'] as String,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'user_id': ?userId,
        'session_id': ?sessionId,
        'feedback_type': feedbackType,
        'message_content': messageContent,
      };
}
