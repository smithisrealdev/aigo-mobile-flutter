import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/supabase_config.dart';
import '../theme/app_colors.dart';
import '../widgets/upgrade_dialog.dart';
import '../services/chat_service.dart';
import '../services/itinerary_service.dart';
import '../services/rate_limit_service.dart';
import '../services/voice_service.dart';
import '../services/reservation_service.dart';
import '../widgets/chat/chat_message_bubble.dart';
import '../utils/chat_widget_parser.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  final String? initialMessage;
  const AIChatScreen({super.key, this.initialMessage});
  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _isRecording = false;
  bool _isGeneratingItinerary = false;
  static const _maxChars = 500;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
      if (_controller.text.length > _maxChars - 50) setState(() {});
    });
    // Send initial message if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Auth check
      if (SupabaseConfig.client.auth.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please sign in to use AI chat'),
            action: SnackBarAction(
              label: 'Sign In',
              onPressed: () => context.go('/login'),
            ),
          ),
        );
        return;
      }
      if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
        _send(widget.initialMessage!);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleVoice() async {
    if (_isRecording) {
      // Stop and transcribe
      setState(() => _isRecording = false);
      try {
        final voiceSvc = ref.read(voiceServiceProvider);
        final text = await voiceSvc.stopAndTranscribe();
        if (text.isNotEmpty && mounted) {
          _controller.text = text;
          setState(() => _hasText = true);
          _send(text);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Transcription failed: $e')));
        }
      }
    } else {
      // Start recording
      final voiceSvc = ref.read(voiceServiceProvider);
      final granted = await voiceSvc.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }
      final started = await voiceSvc.startRecording();
      if (started && mounted) {
        setState(() => _isRecording = true);
      }
    }
  }

  void _send(String text) async {
    if (text.trim().isEmpty || text.length > _maxChars) return;

    // Check AI quota before sending
    final quotaResult = await RateLimitService.instance.canUseAi();
    if (quotaResult['can_use'] != true) {
      if (mounted) {
        showUpgradeDialog(
          context,
          ref,
          currentUsage: quotaResult['current_usage'] as int? ?? 0,
          monthlyLimit: quotaResult['monthly_limit'] as int? ?? 10,
          planName: 'Free',
        );
      }
      return;
    }

    // Increment AI usage
    RateLimitService.instance.incrementAiUsage();

    // Call ChatNotifier to handle history and streaming
    ref.read(chatServiceProvider).sendMessage(text.trim());

    _controller.clear();
    setState(() => _hasText = false);
    _scrollToBottom();
  }

  Future<void> _generateAndNavigate(ChatState state) async {
    if (_isGeneratingItinerary) return;
    setState(() => _isGeneratingItinerary = true);

    final dest = state.tripSummary?.destination ?? state.tripInfo.destination;
    if (dest == null || dest.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Missing destination. Please specify where you want to go.',
            ),
          ),
        );
      }
      setState(() => _isGeneratingItinerary = false);
      return;
    }

    // Prepare dates
    final now = DateTime.now();
    final startDateStr = now.toIso8601String().split('T')[0];
    final duration =
        state.tripSummary?.duration ?? state.tripInfo.duration ?? 3;
    final endDateStr = now
        .add(Duration(days: duration - 1))
        .toIso8601String()
        .split('T')[0];

    // Collect context for better AI generation
    final contextStr = state.messages
        .where((m) => !m.isError)
        .take(10) // Take last 10 messages for context
        .map((m) => '${m.isUser ? "User" : "AI"}: ${m.content}')
        .join('\n');

    try {
      final result = await ItineraryService.instance.generateItinerary(
        params: GenerateItineraryParams(
          destination: dest,
          startDate: startDateStr,
          endDate: endDateStr,
          budget: state.tripInfo.budget,
          tripStyle: state.tripInfo.tripStyle,
          travelers: state.tripInfo.travelers,
          conversationContext: contextStr,
          tripSummary: state.tripSummary?.toJson(),
        ),
      );

      final itinerary = result['itinerary'];
      final recs =
          (result['recommendedReservations'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      // We need to create a trip record first since this is mobile
      // The edge function `generate-itinerary` might just return the JSON,
      // but let's see if it returns a tripId. If not, we create one locally.
      String tripId = result['tripId'] ?? '';

      if (tripId.isEmpty) {
        final insertRes = await SupabaseConfig.client
            .from('trips')
            .insert({
              'user_id': SupabaseConfig.client.auth.currentUser!.id,
              'destination': dest,
              'start_date': startDateStr,
              'end_date': endDateStr,
              'itinerary_data': itinerary,
              'status': 'published',
            })
            .select('id')
            .single();
        tripId = insertRes['id'] as String;
      } else {
        await SupabaseConfig.client
            .from('trips')
            .update({'itinerary_data': itinerary, 'status': 'published'})
            .eq('id', tripId);
      }

      // Trigger background enrichment
      _runPostGenerationEnrichment(tripId, recs);

      if (mounted) context.push('/itinerary');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate itinerary: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingItinerary = false);
    }
  }

  void _runPostGenerationEnrichment(
    String tripId,
    List<Map<String, dynamic>> recs,
  ) {
    if (recs.isNotEmpty) {
      for (final r in recs) {
        final rec = AIRecommendedReservation.fromJson(r);
        ReservationService.instance.addReservation(
          Reservation(
            id: '',
            tripId: tripId,
            type: rec.type,
            title: rec.title,
            notes:
                'AI Recommendation: ${rec.notes ?? ''}\nBooking options: ${rec.bookingTips?.join(", ") ?? ''}',
            cost: rec.estimatedPrice != null
                ? (rec.estimatedPrice!['amount'] as num?)?.toDouble()
                : null,
          ),
        );
      }
    }

    // Tell packing service to generate a packing list in the background
    SupabaseConfig.client.functions
        .invoke('generate-packing-list', body: {'tripId': tripId})
        .catchError((e) {
          debugPrint('Background packing list generation failed: $e');
          throw e; // Allow error to propagate to catch block
        });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Theme helpers
  Color _bg(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? const Color(0xFF121212)
      : Colors.white;
  Color _surface(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? const Color(0xFF1E1E1E)
      : const Color(0xFFF3F4F6);
  Color _cardBg(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? const Color(0xFF1E1E1E)
      : Colors.white;
  Color _textP(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? Colors.white
      : AppColors.textPrimary;
  Color _textS(BuildContext c) => Theme.of(c).brightness == Brightness.dark
      ? Colors.white70
      : AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    // Listen for AI signaling readiness to generate itinerary
    ref.listen<ChatState>(chatServiceProvider, (previous, next) {
      if (previous != null &&
          !previous.readyToGenerate &&
          next.readyToGenerate) {
        _generateAndNavigate(next);
      }

      // Auto-scroll when new messages arrive or stream updates
      if (previous?.messages.length != next.messages.length ||
          (previous?.isStreaming == false && next.isStreaming == true)) {
        _scrollToBottom();
      }
    });

    final chatState = ref.watch(chatServiceProvider);
    final bp = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg(context),
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/images/logo_white.svg',
                      height: 28,
                      colorFilter: const ColorFilter.mode(
                        const Color(0xFF111827),
                        BlendMode.srcIn,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.add_comment_outlined,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                      onPressed: () =>
                          ref.read(chatServiceProvider.notifier).clearContext(),
                      tooltip: 'New Chat',
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Context bar
          if (chatState.messages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brandBlue.withValues(alpha: 0.05),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.brandBlue.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: AppColors.brandBlue,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Planning your trip',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.brandBlue,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: chatState.isStreaming
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    chatState.isStreaming ? 'AI Thinking' : 'AI Active',
                    style: TextStyle(
                      fontSize: 11,
                      color: chatState.isStreaming
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          // Body
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: chatState.messages.isEmpty
                  ? _buildWelcome(key: const ValueKey('w'))
                  : _buildChat(chatState, key: const ValueKey('c')),
            ),
          ),
          // Input
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bp + 8),
            decoration: BoxDecoration(
              color: _bg(context),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(left: 14, right: 16),
                        decoration: BoxDecoration(
                          color: _surface(context),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 18,
                              color: AppColors.brandBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                maxLength: _maxChars,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _textP(context),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Describe your dream trip...',
                                  hintStyle: TextStyle(
                                    color: _textS(context),
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  counterText: '',
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: _send,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          _hasText ? _send(_controller.text) : _toggleVoice(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _hasText
                              ? AppColors.brandBlue
                              : (_isRecording
                                    ? const Color(0xFFEF4444)
                                    : _surface(context)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _hasText
                              ? Icons.arrow_upward_rounded
                              : (_isRecording
                                    ? Icons.stop_rounded
                                    : Icons.mic_none_rounded),
                          color: _hasText || _isRecording
                              ? Colors.white
                              : _textS(context),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isRecording || _isGeneratingItinerary)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isGeneratingItinerary
                                ? AppColors.brandBlue
                                : const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isGeneratingItinerary
                              ? 'Generating Itinerary...'
                              : 'Recording...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _textS(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_controller.text.length > _maxChars - 100)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 56),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_controller.text.length}/$_maxChars',
                        style: TextStyle(
                          fontSize: 11,
                          color: _controller.text.length > _maxChars - 20
                              ? const Color(0xFFEF4444)
                              : _textS(context),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat ──
  Widget _buildChat(ChatState chatState, {Key? key}) {
    return ListView.builder(
      key: key,
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      itemCount:
          chatState.messages.length +
          (chatState.isLoading &&
                  !chatState.isStreaming &&
                  chatState.messages.last.isUser
              ? 1
              : 0),
      itemBuilder: (_, i) {
        if (i == chatState.messages.length) return _buildTypingIndicator();
        final msg = chatState.messages[i];

        // Avatar grouping: show avatar only if first AI msg or prev was user
        final showAvatar =
            !msg.isUser && (i == 0 || chatState.messages[i - 1].isUser);

        // Show timestamp if gap > 5min from previous
        final showTime =
            i == 0 ||
            msg.timestamp
                    .difference(chatState.messages[i - 1].timestamp)
                    .inMinutes
                    .abs() >
                5;

        // Provide followUps for the last AI message
        List<String>? followUps;
        if (!msg.isUser &&
            i == chatState.messages.length - 1 &&
            !chatState.isStreaming) {
          followUps = parseAigoSuggestions(msg.content);
          if (followUps == null) {
            followUps = _generateFollowUps(
              msg.content,
              chatState.messages[i - 1].content,
            );
          }
        }

        return ChatMessageBubble(
          message: msg,
          showAvatar: showAvatar,
          showTime: showTime,
          followUps: followUps,
          onFollowUpTap: (text) {
            _controller.text = text;
            setState(() => _hasText = true);
            _send(text);
          },
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.brandBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/images/logo_white.svg',
                height: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _surface(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  /// Generate contextual follow-up suggestions based on AI response
  List<String>? _generateFollowUps(String aiResponse, String userMessage) {
    final lower = aiResponse.toLowerCase();
    // If AI is asking about dates/time
    if (lower.contains('when') ||
        lower.contains('เมื่อไหร่') ||
        lower.contains('ช่วงเวลา')) {
      return ['Next month', '3 months from now', 'Not sure yet'];
    }
    // If AI is asking about budget
    if (lower.contains('budget') ||
        lower.contains('งบ') ||
        lower.contains('ค่าใช้จ่าย')) {
      return ['Budget-friendly', 'Mid-range', 'Luxury'];
    }
    // If AI mentions destinations/places
    if (lower.contains('recommend') ||
        lower.contains('แนะนำ') ||
        lower.contains('สถานที่')) {
      return ['Tell me more', 'Other options?', 'Create trip!'];
    }
    // If AI is asking about travel style
    if (lower.contains('style') ||
        lower.contains('สไตล์') ||
        lower.contains('ชอบ')) {
      return ['Adventure', 'Relaxation', 'Culture & Food'];
    }
    // If AI mentions itinerary or planning
    if (lower.contains('itinerary') ||
        lower.contains('plan') ||
        lower.contains('วางแผน')) {
      return ['Generate itinerary', 'Adjust dates', 'Add activities'];
    }
    // Default follow-ups
    return ['Tell me more', 'Plan this trip!', 'Other destinations?'];
  }

  // ── Welcome ──
  Widget _buildWelcome({Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Let's plan together",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _textP(context),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Where should we go?',
            style: TextStyle(fontSize: 15, color: _textS(context)),
          ),
          const SizedBox(height: 20),
          // Capability pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _capPill(
                Icons.calendar_month_outlined,
                'Itinerary',
                'Create an itinerary for my trip',
              ),
              _capPill(
                Icons.account_balance_wallet_outlined,
                'Budget',
                'Help me plan a budget for my trip',
              ),
              _capPill(
                Icons.hotel_outlined,
                'Hotels',
                'Find hotels for my trip',
              ),
              _capPill(
                Icons.restaurant_outlined,
                'Food',
                'Recommend restaurants and local food',
              ),
              _capPill(
                Icons.map_outlined,
                'Activities',
                'Suggest activities and things to do',
              ),
              _capPill(
                Icons.flight_outlined,
                'Flights',
                'Find flights for my trip',
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Try asking
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.brandBlue.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: AppColors.brandBlue,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Try asking...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _promptRow(
                  Icons.beach_access_outlined,
                  'Plan a 5-day beach trip under \$800',
                ),
                const SizedBox(height: 8),
                _promptRow(
                  Icons.restaurant_outlined,
                  'Best street food spots in Bangkok',
                ),
                const SizedBox(height: 8),
                _promptRow(
                  Icons.family_restroom_outlined,
                  'Family-friendly trip to Tokyo',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Prompt chips
          SizedBox(
            height: 40,
            child: ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.85, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(b),
              blendMode: BlendMode.dstIn,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _promptChip('Beach vacation in Bali'),
                  _promptChip('Food tour in Tokyo'),
                  _promptChip('Road trip in Italy'),
                  _promptChip('Weekend in Paris'),
                  _promptChip('Adventure in Chiang Mai'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Destinations
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular destinations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textP(context),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.85, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(b),
              blendMode: BlendMode.dstIn,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _destCard(
                    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=400&h=300&fit=crop',
                    'Kyoto',
                    'Japan',
                    '7 days',
                  ),
                  const SizedBox(width: 12),
                  _destCard(
                    'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?w=400&h=300&fit=crop',
                    'Santorini',
                    'Greece',
                    '5 days',
                  ),
                  const SizedBox(width: 12),
                  _destCard(
                    'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=400&h=300&fit=crop',
                    'Bali',
                    'Indonesia',
                    '6 days',
                  ),
                  const SizedBox(width: 12),
                  _destCard(
                    'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&h=300&fit=crop',
                    'Paris',
                    'France',
                    '4 days',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _capPill(IconData icon, String label, String query) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _controller.text = query;
          setState(() => _hasText = true);
          _send(query);
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.brandBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.brandBlue),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.brandBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _promptChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _controller.text = text;
            setState(() => _hasText = true);
            _send(text);
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _cardBg(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.brandBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.brandBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destCard(String url, String name, String country, String dur) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final query = 'Plan a trip to $name, $country for $dur';
          _controller.text = query;
          setState(() => _hasText = true);
          _send(query);
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox(),
                errorWidget: (_, __, ___) => Container(
                  color: _surface(context),
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dur,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      country,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _promptRow(IconData icon, String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _controller.text = text;
          setState(() => _hasText = true);
          _send(text);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _cardBg(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.brandBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 13, color: _textP(context)),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppColors.brandBluePale,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Typing dots ──
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _c;
  late final List<Animation<double>> _a;
  @override
  void initState() {
    super.initState();
    _c = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _a = _c
        .map(
          (c) => Tween(
            begin: 0.0,
            end: -6.0,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();
    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _c[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      3,
      (i) => AnimatedBuilder(
        animation: _a[i],
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _a[i].value),
          child: Container(
            width: 7,
            height: 7,
            margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ),
  );
}
