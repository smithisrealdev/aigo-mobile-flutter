/// Plan with limits and features.
import 'dart:convert';

List<String> _parseFeatures(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) return raw.cast<String>();
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
  return [];
}

class PlanLimit {
  final String id;
  final String name;
  final int maxTrips;
  final int maxAiRequests;
  final int maxCollaborators;
  final double price;
  final double yearlyPrice;
  final List<String> features;

  PlanLimit({
    required this.id,
    required this.name,
    required this.maxTrips,
    required this.maxAiRequests,
    required this.maxCollaborators,
    required this.price,
    this.yearlyPrice = 0,
    required this.features,
  });

  factory PlanLimit.fromJson(Map<String, dynamic> json) => PlanLimit(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Free',
        maxTrips: json['max_trips'] as int? ?? 3,
        maxAiRequests: json['max_ai_requests'] as int? ?? 10,
        maxCollaborators: json['max_collaborators'] as int? ?? 1,
        price: ((json['monthly_price_cents'] ?? json['price'] ?? 0) as num).toDouble() / 100,
        yearlyPrice: ((json['yearly_price_cents'] ?? 0) as num).toDouble() / 100,
        features: _parseFeatures(json['features']),
      );

  bool get isFree => name.toLowerCase() == 'free';
  bool get isPro => name.toLowerCase() == 'pro';
  bool get isTeam => name.toLowerCase() == 'team';
}

/// User subscription record.
class UserSubscription {
  final String id;
  final String userId;
  final String planId;
  final String status; // active | canceled | past_due | trialing
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final String? currentPeriodStart;
  final String? currentPeriodEnd;
  final String? cancelAt;
  final String? createdAt;

  UserSubscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.status,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cancelAt,
    this.createdAt,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) =>
      UserSubscription(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        planId: json['plan_id'] as String? ?? 'free',
        status: json['status'] as String? ?? 'active',
        stripeCustomerId: json['stripe_customer_id'] as String?,
        stripeSubscriptionId: json['stripe_subscription_id'] as String?,
        currentPeriodStart: json['current_period_start'] as String?,
        currentPeriodEnd: json['current_period_end'] as String?,
        cancelAt: json['cancel_at'] as String?,
        createdAt: json['created_at'] as String?,
      );

  bool get isActive => status == 'active' || status == 'trialing';
  bool get isCanceled => status == 'canceled';
  bool get isPastDue => status == 'past_due';

  DateTime? get periodEnd =>
      currentPeriodEnd != null ? DateTime.tryParse(currentPeriodEnd!) : null;
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
