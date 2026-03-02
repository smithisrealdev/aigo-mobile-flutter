import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

// ──────────────────────────────────────────────
// User Journey Screen — AiGo 2026
// Immersive storytelling: "คุณพลอย" multi-agent trip
// ──────────────────────────────────────────────

class UserJourneyScreen extends StatefulWidget {
  const UserJourneyScreen({super.key});

  @override
  State<UserJourneyScreen> createState() => _UserJourneyScreenState();
}

class _UserJourneyScreenState extends State<UserJourneyScreen> {
  final ScrollController _sc = ScrollController();
  double _headerOpacity = 1.0;
  int _selectedPersona = 0; // 0 = พลอย (Family), 1 = เซน (New Gen)

  @override
  void initState() {
    super.initState();
    _sc.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _sc.offset;
    setState(() {
      _headerOpacity = (1.0 - (offset / 200)).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _sc.removeListener(_onScroll);
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FC),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _sc,
            slivers: [
              // ── Hero Header ──
              SliverToBoxAdapter(
                child: _buildHeroHeader(isDark, pad),
              ),

              // ── Persona Selector ──
              SliverToBoxAdapter(
                child: _buildPersonaSelector(isDark),
              ),

              // ═══ Journey Content (persona-specific) ═══
              if (_selectedPersona == 0) ...[

              // ── Intro Card ──
              SliverToBoxAdapter(
                child: _buildIntroCard(isDark),
              ),

              // ── Phase 1 ──
              SliverToBoxAdapter(
                child: _buildPhaseCard(
                  isDark: isDark,
                  phaseNumber: 1,
                  emoji: '📍',
                  title: 'Zero-Effort Input',
                  subtitle: 'จุดประกายทริปแบบไม่ต้องพิมพ์',
                  tagline: 'หมดยุคกางแผนที่เปิดเบราว์เซอร์ 10 แท็บ',
                  userAction:
                      'พลอยไถ TikTok เจอคลิป "คาเฟ่ลับเห็นวิวฟูจิ" แค่แคปหน้าจอเก็บไว้ แล้วโยนรูปพร้อมไฟล์ PDF ตั๋วเครื่องบินลง AiGo รวดเดียว',
                  aiAction:
                      'สแกน PDF ดึงวันเวลาบิน สร้าง Timeline ทันที ใช้พลัง Multimodal วิเคราะห์รูปแคป สกัดพิกัดคาเฟ่ลับแม้ไม่มีชื่อร้าน ปักหมุด Must-Go ภายใน 3 วินาที',
                  aiModel: 'Gemini 3.1 Pro',
                  aiModelColor: const Color(0xFF4285F4),
                  aiModelIcon: Icons.visibility,
                  accentColor: const Color(0xFF4285F4),
                  userIcon: Icons.screenshot_monitor,
                ),
              ),

              // ── Phase 2 ──
              SliverToBoxAdapter(
                child: _buildPhaseCard(
                  isDark: isDark,
                  phaseNumber: 2,
                  emoji: '📍',
                  title: 'Hyper-Personalized Planning',
                  subtitle: 'จัดตารางราวกับมีไกด์ส่วนตัว',
                  tagline:
                      'จัดการข้อจำกัดที่ซับซ้อน (ผู้สูงอายุ + เด็กเล็ก) ได้ในอึดใจเดียว',
                  userAction:
                      'พลอยกดไมค์สั่ง "จัดทริปโตเกียว-ฟูจิ 5 วัน เอาที่แคปไว้ใส่ด้วย ขอจังหวะเที่ยวหลวมๆ เพราะแม่เดินเยอะไม่ได้ หลานต้องมีเวลานอนกลางวัน และคุมงบไม่เกิน 40,000 บาท"',
                  aiAction:
                      'คิดตรรกะพื้นที่-เวลา จัดกรุ๊ปสถานที่ใกล้กันในวันเดียว เลือกสถานีที่มีลิฟต์ให้คุณแม่ เว้น 14:00 ให้หลานนอน คาย JSON เป๊ะ 100% สร้างแผนที่ Interactive ลากสลับคิวได้ทันที',
                  aiModel: 'Claude Sonnet 4.6',
                  aiModelColor: const Color(0xFFD97706),
                  aiModelIcon: Icons.psychology,
                  accentColor: const Color(0xFFD97706),
                  userIcon: Icons.mic,
                ),
              ),

              // ── Phase 3 ──
              SliverToBoxAdapter(
                child: _buildPhaseCard(
                  isDark: isDark,
                  phaseNumber: 3,
                  emoji: '📍',
                  title: 'Autonomous Booking',
                  subtitle: 'เลขาฯ ส่วนตัวที่เหมาจองจบในคลิกเดียว',
                  tagline: 'ให้ AI สายปฏิบัติการไปเจรจาและทำตัวเลขแทน',
                  userAction:
                      'พลอยดูตารางแล้วถูกใจ แพลนหลวมกำลังดี ครอบคลุมทุกที่ เธอสแกน Face ID แล้วกดปุ่มเดียว "Book Entire Trip"',
                  aiAction:
                      'แยกร่างเชื่อม API ของ Agoda (ห้องแฟมิลี่), Klook (ตั๋วสวนสนุก), JR (รถไฟญี่ปุ่น) เปรียบเทียบราคาให้อยู่ในงบ 40,000 บาทเป๊ะ กรอกชื่อ ตัดบัตร E-ticket เด้งเข้า Timeline พร้อมใช้ออฟไลน์',
                  aiModel: 'GPT-5.2',
                  aiModelColor: const Color(0xFF10B981),
                  aiModelIcon: Icons.precision_manufacturing,
                  accentColor: const Color(0xFF10B981),
                  userIcon: Icons.face_unlock_sharp,
                ),
              ),

              // ── Phase 4 ──
              SliverToBoxAdapter(
                child: _buildPhaseCard(
                  isDark: isDark,
                  phaseNumber: 4,
                  emoji: '📍',
                  title: 'On-Trip Dynamic Guardian',
                  subtitle: 'ผู้ช่วยแก้ปัญหาเฉพาะหน้าเวลาแผนล่ม',
                  tagline:
                      'เมื่อเกิดเหตุไม่คาดฝัน AI จะเป็นคนกู้สถานการณ์ให้เอง',
                  userAction:
                      'วันที่ 3 ที่คาวากุจิโกะ พายุเข้า ฝนตกหนัก แผนเดิมล่มสนิท คุณแม่เดินลำบาก หลานเริ่มงอแง',
                  aiAction:
                      'ตรวจพบพายุ ส่ง Push เตือน "🌧️ พายุเข้าฟูจิ! ปรับแผนให้แล้ว" Claude คิด Plan B เสนอพิพิธภัณฑ์สัตว์น้ำ (ในร่ม/มีวีลแชร์/เด็กชอบ) GPT ยกเลิกตั๋วเก่า ซื้อใหม่ เตรียมเรียก Taxi ไว้รอ',
                  aiModel: 'Orchestration System',
                  aiModelColor: const Color(0xFF8B5CF6),
                  aiModelIcon: Icons.hub,
                  accentColor: const Color(0xFF8B5CF6),
                  userIcon: Icons.thunderstorm,
                ),
              ),

              // ── Phase 5 ──
              SliverToBoxAdapter(
                child: _buildPhaseCard(
                  isDark: isDark,
                  phaseNumber: 5,
                  emoji: '📍',
                  title: 'Post-Trip Creator Economy',
                  subtitle: 'เปลี่ยนความทรงจำให้เป็นรายได้',
                  tagline: 'จบปัญหาขี้เกียจแต่งรูป ขี้เกียจเขียนรีวิว',
                  userAction:
                      'กลับถึงกรุงเทพฯ พลอยโยนรูป 200 รูปลง AiGo กด "Create Travel Story" รอ 30 วิ',
                  aiAction:
                      'Vision คัดรูปที่ทุกคนยิ้มสวย ตัดรูปเบลอออก จับคู่กับสถานที่จริง เจเนอเรตบทความรีวิว/Vlog สั้นสไตล์บล็อกเกอร์ พลอยกดโพสต์ลง Community ได้ทันที',
                  aiModel: 'Gemini 3.1 Pro + DeepSeek V4',
                  aiModelColor: const Color(0xFFEC4899),
                  aiModelIcon: Icons.auto_awesome,
                  accentColor: const Color(0xFFEC4899),
                  userIcon: Icons.photo_library,
                ),
              ),

              // ── Monetization ──
              SliverToBoxAdapter(
                child: _buildMonetizationCard(isDark),
              ),

              ] else ...[

              // ═══ ZANE's Journey (New Gen — Seoul) ═══
              SliverToBoxAdapter(child: _buildZaneIntroCard(isDark)),

              // ── Zane Phase 1: Vibe-Driven Discovery ──
              SliverToBoxAdapter(
                child: _buildPhaseCard(
                  isDark: isDark,
                  phaseNumber: 1,
                  emoji: '🎧',
                  title: 'Vibe-Driven Discovery',
                  subtitle: 'หาที่เที่ยวจาก "มู้ด" ไม่ใช่จาก Google',
                  tagline: 'หมดยุคเสิร์ช "10 ที่เที่ยวฮิต" นิวเจนหาไอเดียจาก TikTok และเกลียดการโดนกั๊กพิกัด',
                  userAction:
                      'เซนไถ TikTok เจอคลิปวัยรุ่นเกาหลีปาร์ตี้ในบาร์ใต้ดิน (เจ้าของคลิปไม่บอกชื่อร้าน) เขากด "Share to AiGo" โยนคลิปเข้าแอป แล้วสั่งเสียง "ศุกร์นี้ไปโซล 4 คน เอามู้ดแบบนี้เลย ขอแบบเท่ๆ"',
                  aiAction:
                      'สแกนวิดีโอ สกัดโทนสี สไตล์เพลง สถาปัตยกรรม AI แกะรอยจนรู้พิกัดบาร์ลับในคลิปทันที เข้าใจ Vibe "Seoul Underground" กวาดหา Hidden Gems มู้ดตรงกันมาสร้างเป็น "Vibe Board" ภายใน 3 วินาที',
                  aiModel: 'Gemini 3.1 Pro',
                  aiModelColor: const Color(0xFF06B6D4),
                  aiModelIcon: Icons.video_library,
                  accentColor: const Color(0xFF06B6D4),
                  userIcon: Icons.share,
                  userLabel: '👤 สิ่งที่เซนทำ',
                ),
              ),

              // ── Zane Phase 2: Anti-Planning ──
              SliverToBoxAdapter(
                child: _buildPhaseCard(
                  isDark: isDark,
                  phaseNumber: 2,
                  emoji: '🎧',
                  title: 'Multiplayer "Anti-Planning"',
                  subtitle: 'ปาร์ตี้จัดทริป & ตารางคนตื่นสาย',
                  tagline: 'นิวเจนเกลียดตาราง Excel บังคับตื่น 8 โมง แผนต้องยืดหยุ่นเหมือนเล่นเกม',
                  userAction:
                      'เซนส่งลิงก์ "Shared Canvas" เข้ากรุ๊ปไลน์เพื่อน แอปโชว์ "การ์ดสถานที่" ให้เพื่อน 4 คนปัดขวา (ชอบ) ปัดซ้าย (ไม่ชอบ) สไตล์ Tinder',
                  aiAction:
                      'นำสถานที่ที่เพื่อนปัดขวาตรงกัน มาร้อยเรียงเป็น "Fluid Timeline" ตั้ง Default เริ่มทริปบ่ายโมง คำนวณทิศทางแสงแดดจัดคิวไป "คาเฟ่กระจกใส" ตอน 16:30 น. เพราะแสงจะสาดเข้ามุมร้านถ่ายรูปสวยที่สุดพอดี',
                  aiModel: 'Claude Sonnet 4.6',
                  aiModelColor: const Color(0xFFD97706),
                  aiModelIcon: Icons.psychology,
                  accentColor: const Color(0xFFD97706),
                  userIcon: Icons.swipe,
                  userLabel: '👤 สิ่งที่เซนทำ',
                ),
              ),

              // ── Zane Phase 3: Split-Bill ──
              SliverToBoxAdapter(
                child: _buildPhaseCard(
                  isDark: isDark,
                  phaseNumber: 3,
                  emoji: '🎧',
                  title: 'Frictionless Split-Bill',
                  subtitle: 'จองปุ๊บ หารจ่ายปั๊บ ตัดจบปัญหาทวงเงิน!',
                  tagline: 'Pain Point เบอร์ 1: คนจัดทริปรูดบัตรไปก่อน ตามทวงเพื่อนจนเสียมิตรภาพ',
                  userAction:
                      'เซนเคาะแพลนเสร็จ กดปุ่ม "Book for the Squad" ระบบ Hold Reservation ตั๋วเครื่องบินและ Airbnb ไว้ชั่วคราว',
                  aiAction:
                      'ส่งบิลหาร 4 อัตโนมัติ เด้ง Push Notification / QR Code ให้เพื่อนสแกนจ่าย PromptPay หรือ Apple Pay ครบ 4 คนใน 15 นาทีถึงคอนเฟิร์มตั๋ว ใครโอนช้า AI ส่งข้อความไปจิกให้เอง!',
                  aiModel: 'GPT-5.2 + Smart Contract',
                  aiModelColor: const Color(0xFF10B981),
                  aiModelIcon: Icons.precision_manufacturing,
                  accentColor: const Color(0xFF10B981),
                  userIcon: Icons.group,
                  userLabel: '👤 สิ่งที่เซนทำ',
                ),
              ),

              // ── Zane Phase 4: Hangover & FOMO ──
              SliverToBoxAdapter(
                child: _buildPhaseCard(
                  isDark: isDark,
                  phaseNumber: 4,
                  emoji: '🎧',
                  title: 'Hangover Pivot & FOMO Guardian',
                  subtitle: 'ตื่นสาย แผนล่ม แต่เจออีเวนต์ลับ',
                  tagline: 'คนรุ่นใหม่เป็น FOMO ถ้ามีอะไรเจ๋งจัดตอนนี้ พวกเขาต้องได้ไป',
                  userAction:
                      'ตื่นบ่ายสาม เซนกดปุ่ม "Hangover Mode" และยกกล้องมือถือส่องถนน (AR Mode)',
                  aiAction:
                      'ดักฟัง X (Twitter) และ Threads แบบ Real-time พบ Pop-up Store แจก Art Toy ลับๆ ห่างไป 3 ซอย จัดแค่วันนี้! ยกเลิกตั๋วมิวเซียม Refund เงินเข้าบัญชีเพื่อนเงียบๆ ดัน AR Navigation (ลูกศร 3D นีออน) นำทางเซนไปถึงงาน Pop-up',
                  aiModel: 'Multi-Agent + Social Listening',
                  aiModelColor: const Color(0xFF8B5CF6),
                  aiModelIcon: Icons.hub,
                  accentColor: const Color(0xFF8B5CF6),
                  userIcon: Icons.local_bar,
                  userLabel: '👤 สิ่งที่เซนทำ',
                ),
              ),

              // ── Zane Phase 5: Viral Flex ──
              SliverToBoxAdapter(
                child: _buildPhaseCard(
                  isDark: isDark,
                  phaseNumber: 5,
                  emoji: '🎧',
                  title: 'Zero-Edit Viral Flex',
                  subtitle: 'ตัดคลิปไวรัล ป้ายยาปั๊บ รับเงินเลย',
                  tagline: 'คอนเทนต์คือสกุลเงินใหม่ ทุกทริปต้องอวดได้ และต้องทำเงินได้',
                  userAction:
                      'ระหว่างรอเครื่องบินกลับ เซนเลือกคลิปดิบ 100 คลิปลงแอป กดปุ่ม "Create My Vibe"',
                  aiAction:
                      'สแกนหาเพลง Viral Trend ใน TikTok ณ ชั่วโมงนั้น คัดเฉพาะช็อตเท่ๆ ตัดต่อให้ตรงจังหวะเพลง ย้อมสีสไตล์ฟิล์ม Y2K เสร็จใน 10 วินาที พร้อมลายน้ำ "AiGo: Clone My Vibe" ให้คนจองทริปตามเซน',
                  aiModel: 'Gemini 3.1 Pro + DeepSeek V4',
                  aiModelColor: const Color(0xFFEC4899),
                  aiModelIcon: Icons.auto_awesome,
                  accentColor: const Color(0xFFEC4899),
                  userIcon: Icons.movie_creation,
                  userLabel: '👤 สิ่งที่เซนทำ',
                ),
              ),

              // ── Zane Monetization ──
              SliverToBoxAdapter(child: _buildZaneMonetizationCard(isDark)),

              ], // end persona conditional

              // ── AI Architecture Summary ──
              SliverToBoxAdapter(
                child: _buildArchitectureSummary(isDark),
              ),

              // ── Value Proposition ──
              SliverToBoxAdapter(
                child: _buildValueProposition(isDark),
              ),

              // Bottom spacing
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),

          // ── Floating Back Button ──
          Positioned(
            top: pad.top + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white)
                      .withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // HERO HEADER
  // ════════════════════════════════════════════
  Widget _buildHeroHeader(bool isDark, EdgeInsets pad) {
    return Opacity(
      opacity: _headerOpacity,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: pad.top + 56,
          left: 24,
          right: 24,
          bottom: 32,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A5EFF),
              Color(0xFF7C3AED),
              Color(0xFFEC4899),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '✨ AiGo 2026 Vision',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'User Journey',
              style: GoogleFonts.dmSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'เส้นทางประสบการณ์ผู้ใช้งาน',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 16),
            // AI Models row
            Row(
              children: [
                _aiChip('Gemini', const Color(0xFF4285F4), Icons.visibility),
                const SizedBox(width: 8),
                _aiChip('Claude', const Color(0xFFD97706), Icons.psychology),
                const SizedBox(width: 8),
                _aiChip('GPT', const Color(0xFF10B981), Icons.precision_manufacturing),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // INTRO CARD
  // ════════════════════════════════════════════
  Widget _buildIntroCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkMode : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A5EFF), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.hub, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Multi-Agent Orchestration',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'ผสานพลัง AI ระดับท็อปหลายค่าย',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Character intro
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('👩', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'คุณพลอย — สาวออฟฟิศวัย 30',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'จัดทริปพาคุณแม่วัย 65 (ปวดเข่า) และหลานชายวัย 5 ขวบ ไปโตเกียว-ฟูจิ 5 วัน 4 คืน',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Travel party
            Row(
              children: [
                _travelPartyChip('👩', 'พลอย (30)', const Color(0xFFEC4899)),
                const SizedBox(width: 8),
                _travelPartyChip('👵', 'คุณแม่ (65)', const Color(0xFF8B5CF6)),
                const SizedBox(width: 8),
                _travelPartyChip('👦', 'หลาน (5)', const Color(0xFF4285F4)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _travelPartyChip(String emoji, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // PHASE CARD
  // ════════════════════════════════════════════
  Widget _buildPhaseCard({
    required bool isDark,
    required int phaseNumber,
    required String emoji,
    required String title,
    required String subtitle,
    required String tagline,
    required String userAction,
    required String aiAction,
    required String aiModel,
    required Color aiModelColor,
    required IconData aiModelIcon,
    required Color accentColor,
    required IconData userIcon,
    String userLabel = '👤 สิ่งที่คุณพลอยทำ',
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkMode : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phase header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withValues(alpha: 0.08),
                    accentColor.withValues(alpha: 0.02),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Phase number badge
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '$phaseNumber',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.dmSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tagline,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: accentColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                children: [
                  // User action
                  _actionRow(
                    isDark: isDark,
                    icon: userIcon,
                    iconColor: const Color(0xFF1A5EFF),
                    label: userLabel,
                    content: userAction,
                    bgColor: const Color(0xFF1A5EFF).withValues(alpha: 0.05),
                  ),
                  const SizedBox(height: 12),
                  // AI action
                  _actionRow(
                    isDark: isDark,
                    icon: aiModelIcon,
                    iconColor: aiModelColor,
                    label: '🤖 AI Behind the Magic',
                    content: aiAction,
                    bgColor: aiModelColor.withValues(alpha: 0.05),
                    aiModelBadge: aiModel,
                    aiModelBadgeColor: aiModelColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String content,
    required Color bgColor,
    String? aiModelBadge,
    Color? aiModelBadgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : iconColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (aiModelBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: aiModelBadgeColor?.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    aiModelBadge,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: aiModelBadgeColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // MONETIZATION CARD
  // ════════════════════════════════════════════
  Widget _buildMonetizationCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      const Icon(Icons.monetization_on, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '💰 Creator Economy Loop',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'เมื่อผู้ใช้ AiGo คนอื่นมาเห็นรีวิวของพลอย แล้วกดปุ่ม "Clone Trip (เที่ยวตามพลอย)" และเกิดการจอง พลอยจะได้รับ Affiliate Commission กลับมาเป็นเหรียญ AiGo Coins สำหรับบินฟรีในทริปต่อไป!',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: const Color(0xFF78350F),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            // Flow diagram
            Row(
              children: [
                _flowStep('📝', 'โพสต์รีวิว'),
                _flowArrow(),
                _flowStep('👥', 'คนกด Clone'),
                _flowArrow(),
                _flowStep('💳', 'เกิดการจอง'),
                _flowArrow(),
                _flowStep('🪙', 'ได้ Coins!'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowStep(String emoji, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF92400E),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _flowArrow() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Icon(Icons.arrow_forward, size: 14, color: Color(0xFFB45309)),
    );
  }

  // ════════════════════════════════════════════
  // ARCHITECTURE SUMMARY
  // ════════════════════════════════════════════
  Widget _buildArchitectureSummary(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkMode : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🏗️ AI Architecture',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _archRow(
              Icons.visibility,
              'Gemini — ดวงตา',
              'รับข้อมูลดิบ ภาพ PDF เสียง แปลงเป็นข้อมูลที่ใช้ได้',
              const Color(0xFF4285F4),
              isDark,
            ),
            _archConnector(isDark),
            _archRow(
              Icons.psychology,
              'Claude — สมอง',
              'คิดวิเคราะห์ วางแผน ตัดสินใจเชิงตรรกะ',
              const Color(0xFFD97706),
              isDark,
            ),
            _archConnector(isDark),
            _archRow(
              Icons.precision_manufacturing,
              'GPT — มือเท้า',
              'ลงมือทำ จอง ยกเลิก สร้างเอกสาร',
              const Color(0xFF10B981),
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _archRow(
    IconData icon,
    String title,
    String desc,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                desc,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _archConnector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 21),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Container(
            width: 2,
            height: 20,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.3),
                  (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.1),
                ],
              ),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color:
                (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════
  // VALUE PROPOSITION (persona-aware)
  // ════════════════════════════════════════════
  Widget _buildValueProposition(bool isDark) {
    final isPloy = _selectedPersona == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPloy
                ? const [Color(0xFF1A5EFF), Color(0xFF7C3AED)]
                : const [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (isPloy ? const Color(0xFF1A5EFF) : const Color(0xFF06B6D4))
                  .withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPloy ? '🌟' : '🔥',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 12),
            Text(
              isPloy
                  ? 'จาก Do-it-yourself\nสู่ Autonomous Travel Concierge'
                  : 'จากแอปจองตั๋ว\nสู่ Lifestyle & Social Super App',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isPloy
                  ? 'การทำงานร่วมกันของ AI ระดับท็อป จะเปลี่ยน AiGo จากแอปท่องเที่ยวที่ต้องทำเองทุกอย่าง กลายเป็นผู้ช่วยส่วนตัวที่ทำให้ทุกสิ่งสมบูรณ์แบบ'
                  : 'AiGo จะก้าวข้ามการเป็นแอปจองตั๋ว (OTA) ไปสู่การเป็น Super App ที่วัยรุ่นต้องกดเข้าใช้ทุกวัน แม้ในวันที่ไม่ได้ไปเที่ยวก็ตาม',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  isPloy
                      ? 'สร้างความประทับใจจนไม่อยากกลับไปจองทริปแบบเดิม ✈️'
                      : 'เทสต์ดี • ยืดหยุ่น • แฟร์เรื่องเงิน • เปลี่ยนยอดวิวเป็นรายได้ 🔥',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isPloy ? const Color(0xFF1A5EFF) : const Color(0xFF0891B2),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // PERSONA SELECTOR
  // ════════════════════════════════════════════
  Widget _buildPersonaSelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkMode : const Color(0xFFF1F3F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            _personaTab(
              index: 0,
              emoji: '👩',
              label: 'พลอย — ครอบครัว',
              sublabel: 'Family Guardian',
              isDark: isDark,
            ),
            const SizedBox(width: 4),
            _personaTab(
              index: 1,
              emoji: '🧑‍🎤',
              label: 'เซน — นิวเจน',
              sublabel: 'Ultimate Wingman',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _personaTab({
    required int index,
    required String emoji,
    required String label,
    required String sublabel,
    required bool isDark,
  }) {
    final selected = _selectedPersona == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedPersona != index) {
            setState(() => _selectedPersona = index);
            _sc.animateTo(0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary)
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary),
                ),
              ),
              Text(
                sublabel,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: selected
                      ? (index == 0
                          ? const Color(0xFFEC4899)
                          : const Color(0xFF06B6D4))
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // ZANE INTRO CARD
  // ════════════════════════════════════════════
  Widget _buildZaneIntroCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDarkMode : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      const Icon(Icons.bolt, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The Ultimate Wingman',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'คู่หูสายสตรีทสุดคูลของนิวเจน',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Character intro
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF06B6D4).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child:
                          Text('🧑‍🎤', style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'เซน (Zane) — ครีเอทีฟจบใหม่วัย 22',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'รวมแก๊งเพื่อนสนิท 4 คนไปทริปไฟลุก โซล (เกาหลีใต้) ตะลุยคาเฟ่ลับ ร้านวินเทจ และทำคอนเทนต์',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Squad
            Row(
              children: [
                _travelPartyChip(
                    '🧑‍🎤', 'เซน (22)', const Color(0xFF06B6D4)),
                const SizedBox(width: 6),
                _travelPartyChip(
                    '🎸', 'มิว (22)', const Color(0xFF8B5CF6)),
                const SizedBox(width: 6),
                _travelPartyChip(
                    '📸', 'เฟิร์น (21)', const Color(0xFFEC4899)),
                const SizedBox(width: 6),
                _travelPartyChip(
                    '🎮', 'ไบร์ท (23)', const Color(0xFFF59E0B)),
              ],
            ),
            const SizedBox(height: 12),
            // Vibe tags
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _vibeTag('🎵 Seoul Underground', const Color(0xFF06B6D4)),
                _vibeTag('☕ คาเฟ่ลับ', const Color(0xFF8B5CF6)),
                _vibeTag('👗 Vintage', const Color(0xFFEC4899)),
                _vibeTag('📱 Content Creator', const Color(0xFFF59E0B)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _vibeTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════
  // ZANE MONETIZATION CARD
  // ════════════════════════════════════════════
  Widget _buildZaneMonetizationCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFCFFAFE), Color(0xFFE0E7FF)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.trending_up,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '🔥 Micro-Creator Economy',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0E7490),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'คลิปของเซนแมส! วัยรุ่นคนอื่นกดลิงก์ "Clone My Vibe" จองทริปตามรอยเซน เซนได้รับ Affiliate Commission เด้งเข้าบัญชีทันที เปลี่ยนจากนักท่องเที่ยวธรรมดาเป็น Micro-Creator ที่สร้าง Passive Income จากไลฟ์สไตล์ตัวเอง',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: const Color(0xFF155E75),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            // Flow diagram
            Row(
              children: [
                _zaneFlowStep('🎬', 'สร้างคลิป'),
                _zaneFlowArrow(),
                _zaneFlowStep('🔥', 'คลิปไวรัล'),
                _zaneFlowArrow(),
                _zaneFlowStep('🔗', 'Clone Vibe'),
                _zaneFlowArrow(),
                _zaneFlowStep('💸', 'รับ Commission!'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _zaneFlowStep(String emoji, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0E7490),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _zaneFlowArrow() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Icon(Icons.arrow_forward, size: 14, color: Color(0xFF0891B2)),
    );
  }
}
