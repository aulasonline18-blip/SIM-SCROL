import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../shared/widgets/shared_widgets.dart';
import '../../sim/classroom/pedagogical_slot_visibility.dart';
import '../../sim/media/visual_router_n2.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';
import '../session/lab_session.dart';

class AulaTopBar extends StatelessWidget {
  const AulaTopBar({
    required this.session,
    this.showReviewButton = false,
    this.progress,
    this.headerLabel,
    this.textScale = 1,
    this.fontScaleLevel,
    this.onFontScaleTap,
    super.key,
  });

  final LabSession session;
  final bool showReviewButton;
  final double? progress;
  final String? headerLabel;
  final double textScale;
  final int? fontScaleLevel;
  final VoidCallback? onFontScaleTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final progressValue = progress == null
        ? null
        : (progress! / 100).clamp(0.0, 1.0);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.elevatedSurface.withValues(
              alpha: palette.dark ? 0.96 : 0.94,
            ),
            borderRadius: BorderRadius.circular(SimRadius.xl),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                SimAulaMenuButton(
                  onTap: () =>
                      showAulaMenu(context, session, textScale: textScale),
                ),
                const SizedBox(width: SimSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        headerLabel ?? t('lesson'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SimTypography.label.copyWith(
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (progressValue != null)
                        SimProgressRail(
                          value: progressValue,
                          height: 6,
                          semanticLabel: t('progress'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: SimSpacing.sm),
                if (onFontScaleTap != null)
                  SimIconAction(
                    icon: Icons.format_size,
                    semanticLabel: t('aula_font_scale_label', {
                      'level': fontScaleLevel ?? 1,
                    }),
                    onPressed: onFontScaleTap,
                    size: 40,
                    iconSize: 18,
                  ),
                _ClassroomDarkModeButton(),
                if (showReviewButton)
                  SimIconAction(
                    icon: Icons.history_edu,
                    semanticLabel: t('aula_open_review'),
                    onPressed: session.openReviewRoom,
                    size: 40,
                    iconSize: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassroomDarkModeButton extends StatelessWidget {
  const _ClassroomDarkModeButton();

  @override
  Widget build(BuildContext context) {
    final scope = SimThemeScope.of(context);
    final icon = scope.darkMode
        ? Icons.light_mode_outlined
        : Icons.dark_mode_outlined;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SimIconAction(
        icon: icon,
        semanticLabel: scope.darkMode ? t('theme_light') : t('theme_dark'),
        onPressed: scope.onToggleDarkMode,
        size: 40,
        iconSize: 18,
      ),
    );
  }
}

class LessonImagePanel extends StatelessWidget {
  const LessonImagePanel({
    required this.session,
    this.onImageSettled,
    super.key,
  });

  final LabSession session;
  final VoidCallback? onImageSettled;

  @override
  Widget build(BuildContext context) {
    final data = session.aulaSnapshot?.imagem?.trim();
    if (data != null && data.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: SimSpacing.sm),
        child: LessonImageStudySurface(
          data: data,
          width: 420,
          height: 560,
          caption: lessonImageCaption(session),
          onImageSettled: onImageSettled,
        ),
      );
    }
    if (session.imageStatus == 'loading' &&
        !hasValidPedagogicalContent(session.aulaSnapshot?.conteudo)) {
      return StatusLine(
        icon: Icons.image,
        text: t('aula_image_loading'),
        loading: true,
      );
    }
    if (session.imageError != null) return const LessonImageErrorView();
    return const SizedBox.shrink();
  }
}

String lessonImageCaption(LabSession session) => t('aula_image_alt');

class LessonImageStudySurface extends StatelessWidget {
  const LessonImageStudySurface({
    required this.data,
    required this.width,
    required this.height,
    required this.caption,
    this.onImageSettled,
    super.key,
  });

  final String data;
  final double width;
  final double height;
  final String caption;
  final VoidCallback? onImageSettled;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      image: true,
      label: caption,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: AspectRatio(
          aspectRatio: width / height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surfaceSoft,
              borderRadius: BorderRadius.circular(SimRadius.lg),
              border: Border.all(color: palette.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SimRadius.lg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(SimSpacing.xs),
                    child: LessonMediaImageView(
                      data: data,
                      onImageSettled: onImageSettled,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ColoredBox(
                      color: palette.surface.withValues(alpha: 0.92),
                      child: Padding(
                        padding: const EdgeInsets.all(SimSpacing.xs),
                        child: Text(
                          caption,
                          style: SimTypography.caption.copyWith(
                            color: palette.muted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LessonMediaImageView extends StatefulWidget {
  const LessonMediaImageView({
    required this.data,
    this.compact = false,
    this.onImageSettled,
    super.key,
  });

  final String data;
  final bool compact;
  final VoidCallback? onImageSettled;

  @override
  State<LessonMediaImageView> createState() => _LessonMediaImageViewState();
}

class _LessonMediaImageViewState extends State<LessonMediaImageView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onImageSettled?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isSafeInlineSvg(widget.data)) {
      return SvgPicture.string(widget.data, fit: BoxFit.contain);
    }
    final bytes = _decodeDataUrl(widget.data);
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.contain);
    }
    if (widget.data.startsWith('http')) {
      return Image.network(widget.data, fit: BoxFit.contain);
    }
    return LessonImageErrorView(compact: widget.compact);
  }
}

class LessonImageErrorView extends StatelessWidget {
  const LessonImageErrorView({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(compact ? 8 : 16),
      child: Text(t('aula_image_unavailable_short')),
    ),
  );
}

class StatusLine extends StatelessWidget {
  const StatusLine({
    required this.icon,
    required this.text,
    this.loading = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SimStatusSurface(
    tone: SimSurfaceTone.soft,
    icon: loading ? Icons.auto_awesome : icon,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: SimTypography.caption),
        if (loading) ...[
          const SizedBox(height: SimSpacing.xs),
          const LinearProgressIndicator(minHeight: 3),
        ],
      ],
    ),
  );
}

Uint8List? _decodeDataUrl(String data) {
  final comma = data.indexOf(',');
  if (!data.startsWith('data:') || comma < 0) return null;
  try {
    return base64Decode(data.substring(comma + 1));
  } on FormatException {
    return null;
  }
}
