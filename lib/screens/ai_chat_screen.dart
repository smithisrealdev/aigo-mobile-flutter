import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});
  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _controller = TextEditingController();
  final _messages = <_ChatMsg>[
    _ChatMsg(isUser: false, text: "Hi! I'm your AI travel planner ✨\nWhere would you like to go?", cards: [
      _PlaceCard('Tokyo, Japan', 'https://picsum.photos/300/200?random=20', '7 days • Culture & Food'),
      _PlaceCard('Bali, Indonesia', 'https://picsum.photos/300/200?random=21', '5 days • Beach & Nature'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppColors.blueGradient),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text('AI Planner', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.flight, color: Colors.white70, size: 16),
                        SizedBox(width: 8),
                        Text('Planning: Tokyo Trip • Mar 15-22', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessage(_messages[i]),
            ),
          ),
          _buildQuickReplies(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMsg msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: msg.isUser ? AppColors.brandBlue : Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: msg.isUser ? const Radius.circular(4) : null,
                  bottomLeft: !msg.isUser ? const Radius.circular(4) : null,
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
              ),
              child: Text(msg.text, style: TextStyle(color: msg.isUser ? Colors.white : AppColors.textPrimary, fontSize: 15, height: 1.5)),
            ),
            if (msg.cards != null) ...[
              const SizedBox(height: 12),
              ...msg.cards!.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
                child: Row(
                  children: [
                    ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)), child: CachedNetworkImage(imageUrl: c.image, width: 80, height: 80, fit: BoxFit.cover)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(c.subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ])),
                    const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.chevron_right, color: AppColors.textSecondary)),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReplies() {
    final replies = ['Plan my trip ✨', 'Show hotels 🏨', 'Best restaurants 🍜', 'Things to do 🎯'];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: replies.map((r) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(r, style: const TextStyle(fontSize: 13, color: AppColors.brandBlue)),
            backgroundColor: AppColors.brandBlue.withValues(alpha: 0.08),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => setState(() => _messages.add(_ChatMsg(isUser: true, text: r))),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Ask me anything...', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(gradient: AppColors.blueGradient, shape: BoxShape.circle),
            child: IconButton(icon: const Icon(Icons.mic, color: Colors.white, size: 20), onPressed: () {}),
          ),
        ],
      ),
    );
  }
}

class _ChatMsg {
  final bool isUser;
  final String text;
  final List<_PlaceCard>? cards;
  _ChatMsg({required this.isUser, required this.text, this.cards});
}

class _PlaceCard {
  final String title, image, subtitle;
  _PlaceCard(this.title, this.image, this.subtitle);
}
