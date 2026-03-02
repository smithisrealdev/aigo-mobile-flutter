import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';
import '../services/trip_service.dart' hide tripExpensesProvider;
import '../services/expense_service.dart';
import '../services/exchange_rate_service.dart';
import '../models/models.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  String? _selectedTripId;

  void _showCurrencyConverter(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CurrencyConverterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCurrencyConverter(context, ref),
        backgroundColor: AppColors.brandBlue,
        child: const Icon(Icons.currency_exchange, color: Colors.white),
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brandBlue)),
        error: (e, _) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Failed to load budget data', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: () => ref.invalidate(tripsProvider), icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
        ])),
        data: (trips) {
          // Calculate totals
          double totalBudget = 0;
          double totalSpent = 0;
          for (final t in trips) {
            if (t.budgetTotal != null) totalBudget += t.budgetTotal!;
            if (t.budgetSpent != null) totalSpent += t.budgetSpent!;
          }
          final pct = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;

          // Select trip for expense details
          final selectedTrip = _selectedTripId != null
              ? trips.cast<Trip?>().firstWhere((t) => t!.id == _selectedTripId, orElse: () => null)
              : (trips.isNotEmpty ? trips.first : null);

          return Column(
            children: [
              Container(
                decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1))),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      children: [
                        Row(children: [
                          GestureDetector(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20)),
                          const SizedBox(width: 12),
                          Text('Budget', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                        ]),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 140, height: 140,
                          child: CustomPaint(
                            painter: _DonutPainter(pct),
                            child: Center(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text('฿${totalSpent.toStringAsFixed(0)}', style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.brandBlue)),
                                Text('of ฿${totalBudget.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                              ]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Trip selector
              if (trips.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: trips.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final t = trips[i];
                        final selected = t.id == (selectedTrip?.id ?? '');
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTripId = t.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.brandBlue : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: selected ? null : Border.all(color: AppColors.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(t.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary), maxLines: 1),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Expanded(
                child: selectedTrip != null
                    ? _TripBudgetDetail(tripId: selectedTrip.id, trip: selectedTrip)
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Center(child: Column(children: [
                            const SizedBox(height: 40),
                            Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            const Text('No trips yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            const SizedBox(height: 4),
                            const Text('Create a trip to start tracking budget', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ])),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TripBudgetDetail extends ConsumerWidget {
  final String tripId;
  final Trip trip;

  const _TripBudgetDetail({required this.tripId, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(tripExpensesProvider(tripId));

    return expensesAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.brandBlue))),
      error: (e, _) => Center(child: Text('Failed to load expenses: $e', style: const TextStyle(color: AppColors.textSecondary))),
      data: (expenses) {
        // Group by category
        final Map<String, double> byCategory = {};
        for (final exp in expenses) {
          byCategory[exp.category] = (byCategory[exp.category] ?? 0) + exp.amount;
        }

        final categoryEmojis = {'accommodation': '🏨', 'food': '🍜', 'transport': '🚃', 'activities': '🎯', 'shopping': '🛍️', 'other': '📦'};
        final categoryColors = {'accommodation': AppColors.brandBlue, 'food': AppColors.warning, 'transport': AppColors.success, 'activities': Colors.purple, 'shopping': Colors.orange, 'other': const Color(0xFF6B7280)};

        final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.amount);
        final budget = trip.budgetTotal ?? totalSpent * 1.2;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Spending by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (byCategory.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('No expenses recorded yet', style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              ...byCategory.entries.map((e) {
                final emoji = categoryEmojis[e.key] ?? '📦';
                final color = categoryColors[e.key] ?? const Color(0xFF6B7280);
                final catBudget = budget / byCategory.length;
                return _budgetBar('$emoji ${e.key[0].toUpperCase()}${e.key.substring(1)}', e.value, catBudget, color);
              }),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: () => _showAddExpenseDialog(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (expenses.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No expenses yet', style: TextStyle(color: AppColors.textSecondary))))
            else
              ...expenses.take(20).map((e) {
                final emoji = categoryEmojis[e.category] ?? '📦';
                final date = e.expenseDate ?? e.createdAt?.substring(0, 10) ?? '';
                return _expense(e.title, emoji, '฿${e.amount.toStringAsFixed(0)}', date);
              }),
          ],
        );
      },
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'food';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDState) => AlertDialog(
        title: const Text('Add Expense'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 8),
          TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount (฿)'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: category,
            items: ['food', 'accommodation', 'transport', 'activities', 'shopping', 'other'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setDState(() => category = v ?? 'food'),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (titleCtrl.text.isEmpty || amount == null) return;
              Navigator.pop(ctx);
              try {
                await ExpenseService.instance.addExpense(CreateExpenseInput(
                  tripId: tripId,
                  title: titleCtrl.text,
                  amount: amount,
                  currency: 'USD',
                  category: category,
                ));
                ref.invalidate(tripExpensesProvider(tripId));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      )),
    );
  }

  static Widget _budgetBar(String label, double spent, double total, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(children: [
        Row(children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)), const Spacer(), Text('฿${spent.toInt()} / ฿${total.toInt()}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: (spent / total).clamp(0.0, 1.0), backgroundColor: color.withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation(color), minHeight: 8),
        ),
      ]),
    );
  }

  static Widget _expense(String title, String emoji, String amount, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ])),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ]),
    );
  }
}

