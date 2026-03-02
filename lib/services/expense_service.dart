import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';
import 'auth_service.dart';

// ──────────────────────────────────────────────
// Expense service — matches useManualExpenses.ts
// Direct CRUD on manual_expenses table
// ──────────────────────────────────────────────

class CreateExpenseInput {
  final String tripId;
  final String title;
  final double amount;
  final String currency;
  final String category;
  final String? expenseDate;
  final int? dayIndex;
  final String? notes;

  CreateExpenseInput({
    required this.tripId,
    required this.title,
    required this.amount,
    required this.currency,
    required this.category,
    this.expenseDate,
    this.dayIndex,
    this.notes,
  });
}

class ExpenseService {
  ExpenseService._();
  static final ExpenseService instance = ExpenseService._();

  /// Fetch all expenses for a trip.
  Future<List<ManualExpense>> fetchExpenses(String tripId) async {
    final data = await SupabaseConfig.client
        .from('manual_expenses')
        .select()
        .eq('trip_id', tripId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => ManualExpense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Add a new expense.
  Future<ManualExpense?> addExpense(CreateExpenseInput input) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final data = await SupabaseConfig.client
        .from('manual_expenses')
        .insert({
          'trip_id': input.tripId,
          'user_id': userId,
          'title': input.title,
          'amount': input.amount,
          'currency': input.currency,
          'category': input.category,
          'expense_date': ?input.expenseDate,
          'day_index': ?input.dayIndex,
          'notes': ?input.notes,
        })
        .select()
        .single();

    return ManualExpense.fromJson(data);
  }

  /// Update an existing expense.
  Future<ManualExpense?> updateExpense(
      String id, Map<String, dynamic> updates) async {
    final data = await SupabaseConfig.client
        .from('manual_expenses')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return ManualExpense.fromJson(data);
  }

  /// Delete an expense.
  Future<void> deleteExpense(String id) async {
    await SupabaseConfig.client
        .from('manual_expenses')
        .delete()
        .eq('id', id);
  }
}

// ── Riverpod providers ──

final expenseServiceProvider =
    Provider((_) => ExpenseService.instance);

/// Expenses state for a trip (matching website pattern).
class ExpensesState {
  final List<ManualExpense> expenses;
  final bool isLoading;
  final String? error;

  ExpensesState({
    this.expenses = const [],
    this.isLoading = true,
    this.error,
  });

  /// Totals by category.
  Map<String, double> get totalsByCategory {
    final acc = <String, double>{};
    for (final exp in expenses) {
      acc[exp.category] = (acc[exp.category] ?? 0) + exp.amount;
    }
    return acc;
  }

  /// Totals by day index.
  Map<int, double> get totalsByDay {
    final acc = <int, double>{};
    for (final exp in expenses) {
      if (exp.dayIndex != null) {
        acc[exp.dayIndex!] = (acc[exp.dayIndex!] ?? 0) + exp.amount;
      }
    }
    return acc;
  }

  /// Total amount.
  double get totalAmount =>
      expenses.fold(0.0, (sum, exp) => sum + exp.amount);
}

/// Expenses for a specific trip.
final tripExpensesProvider =
    FutureProvider.family<List<ManualExpense>, String>((ref, tripId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ExpenseService.instance.fetchExpenses(tripId);
});
