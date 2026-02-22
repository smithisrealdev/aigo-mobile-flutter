import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import 'auth_service.dart';

// ──────────────────────────────────────────────
// Exchange rate service — matches useExchangeRate.ts
// ──────────────────────────────────────────────

// Module-level cache matching website pattern
class _RateCacheEntry {
  final double rate;
  final DateTime timestamp;
  _RateCacheEntry(this.rate) : timestamp = DateTime.now();
}

final Map<String, _RateCacheEntry> _rateCache = {};
const _cacheTtlMs = 60 * 60 * 1000; // 1 hour

// Currency symbol map matching website
const Map<String, String> currencySymbols = {
  'THB': '฿',
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'CAD': 'C\$',
  'AUD': 'A\$',
  'SGD': 'S\$',
  'HKD': 'HK\$',
  'KRW': '₩',
  'CNY': '¥',
  'MYR': 'RM',
  'VND': '₫',
  'PHP': '₱',
  'IDR': 'Rp',
  'INR': '₹',
  'NZD': 'NZ\$',
  'CHF': 'CHF',
  'TWD': 'NT\$',
};

String getCurrencySymbol(String currency) =>
    currencySymbols[currency] ?? currency;

class ConversionResult {
  final double convertedAmount;
  final double rate;
  ConversionResult({required this.convertedAmount, required this.rate});
}

class ExchangeRateService {
  ExchangeRateService._();
  static final ExchangeRateService instance = ExchangeRateService._();

  /// Fetch user's home currency from profiles table.
  /// Matches website logic including THB→USD migration.
  Future<String> fetchHomeCurrency(String userId) async {
    try {
      final data = await SupabaseConfig.client
          .from('profiles')
          .select('home_currency')
          .eq('id', userId)
          .maybeSingle();

      if (data != null && data['home_currency'] != null) {
        final currency = data['home_currency'] as String;
        // Migrate THB → USD (matching website)
        if (currency == 'THB') {
          SupabaseConfig.client
              .from('profiles')
              .update({'home_currency': 'USD'})
              .eq('id', userId)
              .then((_) {});
          return 'USD';
        }
        return currency;
      } else {
        // Default to USD and save
        SupabaseConfig.client
            .from('profiles')
            .update({'home_currency': 'USD'})
            .eq('id', userId)
            .then((_) {});
        return 'USD';
      }
    } catch (e) {
      debugPrint('Failed to fetch home currency: $e');
      return 'USD';
    }
  }

  /// Convert amount from one currency to home currency.
  /// Matches website convertToHomeCurrency.
  Future<ConversionResult?> convertToHomeCurrency({
    required double amount,
    required String fromCurrency,
    required String homeCurrency,
  }) async {
    if (fromCurrency == homeCurrency) return null;

    final cacheKey = '${fromCurrency}_$homeCurrency';
    final cached = _rateCache[cacheKey];

    // Check cache
    if (cached != null &&
        DateTime.now().difference(cached.timestamp).inMilliseconds <
            _cacheTtlMs) {
      return ConversionResult(
        convertedAmount: (amount * cached.rate).roundToDouble(),
        rate: cached.rate,
      );
    }

    // Fetch from edge function with retry
    try {
      final res = await _invokeWithRetry('get-exchange-rate', body: {
        'from': fromCurrency,
        'to': homeCurrency,
        'amount': amount,
      });

      final data = res.data as Map<String, dynamic>?;
      if (data == null || data['convertedAmount'] == null) {
        debugPrint('Exchange rate fetch failed: ${data?['error']}');
        return null;
      }

      final convertedAmount =
          (data['convertedAmount'] as num).toDouble();
      final rate = convertedAmount / amount;

      // Cache the rate
      _rateCache[cacheKey] = _RateCacheEntry(rate);

      return ConversionResult(
        convertedAmount: convertedAmount.roundToDouble(),
        rate: rate,
      );
    } catch (e) {
      debugPrint('Exchange rate error: $e');
      return null;
    }
  }

  /// Invoke with retry (matches supabaseRetry.ts).
  Future<dynamic> _invokeWithRetry(String functionName,
      {Map<String, dynamic>? body, int maxRetries = 3}) async {
    dynamic lastError;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      final result = await SupabaseConfig.client.functions
          .invoke(functionName, body: body);

      // Check for BOOT_ERROR
      final data = result.data;
      final isBootError = data is Map && data['code'] == 'BOOT_ERROR';
      if (isBootError && attempt < maxRetries) {
        lastError = Exception('BOOT_ERROR');
        await Future.delayed(Duration(milliseconds: 500 * attempt));
        continue;
      }

      return result;
    }
    throw lastError ?? Exception('All retries exhausted');
  }
}

// ── Riverpod providers ──

final exchangeRateServiceProvider =
    Provider((_) => ExchangeRateService.instance);

/// Home currency for current user.
final homeCurrencyProvider = FutureProvider<String>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 'USD';
  return ExchangeRateService.instance.fetchHomeCurrency(user.id);
});