class _CurrencyConverterSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CurrencyConverterSheet> createState() =>
      _CurrencyConverterSheetState();
}

class _CurrencyConverterSheetState
    extends ConsumerState<_CurrencyConverterSheet> {
  final _amountCtrl = TextEditingController(text: '100');
  String _from = 'USD';
  String _to = 'THB';
  double? _result;
  double? _rate;
  bool _loading = false;

  static const _currencies = [
    'USD', 'EUR', 'GBP', 'JPY', 'THB', 'CAD', 'AUD', 'SGD',
    'HKD', 'KRW', 'CNY', 'MYR', 'VND', 'PHP', 'IDR', 'INR',
    'NZD', 'CHF', 'TWD',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeCurrency = ref.read(homeCurrencyProvider);
      homeCurrency.whenData((c) {
        if (mounted) setState(() => _to = c);
      });
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;
    setState(() => _loading = true);
    final result = await ExchangeRateService.instance.convertToHomeCurrency(
      amount: amount,
      fromCurrency: _from,
      homeCurrency: _to,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result != null) {
        _result = result.convertedAmount;
        _rate = result.rate;
      } else if (_from == _to) {
        _result = amount;
        _rate = 1.0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Currency Converter',
              style: GoogleFonts.dmSans(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          // Amount
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixIcon: const Icon(Icons.attach_money),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          // From / To row
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _from,
                items: _currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _from = v ?? 'USD'),
                decoration: InputDecoration(
                  labelText: 'From',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: IconButton(
                onPressed: () => setState(() {
                  final tmp = _from;
                  _from = _to;
                  _to = tmp;
                  _result = null;
                }),
                icon: const Icon(Icons.swap_horiz,
                    color: AppColors.brandBlue, size: 28),
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _to,
                items: _currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _to = v ?? 'THB'),
                decoration: InputDecoration(
                  labelText: 'To',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          // Convert button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _convert,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Convert',
                      style: GoogleFonts.dmSans(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          // Result
          if (_result != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.brandBlue.withValues(alpha: 0.15)),
              ),
              child: Column(children: [
                Text(
                  '${getCurrencySymbol(_to)} ${_result!.toStringAsFixed(2)}',
                  style: GoogleFonts.dmSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandBlue),
                ),
                if (_rate != null)
                  Text(
                    '1 $_from = ${_rate!.toStringAsFixed(4)} $_to',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  _DonutPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final bg = Paint()..color = Colors.white.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round;
    final fg = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 12..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - 6, bg);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 6), -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
