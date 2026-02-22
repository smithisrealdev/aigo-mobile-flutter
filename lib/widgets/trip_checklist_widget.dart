import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/checklist_service.dart';
import '../theme/app_colors.dart';

/// Trip checklist widget grouped by category.
class TripChecklistWidget extends ConsumerStatefulWidget {
  final String tripId;
  const TripChecklistWidget({super.key, required this.tripId});

  @override
  ConsumerState<TripChecklistWidget> createState() =>
      _TripChecklistWidgetState();
}

class _TripChecklistWidgetState extends ConsumerState<TripChecklistWidget> {
  final _addController = TextEditingController();
  String _selectedCategory = 'todo';

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'packing':
        return Icons.luggage;
      case 'shopping':
        return Icons.shopping_cart;
      default:
        return Icons.check_circle_outline;
    }
  }

  Future<void> _addItem() async {
    final title = _addController.text.trim();
    if (title.isEmpty) return;
    _addController.clear();
    await ChecklistService.instance.addItem(ChecklistItem(
      id: '',
      tripId: widget.tripId,
      title: title,
      category: _selectedCategory,
    ));
    ref.invalidate(tripChecklistsProvider(widget.tripId));
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(tripChecklistsProvider(widget.tripId));

    return itemsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Text('Error: $e'),
      data: (items) {
        final grouped = <String, List<ChecklistItem>>{};
        for (final item in items) {
          grouped.putIfAbsent(item.category, () => []).add(item);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add new item row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    decoration: InputDecoration(
                      hintText: 'Add item...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedCategory,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'todo', child: Text('Todo', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'packing', child: Text('Packing', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'shopping', child: Text('Shopping', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.brandBlue),
                  onPressed: _addItem,
                  iconSize: 28,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Grouped lists
            for (final category in ['packing', 'todo', 'shopping'])
              if (grouped.containsKey(category)) ...[
                Row(
                  children: [
                    Icon(_categoryIcon(category),
                        size: 16, color: AppColors.brandBlue),
                    const SizedBox(width: 6),
                    Text(
                      category[0].toUpperCase() + category.substring(1),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${grouped[category]!.where((i) => i.isChecked).length}/${grouped[category]!.length})',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...grouped[category]!.map((item) => _ChecklistTile(
                      item: item,
                      urgencyColor: _urgencyColor(item.urgency),
                      onToggle: () async {
                        await ChecklistService.instance
                            .toggleItem(item.id, !item.isChecked);
                        ref.invalidate(
                            tripChecklistsProvider(widget.tripId));
                      },
                      onDelete: () async {
                        await ChecklistService.instance.deleteItem(item.id);
                        ref.invalidate(
                            tripChecklistsProvider(widget.tripId));
                      },
                    )),
                const SizedBox(height: 12),
              ],

            if (items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No checklist items yet',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final ChecklistItem item;
  final Color urgencyColor;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ChecklistTile({
    required this.item,
    required this.urgencyColor,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              item.isChecked
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color:
                  item.isChecked ? AppColors.success : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.title,
              style: TextStyle(
                fontSize: 13,
                color: item.isChecked
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                decoration:
                    item.isChecked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.urgency,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: urgencyColor),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
