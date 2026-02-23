import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/models.dart';
import '../services/packing_service.dart';
import '../services/checklist_service.dart';

class PackingListScreen extends StatefulWidget {
  final Trip? trip;
  const PackingListScreen({super.key, this.trip});

  @override
  State<PackingListScreen> createState() => _PackingListScreenState();
}

class _PackingListScreenState extends State<PackingListScreen> {
  List<ChecklistItem> _items = [];
  PackingListResult? _aiResult;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    if (widget.trip == null) {
      setState(() {
        _loading = false;
        _error = 'No trip selected';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items =
          await ChecklistService.instance.getChecklist(widget.trip!.id);
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generatePackingList() async {
    if (widget.trip == null) return;
    setState(() => _generating = true);
    try {
      final trip = widget.trip!;
      int totalDays = 7;
      if (trip.startDate != null && trip.endDate != null) {
        final start = DateTime.tryParse(trip.startDate!);
        final end = DateTime.tryParse(trip.endDate!);
        if (start != null && end != null) {
          totalDays = end.difference(start).inDays.clamp(1, 365);
        }
      }
      final result = await PackingService.instance.generatePackingList(
        destination: trip.destination,
        totalDays: totalDays,
        startDate: trip.startDate,
        tripCategory: trip.category,
      );
      setState(() {
        _aiResult = result;
        _generating = false;
      });
      // Also save items to checklist
      for (final item in result.items) {
        await ChecklistService.instance.addItem(ChecklistItem(
          id: '',
          tripId: trip.id,
          title: item.name,
          category: 'packing',
          urgency: item.essential ? 'high' : 'medium',
          notes: item.reason,
        ));
      }
      await _loadChecklist();
    } catch (e) {
      setState(() => _generating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate: $e')),
        );
      }
    }
  }

  Future<void> _toggleItem(ChecklistItem item) async {
    await ChecklistService.instance.toggleItem(item.id, !item.isChecked);
    setState(() {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        _items[idx] = item.copyWith(isChecked: !item.isChecked);
      }
    });
  }

  Map<String, List<ChecklistItem>> get _grouped {
    final map = <String, List<ChecklistItem>>{};
    for (final item in _items) {
      final cat = item.category.isNotEmpty ? item.category : 'other';
      map.putIfAbsent(cat, () => []).add(item);
    }
    return map;
  }

  int get _checkedCount => _items.where((i) => i.isChecked).length;

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'packing':
        return Icons.luggage;
      case 'todo':
        return Icons.check_circle_outline;
      case 'shopping':
        return Icons.shopping_bag;
      default:
        return Icons.list_alt;
    }
  }

  Color _colorForUrgency(String urgency) {
    switch (urgency) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.brandBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.blueBorder, width: 1))),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.maybePop(context),
                          child: const Icon(Icons.arrow_back_ios,
                              color: AppColors.textPrimary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text('Packing List',
                            style: GoogleFonts.dmSans(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const Spacer(),
                        if (!_generating)
                          GestureDetector(
                            onTap: _generatePackingList,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text('AI Generate',
                                      style: GoogleFonts.dmSans(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!_loading && _items.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: _items.isEmpty
                                  ? 0
                                  : _checkedCount / _items.length,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              valueColor:
                                  const AlwaysStoppedAnimation(Colors.white),
                              strokeWidth: 8,
                              strokeCap: StrokeCap.round,
                            ),
                            Center(
                              child: Text(
                                '$_checkedCount/${_items.length}',
                                style: GoogleFonts.dmSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_generating)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_aiResult?.tip != null && !_generating)
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.brandBlue.withValues(alpha: 0.08),
                  AppColors.brandBlue.withValues(alpha: 0.02),
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.brandBlue.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.brandBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.auto_awesome,
                        color: AppColors.brandBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Tip',
                            style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(_aiResult!.tip!,
                            style: GoogleFonts.dmSans(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: GoogleFonts.dmSans(
                                color: AppColors.textSecondary)))
                    : _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.luggage,
                                    size: 64,
                                    color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text('No items yet',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 16,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                                Text(
                                    'Tap "AI Generate" to create a packing list',
                                    style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadChecklist,
                            child: ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              children: _grouped.entries
                                  .map((e) =>
                                      _buildCategory(e.key, e.value))
                                  .toList(),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(String name, List<ChecklistItem> items) {
    final displayName = name[0].toUpperCase() + name.substring(1);
    final checked = items.where((i) => i.isChecked).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        leading: Icon(_iconForCategory(name),
            color: AppColors.brandBlue, size: 22),
        title: Row(
          children: [
            Text(displayName,
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const Spacer(),
            Text('$checked/${items.length}',
                style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        children: items
            .map((item) => _buildItem(item))
            .toList(),
      ),
    );
  }

  Widget _buildItem(ChecklistItem item) {
    final urgencyColor = _colorForUrgency(item.urgency);

    return CheckboxListTile(
      value: item.isChecked,
      onChanged: (_) => _toggleItem(item),
      activeColor: AppColors.brandBlue,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      title: Row(
        children: [
          Expanded(
            child: Text(item.title,
                style: GoogleFonts.dmSans(
                    decoration:
                        item.isChecked ? TextDecoration.lineThrough : null,
                    color: item.isChecked
                        ? AppColors.textSecondary
                        : AppColors.textPrimary)),
          ),
          if (item.urgency == 'high')
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Urgent',
                  style: GoogleFonts.dmSans(
                      color: urgencyColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      subtitle: item.notes != null
          ? Text(item.notes!,
              style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary, fontSize: 12))
          : null,
    );
  }
}
