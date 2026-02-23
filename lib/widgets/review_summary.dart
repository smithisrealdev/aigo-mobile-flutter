import 'package:flutter/material.dart';
import '../models/review_model.dart';

class ReviewSummary extends StatelessWidget {
  final List<Review> reviews;

  const ReviewSummary({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No reviews yet',
              style: TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
        ),
      );
    }

    final avg =
        reviews.fold<double>(0, (s, r) => s + r.rating) / reviews.length;
    final counts = List.filled(5, 0);
    for (final r in reviews) {
      final idx = r.rating.round().clamp(1, 5) - 1;
      counts[idx]++;
    }
    final maxCount = counts.reduce((a, b) => a > b ? a : b).clamp(1, 999999);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: big number + stars
          Column(
            children: [
              Text(avg.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < avg.round() ? Icons.star : Icons.star_border,
                          size: 18,
                          color: const Color(0xFFF59E0B),
                        )),
              ),
              const SizedBox(height: 4),
              Text('${reviews.length} reviews',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(width: 24),
          // Right: breakdown bars
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = counts[star - 1];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 16,
                          child: Text('$star',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280)))),
                      const Icon(Icons.star, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: count / maxCount,
                            backgroundColor: const Color(0xFFF3F4F6),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFF59E0B)),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 24,
                          child: Text('$count',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280)))),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
