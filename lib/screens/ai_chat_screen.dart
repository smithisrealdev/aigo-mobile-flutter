import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/supabase_config.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_deco_circles.dart';
import '../widgets/upgrade_dialog.dart';
import '../services/chat_service.dart';
import '../services/itinerary_service.dart';
import '../services/rate_limit_service.dart';
import '../services/voice_service.dart';
import '../config/supabase_config.dart';

// ── Shimmer ──
class _ShimmerBox extends StatefulWidget {
  final double width, height;
  final BorderRadius borderRadius;
  const _ShimmerBox({required this.width, required this.height, required this.borderRadius});
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}
class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : const Color(0xFFE5E7EB);
    final hi = Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : const Color(0xFFF3F4F6);
    return AnimatedBuilder(animation: _ctrl, builder: (_, __) => Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(borderRadius: widget.borderRadius, gradient: LinearGradient(
        begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0), end: Alignment(-1.0 + 2.0 * _ctrl.value + 1, 0),
        colors: [base, hi, base],
      )),
    ));
  }
}

class AIChatScreen extends ConsumerStatefulWidget {
  final String? initialMessage;
  const AIChatScreen({super.key, this.initialMessage});
  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _isTyping = false;
  bool _isRecording = false;
  final _messages = <_ChatMsg>[];
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
            action: SnackBarAction(label: 'Sign In', onPressed: () => context.go('/login')),
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
  void dispose() { _controller.dispose(); _scrollController.dispose(); _focusNode.dispose(); super.dispose(); }

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transcription failed: $e')),
          );
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
          context, ref,
          currentUsage: quotaResult['current_usage'] as int? ?? 0,
          monthlyLimit: quotaResult['monthly_limit'] as int? ?? 10,
          planName: 'Free',
        );
      }
      return;
    }

    final now = DateTime.now();
    setState(() {
      _messages.add(_ChatMsg(isUser: true, text: text.trim(), time: now));
      _controller.clear();
      _hasText = false;
      _isTyping = true;
    });
    _scrollToBottom();

    // Call the real AI chat service
    ChatService.instance.sendMessage(message: text.trim()).then((reply) {
      if (!mounted) return;

      // Increment AI usage on successful response
      RateLimitService.instance.incrementAiUsage();
      
      // Parse special markers from AI response
      var content = reply.content;
      final tripData = reply.responseData;
      
      // Check for [READY_TO_GENERATE] marker
      if (content.contains('[READY_TO_GENERATE]') && tripData != null) {
        content = content.replaceAll('[READY_TO_GENERATE]', '').trim();
        final tripId = tripData['trip_id'] as String?;
        if (tripId != null) {
          // Generate itinerary and navigate
          _generateAndNavigate(tripId, tripData);
        }
      }
      
      // Check for [TRIP_SUMMARY] marker  
      String? summaryText;
      if (content.contains('[TRIP_SUMMARY]')) {
        final parts = content.split('[TRIP_SUMMARY]');
        content = parts[0].trim();
        if (parts.length > 1) {
          summaryText = parts[1].replaceAll('[/TRIP_SUMMARY]', '').trim();
        }
      }

      setState(() {
        _isTyping = false;
        _messages.add(_ChatMsg(
          isUser: false,
          time: DateTime.now(),
          text: content.isEmpty ? (summaryText ?? 'Trip planned!') : content,
          followUps: reply.responseData?['suggestions'] != null
              ? (reply.responseData!['suggestions'] as List).cast<String>()
              : null,
        ));
      });
      _scrollToBottom();
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMsg(
          isUser: false,
          time: DateTime.now(),
          text: 'Sorry, something went wrong. Please try again.\n\n$e',
        ));
      });
      _scrollToBottom();
    });
  }

  Future<void> _generateAndNavigate(String tripId, Map<String, dynamic> tripData) async {
    try {
      final itinerary = await ItineraryService.instance.generateItinerary(
        params: GenerateItineraryParams(
          destination: tripData['destination']?.toString() ?? '',
          startDate: tripData['start_date']?.toString() ?? '',
          endDate: tripData['end_date']?.toString() ?? '',
        ),
      );
      // Save generated itinerary back to trip
      await SupabaseConfig.client.from('trips').update({'itinerary_data': itinerary, 'status': 'published'}).eq('id', tripId);
      if (mounted) context.push('/itinerary');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate itinerary: $e')));
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // Theme helpers
  Color _bg(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xFF121212) : Colors.white;
  Color _surface(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6);
  Color _cardBg(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white;
  Color _textP(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? Colors.white : AppColors.textPrimary;
  Color _textS(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? Colors.white70 : AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    final bp = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _bg(context),
      body: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(gradient: AppColors.blueGradient),
          clipBehavior: Clip.hardEdge,
          child: Stack(children: [
            const Positioned.fill(child: BrandDecoCircles()),
            SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
              child: Row(children: [
                SvgPicture.asset('assets/images/logo_white.svg', height: 28),
                const Spacer(),
                IconButton(icon: const Icon(Icons.add_comment_outlined, color: Colors.white, size: 22), onPressed: () {}, tooltip: 'New Chat'),
                IconButton(icon: const Icon(Icons.history, color: Colors.white, size: 22), onPressed: () {}, tooltip: 'History'),
              ]),
            )),
          ]),
        ),
        // Context bar
        if (_messages.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.05), border: Border(bottom: BorderSide(color: AppColors.brandBlue.withValues(alpha: 0.1)))),
            child: Row(children: [
              const Icon(Icons.auto_awesome, size: 14, color: AppColors.brandBlue), const SizedBox(width: 6),
              const Text('Planning your trip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.brandBlue)),
              const Spacer(),
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('AI Active', style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
            ]),
          ),
        // Body
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _messages.isEmpty ? _buildWelcome(key: const ValueKey('w')) : _buildChat(key: const ValueKey('c')),
        )),
        // Input
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bp + 8),
          decoration: BoxDecoration(color: _bg(context), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]),
          child: Column(children: [
            Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.only(left: 14, right: 16),
                decoration: BoxDecoration(color: _surface(context), borderRadius: BorderRadius.circular(24)),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, size: 18, color: AppColors.brandBlue), const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: _controller, focusNode: _focusNode, maxLength: _maxChars,
                    style: TextStyle(fontSize: 15, color: _textP(context)),
                    decoration: InputDecoration(hintText: 'Describe your dream trip...', hintStyle: TextStyle(color: _textS(context), fontSize: 15), border: InputBorder.none, counterText: '', contentPadding: const EdgeInsets.symmetric(vertical: 12)),
                    onSubmitted: _send,
                  )),
                ]),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _hasText ? _send(_controller.text) : _toggleVoice(),
                child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: 44, height: 44,
                  decoration: BoxDecoration(gradient: _hasText ? AppColors.blueGradient : null, color: _hasText ? null : (_isRecording ? const Color(0xFFEF4444) : _surface(context)), shape: BoxShape.circle),
                  child: Icon(_hasText ? Icons.arrow_upward_rounded : (_isRecording ? Icons.stop_rounded : Icons.mic_none_rounded), color: _hasText || _isRecording ? Colors.white : _textS(context), size: 22),
                ),
              ),
            ]),
            if (_isRecording)
              Padding(padding: const EdgeInsets.only(top: 6), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Recording...', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textS(context))),
              ])),
            if (_controller.text.length > _maxChars - 100)
              Padding(padding: const EdgeInsets.only(top: 4, right: 56), child: Align(alignment: Alignment.centerRight,
                child: Text('${_controller.text.length}/$_maxChars', style: TextStyle(fontSize: 11, color: _controller.text.length > _maxChars - 20 ? const Color(0xFFEF4444) : _textS(context))),
              )),
          ]),
        ),
      ]),
    );
  }

  // ── Welcome ──
  Widget _buildWelcome({Key? key}) {
    return SingleChildScrollView(key: key, padding: const EdgeInsets.fromLTRB(20, 28, 20, 180), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Let's plan together", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _textP(context), height: 1.2)),
        const SizedBox(height: 6),
        Text('Where should we go?', style: TextStyle(fontSize: 15, color: _textS(context))),
        const SizedBox(height: 20),
        // Capability pills
        Wrap(spacing: 8, runSpacing: 8, children: [
          _capPill(Icons.calendar_month_outlined, 'Itinerary', 'Create an itinerary for my trip'),
          _capPill(Icons.account_balance_wallet_outlined, 'Budget', 'Help me plan a budget for my trip'),
          _capPill(Icons.hotel_outlined, 'Hotels', 'Find hotels for my trip'),
          _capPill(Icons.restaurant_outlined, 'Food', 'Recommend restaurants and local food'),
          _capPill(Icons.map_outlined, 'Activities', 'Suggest activities and things to do'),
          _capPill(Icons.flight_outlined, 'Flights', 'Find flights for my trip'),
        ]),
        const SizedBox(height: 24),
        // Try asking
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.1))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.auto_awesome, size: 16, color: AppColors.brandBlue), SizedBox(width: 6), Text('Try asking...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.brandBlue))]),
            const SizedBox(height: 12),
            _promptRow(Icons.beach_access_outlined, 'Plan a 5-day beach trip under \$800'),
            const SizedBox(height: 8),
            _promptRow(Icons.restaurant_outlined, 'Best street food spots in Bangkok'),
            const SizedBox(height: 8),
            _promptRow(Icons.family_restroom_outlined, 'Family-friendly trip to Tokyo'),
          ]),
        ),
        const SizedBox(height: 24),
        // Prompt chips
        SizedBox(height: 40, child: ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [Colors.white, Colors.white, Colors.transparent], stops: [0.0, 0.85, 1.0], begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(b),
          blendMode: BlendMode.dstIn,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _promptChip('Beach vacation in Bali'), _promptChip('Food tour in Tokyo'), _promptChip('Road trip in Italy'), _promptChip('Weekend in Paris'), _promptChip('Adventure in Chiang Mai'),
          ]),
        )),
        const SizedBox(height: 24),
        // Destinations
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Popular destinations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textP(context))),
          GestureDetector(onTap: () {}, child: const Text('See All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brandBlue))),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 140, child: ShaderMask(
          shaderCallback: (b) => const LinearGradient(colors: [Colors.white, Colors.white, Colors.transparent], stops: [0.0, 0.85, 1.0], begin: Alignment.centerLeft, end: Alignment.centerRight).createShader(b),
          blendMode: BlendMode.dstIn,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _destCard('https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=400&h=300&fit=crop', 'Kyoto', 'Japan', '7 days'),
            const SizedBox(width: 12),
            _destCard('https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?w=400&h=300&fit=crop', 'Santorini', 'Greece', '5 days'),
            const SizedBox(width: 12),
            _destCard('https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=400&h=300&fit=crop', 'Bali', 'Indonesia', '6 days'),
            const SizedBox(width: 12),
            _destCard('https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&h=300&fit=crop', 'Paris', 'France', '4 days'),
          ]),
        )),
      ],
    ));
  }

  Widget _capPill(IconData icon, String label, String query) {
    return Material(color: Colors.transparent, child: InkWell(
      onTap: () => _send(query), borderRadius: BorderRadius.circular(20),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.brandBlue), const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.brandBlue)),
        ]),
      ),
    ));
  }

  Widget _promptChip(String text) {
    return Padding(padding: const EdgeInsets.only(right: 8), child: Material(color: Colors.transparent, child: InkWell(
      onTap: () => _send(text), borderRadius: BorderRadius.circular(20),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: _cardBg(context), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.3))),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.brandBlue)),
      ),
    )));
  }

  Widget _destCard(String url, String name, String country, String dur) {
    return Material(color: Colors.transparent, child: InkWell(
      onTap: () => _send('Plan a trip to $name, $country for $dur'), borderRadius: BorderRadius.circular(16),
      child: Container(width: 140, height: 140, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, placeholder: (_, __) => _ShimmerBox(width: 140, height: 140, borderRadius: BorderRadius.circular(16)), errorWidget: (_, __, ___) => Container(color: _surface(context), child: const Icon(Icons.image_not_supported_outlined))),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54], stops: [0.35, 1.0]))),
          Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: AppColors.brandBlue, borderRadius: BorderRadius.circular(8)), child: Text(dur, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)))),
          Positioned(bottom: 10, left: 10, right: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(country, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
          ])),
        ]),
      ),
    ));
  }

  Widget _promptRow(IconData icon, String text) {
    return Material(color: Colors.transparent, child: InkWell(
      onTap: () => _send(text), borderRadius: BorderRadius.circular(12),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _cardBg(context), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.brandBlue), const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: _textP(context)))),
          const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.brandBluePale),
        ]),
      ),
    ));
  }

  // ── Chat ──
  Widget _buildChat({Key? key}) {
    return ListView.builder(
      key: key, controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length && _isTyping) return _buildTypingIndicator();
        final msg = _messages[i];
        // Avatar grouping: show avatar only if first AI msg or prev was user
        final showAvatar = !msg.isUser && (i == 0 || _messages[i - 1].isUser);
        // Show timestamp if gap > 5min from previous
        final showTime = i == 0 || msg.time.difference(_messages[i - 1].time).inMinutes.abs() > 5;
        // Reactions only on last AI message
        final isLastAi = !msg.isUser && (i == _messages.length - 1 || _messages[i + 1].isUser);
        return _buildMessage(msg, showAvatar: showAvatar, showTime: showTime, showReactions: isLastAi);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Container(margin: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(gradient: AppColors.blueGradient, borderRadius: BorderRadius.circular(8)),
        child: Center(child: SvgPicture.asset('assets/images/logo_white.svg', height: 14))),
      const SizedBox(width: 10),
      Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(color: _surface(context), borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(20), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
        child: const _TypingDots()),
    ]));
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // Parse markdown images ![alt](IMAGE:name) and render as real images
  static final _mdImageRegex = RegExp(r'!\[([^\]]*)\]\(IMAGE:([^)]+)\)');

  Widget _buildRichText(String text) {
    final matches = _mdImageRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: TextStyle(color: _textP(context), fontSize: 15, height: 1.5));
    }

    final widgets = <Widget>[];
    int lastEnd = 0;
    for (final m in matches) {
      if (m.start > lastEnd) {
        final before = text.substring(lastEnd, m.start).trim();
        if (before.isNotEmpty) {
          widgets.add(Text(before, style: TextStyle(color: _textP(context), fontSize: 15, height: 1.5)));
        }
      }
      final placeName = m.group(2) ?? m.group(1) ?? '';
      final query = Uri.encodeComponent(placeName);
      final imageUrl = 'https://images.unsplash.com/photo-1500835556837-99ac94a94552?w=600&q=80&fit=crop';
      final searchUrl = 'https://source.unsplash.com/600x300/?$query,travel';
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: searchUrl,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: 160,
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Icon(Icons.image_outlined, size: 32, color: Color(0xFFD1D5DB))),
            ),
            errorWidget: (_, __, ___) => CachedNetworkImage(
              imageUrl: imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ));
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(placeName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textS(context))),
      ));
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      final after = text.substring(lastEnd).trim();
      if (after.isNotEmpty) {
        widgets.add(Text(after, style: TextStyle(color: _textP(context), fontSize: 15, height: 1.5)));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildMessage(_ChatMsg msg, {required bool showAvatar, required bool showTime, required bool showReactions}) {
    return Column(children: [
      // Timestamp
      if (showTime)
        Padding(padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Text(_formatTime(msg.time), style: TextStyle(fontSize: 11, color: _textS(context)))),

      if (msg.isUser)
        Align(alignment: Alignment.centerRight, child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(gradient: AppColors.blueGradient,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(4)),
            boxShadow: [BoxShadow(color: AppColors.brandBlue.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
        ))
      else
        Container(margin: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Avatar (grouped)
          if (showAvatar)
            Container(width: 28, height: 28, decoration: BoxDecoration(gradient: AppColors.blueGradient, borderRadius: BorderRadius.circular(8)),
              child: Center(child: SvgPicture.asset('assets/images/logo_white.svg', height: 14)))
          else
            const SizedBox(width: 28),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Text bubble
            Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: _surface(context),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(showAvatar ? 4 : 20), topRight: const Radius.circular(20), bottomLeft: const Radius.circular(20), bottomRight: const Radius.circular(20))),
              child: _buildRichText(msg.text)),

            // Rich card with place thumbnails
            if (msg.richCard != null) ...[
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _cardBg(context), borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.15)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppColors.brandBlue), const SizedBox(width: 6),
                    Text(msg.richCard!.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.brandBlue)),
                  ]),
                  const SizedBox(height: 10),
                  // Info items
                  ...msg.richCard!.items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                    Padding(padding: const EdgeInsets.only(right: 8), child: Icon(item.icon, size: 14, color: AppColors.brandBlue)),
                    Expanded(child: Text(item.text, style: TextStyle(fontSize: 13, color: _textP(context), height: 1.4))),
                  ]))),
                  // Place thumbnails (collapsible if >3)
                  if (msg.richCard!.places != null && msg.richCard!.places!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: AppColors.brandBlue.withValues(alpha: 0.1)),
                    const SizedBox(height: 10),
                    ...msg.richCard!.places!.take(3).map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(imageUrl: p.imageUrl, width: 48, height: 48, fit: BoxFit.cover,
                            placeholder: (_, __) => _ShimmerBox(width: 48, height: 48, borderRadius: BorderRadius.circular(10)))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textP(context))),
                          const SizedBox(height: 2),
                          Row(children: [
                            Text(p.subtitle, style: TextStyle(fontSize: 11, color: _textS(context))),
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.star_rounded, size: 11, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 2),
                                Text(p.rating, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                              ])),
                          ]),
                        ])),
                        Icon(Icons.chevron_right_rounded, size: 18, color: _textS(context)),
                      ]),
                    )),
                    if (msg.richCard!.places!.length > 3)
                      Padding(padding: const EdgeInsets.only(bottom: 4),
                        child: GestureDetector(onTap: () {},
                          child: Text('+${msg.richCard!.places!.length - 3} more places', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.brandBlue)))),
                  ],
                  // Action button
                  if (msg.richCard!.actionLabel != null) ...[
                    const SizedBox(height: 6),
                    SizedBox(width: double.infinity, child: Material(color: Colors.transparent, child: InkWell(
                      onTap: () => _send(msg.richCard!.actionLabel!),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(gradient: AppColors.blueGradient, borderRadius: BorderRadius.circular(12)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(msg.richCard!.actionLabel!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                        ])),
                      ),
                    )),
                  ],
                ]),
              ),
            ],

            // Reactions (only last AI)
            if (showReactions) ...[
              const SizedBox(height: 4),
              Row(children: [
                _rxnBtn(Icons.thumb_up_outlined, 'Helpful'),
                const SizedBox(width: 8),
                _rxnBtn(Icons.thumb_down_outlined, 'Not helpful'),
                const SizedBox(width: 8),
                _rxnBtn(Icons.copy_outlined, 'Copy'),
              ]),
            ],

            // Follow-up chips (horizontal scroll!)
            if (msg.followUps != null) ...[
              const SizedBox(height: 10),
              SizedBox(height: 34, child: ListView(
                scrollDirection: Axis.horizontal,
                children: msg.followUps!.map((f) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(color: Colors.transparent, child: InkWell(
                    onTap: () => _send(f), borderRadius: BorderRadius.circular(16),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: _cardBg(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.brandBlue.withValues(alpha: 0.25))),
                      child: Text(f, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.brandBlue))),
                  )),
                )).toList(),
              )),
            ],
          ])),
        ])),
    ]);
  }

  Widget _rxnBtn(IconData icon, String tip) {
    return Tooltip(message: tip, child: GestureDetector(onTap: () {},
      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _surface(context), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: _textS(context)))));
  }
}

