import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import 'brand_deco_circles.dart';

class AigoHeader extends StatelessWidget {
  final String? title;
  final List<Widget>? actions;
  final bool showLogo;
  final Widget? bottom;

  const AigoHeader({super.key, this.title, this.actions, this.showLogo = true, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.blueGradient),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          const Positioned.fill(child: BrandDecoCircles()),
          SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Row(
                children: [
                  if (showLogo) ...[
                    SvgPicture.asset('assets/images/logo_white.svg', height: 32),
                  ] else if (title != null)
                    Expanded(child: Text(title!, style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white))),
                  const Spacer(),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            if (bottom != null) bottom!,
          ],
        ),
        ),
        ],
      ),
    );
  }
}
