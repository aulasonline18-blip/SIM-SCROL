import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../sim_design_system.dart';
import '../sim_i18n.dart';
import '../sim_theme.dart';

// §2.1 CyberStepShell — casca dos passos T03, T04, T06
// Barra de progresso fina (6px) topo + label "Step {n} of {total}"
// Fundo: gradient_bg (#FFFFFF → #F3F4F6 vertical)
class CyberStepShell extends StatelessWidget {
  const CyberStepShell({
    super.key,
    required this.step,
    required this.total,
    required this.child,
  });

  final int step;
  final int total;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pagePadding = SimBreakpoints.pagePadding(width);
    final contentWidth = SimBreakpoints.learningMaxWidth(width);
    final palette = SimThemeScope.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.background,
              palette.surfaceSoft,
              palette.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Topo: barra de progresso + label
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pagePadding.left,
                  20,
                  pagePadding.right,
                  12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          // Trilha
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: palette.border),
                            ),
                          ),
                          // Preenchimento animado
                          AnimatedFractionallySizedBox(
                            widthFactor: step / total,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [palette.primary, palette.muted],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t('step_of', {'n': step, 'total': total}),
                      style: TextStyle(
                        fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              // Corpo
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentWidth),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: SimBreakpoints.isTablet(width) ? 8 : 4,
                          vertical: SimBreakpoints.isTablet(width) ? 40 : 28,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