// ── Typing dots ──
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}
class _TypingDotsState extends State<_TypingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _c;
  late final List<Animation<double>> _a;
  @override
  void initState() {
    super.initState();
    _c = List.generate(3, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 400)));
    _a = _c.map((c) => Tween(begin: 0.0, end: -6.0).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut))).toList();
    for (var i = 0; i < 3; i++) { Future.delayed(Duration(milliseconds: i * 150), () { if (mounted) _c[i].repeat(reverse: true); }); }
  }
  @override
  void dispose() { for (final c in _c) { c.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => AnimatedBuilder(
    animation: _a[i], builder: (_, __) => Transform.translate(offset: Offset(0, _a[i].value),
      child: Container(width: 7, height: 7, margin: EdgeInsets.only(right: i < 2 ? 4 : 0), decoration: BoxDecoration(color: AppColors.brandBlue.withValues(alpha: 0.5), shape: BoxShape.circle))))));
}

// ── Models ──
class _ChatMsg {
  final bool isUser;
  final String text;
  final DateTime time;
  final _RichCard? richCard;
  final List<String>? followUps;
  _ChatMsg({required this.isUser, required this.text, required this.time, this.richCard, this.followUps});
}
class _RichCard {
  final String title;
  final List<_RichItem> items;
  final List<_PlaceThumb>? places;
  final String? actionLabel;
  _RichCard({required this.title, required this.items, this.places, this.actionLabel});
}
class _RichItem {
  final IconData icon;
  final String text;
  _RichItem({required this.icon, required this.text});
}
class _PlaceThumb {
  final String name, subtitle, rating, imageUrl;
  _PlaceThumb({required this.name, required this.subtitle, required this.rating, required this.imageUrl});
}
