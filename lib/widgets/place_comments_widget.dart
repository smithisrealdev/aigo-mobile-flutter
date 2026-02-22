import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/comment_service.dart';
import '../theme/app_colors.dart';

/// Shows user comments for a place and an add-comment form.
class PlaceCommentsWidget extends ConsumerStatefulWidget {
  final String tripId;
  final String placeId;

  const PlaceCommentsWidget({
    super.key,
    required this.tripId,
    required this.placeId,
  });

  @override
  ConsumerState<PlaceCommentsWidget> createState() =>
      _PlaceCommentsWidgetState();
}

class _PlaceCommentsWidgetState extends ConsumerState<PlaceCommentsWidget> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    final result = await CommentService.instance.addComment(
      tripId: widget.tripId,
      placeId: widget.placeId,
      content: text,
    );
    setState(() => _submitting = false);

    if (result != null) {
      _controller.clear();
      ref.invalidate(placeCommentsProvider(
          (tripId: widget.tripId, placeId: widget.placeId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(
      placeCommentsProvider(
          (tripId: widget.tripId, placeId: widget.placeId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Comments',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        // Add comment row
        Row(children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _addComment(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _submitting ? null : _addComment,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send, color: AppColors.brandBlue),
          ),
        ]),
        const SizedBox(height: 12),
        commentsAsync.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.brandBlue))),
          error: (_, __) => const Text('Failed to load comments',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          data: (comments) {
            if (comments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No comments yet. Be the first!',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              );
            }
            return Column(
              children: comments
                  .map((c) => _CommentTile(comment: c))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PlaceComment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (comment.userAvatar != null)
              CircleAvatar(
                backgroundImage: NetworkImage(comment.userAvatar!),
                radius: 12,
              )
            else
              const CircleAvatar(
                  radius: 12,
                  child: Icon(Icons.person, size: 14)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                comment.userName ?? 'Anonymous',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Text(
              _formatDate(comment.createdAt),
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ]),
          const SizedBox(height: 6),
          Text(comment.content,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4)),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
