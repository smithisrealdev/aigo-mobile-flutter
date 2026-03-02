import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';

// ─── Models ───
class _Person {
  final String id;
  final String name;
  _Person({required this.id, required this.name});
}

enum SplitMethod { equal, custom, percentage }

class _Expense {
  final String id;
  final String title;
  final double amount;
  final String payerId;
  final SplitMethod method;
  final Map<String, double> splits; // personId → amount or percentage
  _Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.payerId,
    required this.method,
    required this.splits,
  });
}

// ─── Providers ───
final _peopleProvider = StateProvider<List<_Person>>((ref) => [
      _Person(id: '1', name: 'You'),
      _Person(id: '2', name: 'Friend 1'),
    ]);

final _expensesProvider = StateProvider<List<_Expense>>((ref) => []);

final _settlementsProvider = Provider<List<_Settlement>>((ref) {
  final people = ref.watch(_peopleProvider);
  final expenses = ref.watch(_expensesProvider);
  return _calculateSettlements(people, expenses);
});

class _Settlement {
  final String fromName;
  final String toName;
  final double amount;
  _Settlement({required this.fromName, required this.toName, required this.amount});
}

List<_Settlement> _calculateSettlements(List<_Person> people, List<_Expense> expenses) {
  if (people.isEmpty || expenses.isEmpty) return [];
  final balances = <String, double>{};
  for (final p in people) {
    balances[p.id] = 0;
  }
  for (final e in expenses) {
    balances[e.payerId] = (balances[e.payerId] ?? 0) + e.amount;
    for (final entry in e.splits.entries) {
      double owed;
      if (e.method == SplitMethod.percentage) {
        owed = e.amount * entry.value / 100;
      } else {
        owed = entry.value;
      }
      balances[entry.key] = (balances[entry.key] ?? 0) - owed;
    }
  }

  final debtors = <MapEntry<String, double>>[];
  final creditors = <MapEntry<String, double>>[];
  for (final e in balances.entries) {
    if (e.value < -0.01) debtors.add(e);
    if (e.value > 0.01) creditors.add(e);
  }
  debtors.sort((a, b) => a.value.compareTo(b.value));
  creditors.sort((a, b) => b.value.compareTo(a.value));

  final nameMap = {for (final p in people) p.id: p.name};
  final settlements = <_Settlement>[];
  var di = 0, ci = 0;
  final dBal = debtors.map((e) => -e.value).toList();
  final cBal = creditors.map((e) => e.value).toList();

  while (di < debtors.length && ci < creditors.length) {
    final transfer = math.min(dBal[di], cBal[ci]);
    if (transfer > 0.01) {
      settlements.add(_Settlement(
        fromName: nameMap[debtors[di].key] ?? '?',
        toName: nameMap[creditors[ci].key] ?? '?',
        amount: transfer,
      ));
    }
    dBal[di] -= transfer;
    cBal[ci] -= transfer;
    if (dBal[di] < 0.01) di++;
    if (cBal[ci] < 0.01) ci++;
  }
  return settlements;
}

// ─── Screen ───
class ExpenseSplitterScreen extends ConsumerStatefulWidget {
  const ExpenseSplitterScreen({super.key});
  @override
  ConsumerState<ExpenseSplitterScreen> createState() => _ExpenseSplitterScreenState();
}

