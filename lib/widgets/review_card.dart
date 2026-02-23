import 'package:flutter/material.dart';
import '../models/review_model.dart';

class ReviewCard extends StatefulWidget {
  final Review review;
  final VoidCallback? onHelpful;
  final VoidCallback? onPhotoTap;

  const ReviewCard({
    super.key,
    required this.review,
    this.onHelpful,
    this.onPhotoTap,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool _expanded = false;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365}y ago';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final longComment = r.comment.length > 200;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + name + verified + date
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    r.userAvatar != null ? NetworkImage(r.userAvatar!) : null,
                child: r.userAvatar == null
                    ? Text(r.userName.isNotEmpty ? r.userName[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.w600))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(r.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF111827)),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (r.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 16, color: Color(0xFF10B981)),
                      ],
                    ]),
                    Text(_timeAgo(r.createdAt),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stars
          Row(
            children: List.generate(
                5,
                (i) => Icon(
                      i < r.rating.round() ? Icons.star : Icons.star_border,
                      size: 18,
                      color: const Color(0xFFF59E0B),
                    )),
          ),
          const SizedBox(height: 8),

          // Comment
          GestureDetector(
            onTap: longComment ? () => setState(() => _expanded = !_expanded) : null,
            child: Text(
              _expanded || !longComment
                  ? r.comment
                  : '${r.comment.substring(0, 200)}...',
              style: const TextStyle(fontSize: 14, color: Color(0xFF111827), height: 1.4),
            ),
          ),
          if (longComment)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_expanded ? 'Show less' : 'Read more',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w500)),
              ),
            ),

          // Photos
          if (r.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: widget.onPhotoTap,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(r.photos[i],
                        width: 72, height: 72, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Helpful button
          GestureDetector(
            onTap: widget.onHelpful,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.thumb_up_outlined,
                    size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  r.helpfulCount > 0
                      ? 'Helpful (${r.helpfulCount})'
                      : 'Helpful',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
