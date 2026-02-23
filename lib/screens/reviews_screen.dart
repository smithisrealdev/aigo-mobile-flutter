import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';
import '../widgets/review_summary.dart';
import '../widgets/review_list.dart';
import '../widgets/review_input.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  final String? tripId;
  final String? placeId;
  final String? title;

  const ReviewsScreen({super.key, this.tripId, this.placeId, this.title});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  List<Review> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (widget.tripId != null) {
      _reviews =
          await ReviewService.instance.getReviewsForTrip(widget.tripId!);
    } else if (widget.placeId != null) {
      _reviews =
          await ReviewService.instance.getReviewsForPlace(widget.placeId!);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showWriteReview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: ReviewInput(
          onSubmit: (rating, comment, photos) async {
            final user = SupabaseConfig.client.auth.currentUser;
            if (user == null) return;
            final review = Review(
              id: '',
              userId: user.id,
              userName: user.userMetadata?['full_name'] as String? ??
                  user.email?.split('@').first ??
                  'User',
              userAvatar: user.userMetadata?['avatar_url'] as String?,
              tripId: widget.tripId,
              placeId: widget.placeId,
              rating: rating,
              comment: comment,
              photos: photos,
              createdAt: DateTime.now(),
            );
            await ReviewService.instance.addReview(review);
            if (mounted) Navigator.pop(context);
            _load();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(widget.title ?? 'Reviews',
            style: const TextStyle(
                color: Color(0xFF111827), fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ReviewSummary(reviews: _reviews),
            const SizedBox(height: 16),
            ReviewList(reviews: _reviews, loading: _loading),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showWriteReview,
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.rate_review, color: Colors.white),
      ),
    );
  }
}
