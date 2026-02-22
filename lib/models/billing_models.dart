/// Plan with limits and features.
class PlanLimit {
  final String id;
  final String name;
  final int maxTrips;
  final int maxAiRequests;
  final int maxCollaborators;
  final double price;
  final List<String> features;

  PlanLimit({
    required this.id,
    required this.name,
    required this.maxTrips,
    required this.maxAiRequests,
    required this.maxCollaborators,
    required this.price,
    required this.features,
  });

  factory PlanLimit.fromJson(Map<String, dynamic> json) => PlanLimit(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Free',
        maxTrips: json['max_trips'] as int? ?? 3,
        maxAiRequests: json['max_ai_requests'] as int? ?? 10,
        maxCollaborators: json['max_collaborators'] as int? ?? 1,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        features: (json['features'] as List?)?.cast<String>() ?? [],
      );

  bool get isFree => name.toLowerCase() == 'free';
  bool get isPro => name.toLowerCase() == 'pro';
  bool get isTeam => name.toLowerCase() == 'team';
}

/// Payment history record.
class PaymentRecord {
  final String id;
  final double amount;
  final String currency;
  final String status;
  final String? createdAt;
  final String? description;
  final String? stripeInvoiceUrl;

  PaymentRecord({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    this.createdAt,
    this.description,
    this.stripeInvoiceUrl,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'USD',
        status: json['status'] as String? ?? 'pending',
        createdAt: json['created_at'] as String?,
        description: json['description'] as String?,
        stripeInvoiceUrl: json['stripe_invoice_url'] as String?,
      );
}