class _ExpenseSplitterScreenState extends ConsumerState<ExpenseSplitterScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final people = ref.watch(_peopleProvider);
    final expenses = ref.watch(_expensesProvider);
    final settlements = ref.watch(_settlementsProvider);
    final totalSpent = expenses.fold<double>(0, (s, e) => s + e.amount);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.brandBlue,
        onPressed: () => _showAddExpenseSheet(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: AppColors.brandBlue,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1))),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Expense Splitter',
                          style: GoogleFonts.dmSans(
                              fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
                      const SizedBox(height: 4),
                      Text('${people.length} travelers  ·  ${expenses.length} expenses  ·  \$${totalSpent.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Travelers
            _sectionTitle('Travelers', isDark),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...people.map((p) => Chip(
                      label: Text(p.name, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary)),
                      backgroundColor: isDark ? AppColors.cardDarkMode : Colors.white,
                      deleteIcon: people.length > 1 ? const Icon(Icons.close, size: 16) : null,
                      onDeleted: people.length > 1
                          ? () => ref.read(_peopleProvider.notifier).state =
                              people.where((x) => x.id != p.id).toList()
                          : null,
                      side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    )),
                ActionChip(
                  label: const Text('Add', style: TextStyle(fontSize: 13, color: AppColors.brandBlue)),
                  avatar: const Icon(Icons.person_add, size: 16, color: AppColors.brandBlue),
                  backgroundColor: AppColors.brandBlue.withValues(alpha: 0.08),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onPressed: () => _showAddPersonDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Expenses
            _sectionTitle('Expenses', isDark),
            const SizedBox(height: 8),
            if (expenses.isEmpty)
              _emptyCard('No expenses yet', 'Tap + to add one', Icons.receipt_long, isDark)
            else
              ...expenses.map((e) {
                final payerName = people.firstWhere((p) => p.id == e.payerId, orElse: () => _Person(id: '', name: '?')).name;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDarkMode : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.brandBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt, size: 20, color: AppColors.brandBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
                        Text('Paid by $payerName  ·  ${e.method.name}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
                      ],
                    )),
                    Text('\$${e.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.brandBlue)),
                  ]),
                );
              }),
            const SizedBox(height: 24),

            // Settlements
            _sectionTitle('Who Owes Whom', isDark),
            const SizedBox(height: 8),
            if (settlements.isEmpty)
              _emptyCard('All settled up', 'Add expenses to see settlements', Icons.check_circle_outline, isDark)
            else
              ...settlements.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDarkMode : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.swap_horiz, color: AppColors.success, size: 24),
                      const SizedBox(width: 12),
                      Expanded(child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 14, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                          children: [
                            TextSpan(text: s.fromName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const TextSpan(text: ' owes '),
                            TextSpan(text: s.toName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )),
                      Text('\$${s.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.success)),
                    ]),
                  )),
            const SizedBox(height: 80),
          ])),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String title, bool isDark) => Text(title,
      style: GoogleFonts.dmSans(
          fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary));

  Widget _emptyCard(String title, String subtitle, IconData icon, bool isDark) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkMode : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Icon(icon, size: 40, color: AppColors.brandBlue.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)),
        ]),
      );

  void _showAddPersonDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Traveler', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              final people = ref.read(_peopleProvider);
              ref.read(_peopleProvider.notifier).state = [
                ...people,
                _Person(id: DateTime.now().millisecondsSinceEpoch.toString(), name: controller.text.trim()),
              ];
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context, WidgetRef ref) {
    final people = ref.read(_peopleProvider);
    if (people.isEmpty) return;
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String payerId = people.first.id;
    SplitMethod method = SplitMethod.equal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Expense', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(hintText: 'Expense title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(hintText: 'Amount', prefixText: '\$ ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: payerId,
              decoration: InputDecoration(labelText: 'Paid by', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: people.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
              onChanged: (v) => setSheetState(() => payerId = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SplitMethod>(
              initialValue: method,
              decoration: InputDecoration(labelText: 'Split method', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: SplitMethod.values.map((m) => DropdownMenuItem(value: m, child: Text(m.name[0].toUpperCase() + m.name.substring(1)))).toList(),
              onChanged: (v) => setSheetState(() => method = v!),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final amount = double.tryParse(amountCtrl.text);
                  if (titleCtrl.text.trim().isEmpty || amount == null || amount <= 0) return;
                  final splits = <String, double>{};
                  final share = amount / people.length;
                  for (final p in people) {
                    splits[p.id] = method == SplitMethod.percentage ? 100.0 / people.length : share;
                  }
                  final expenses = ref.read(_expensesProvider);
                  ref.read(_expensesProvider.notifier).state = [
                    ...expenses,
                    _Expense(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleCtrl.text.trim(),
                      amount: amount,
                      payerId: payerId,
                      method: method,
                      splits: splits,
                    ),
                  ];
                  Navigator.pop(ctx);
                },
                child: const Text('Add Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        );
      }),
    );
  }
}
