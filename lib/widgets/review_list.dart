import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';
import 'review_card.dart';

enum ReviewSort { recent, highest, helpful }

class ReviewList extends StatefulWidget {
  final List<Review> reviews;
  final bool loading;

  const ReviewList({super.key, required this.reviews, this.loading = false});

  @override
  State<ReviewList> createState() => _ReviewListState();
}

class _ReviewListState extends State<ReviewList> {
  ReviewSort _sort = ReviewSort.recent;

  List<Review> get _sorted {
    final list = List<Review>.from(widget.reviews);
    switch (_sort) {
      case ReviewSort.recent:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case ReviewSort.highest:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case ReviewSort.helpful:
        list.sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Column(
        children: List.generate(
            3,
            (_) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                )),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sort chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ReviewSort.values.map((s) {
              final label = switch (s) {
                ReviewSort.recent => 'Most Recent',
                ReviewSort.highest => 'Highest Rated',
                ReviewSort.helpful => 'Most Helpful',
              };
              final selected = _sort == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _sort = s),
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        if (_sorted.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No reviews yet. Be the first!',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ),
          )
        else
          ..._sorted.map((r) => ReviewCard(
                review: r,
                onHelpful: () => ReviewService.instance.markHelpful(r.id),
              )),
      ],
    );
  }
}
