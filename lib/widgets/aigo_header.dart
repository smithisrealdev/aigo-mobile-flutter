import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

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
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  if (showLogo)
                    Text('aigo', style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1))
                  else if (title != null)
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
    );
  }
}
