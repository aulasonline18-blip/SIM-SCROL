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

const double lessonImageStudyAspectRatio = 3 / 4;

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

class LessonVisualBoard extends StatefulWidget {
  const LessonVisualBoard({
    required this.data,
    required this.caption,
    this.onImageSettled,
    super.key,
  });

  final String data;
  final String caption;
  final VoidCallback? onImageSettled;

  @override
  State<LessonVisualBoard> createState() => _LessonVisualBoardState();
}

class _LessonVisualBoardState extends State<LessonVisualBoard> {
  int _stepIndex = 0;
  int _highlightIndex = -1;
  bool _descriptionExpanded = false;

  _LessonBoardVisualKind get _kind => _kindForVisualData(widget.data);

  int get _stepCount => _kind == _LessonBoardVisualKind.stepByStep ? 4 : 0;

  void _advanceStep(int delta) {
    final count = _stepCount;
    if (count <= 0) return;
    setState(() => _stepIndex = (_stepIndex + delta).clamp(0, count - 1));
  }

  void _cycleHighlight() {
    final count = switch (_kind) {
      _LessonBoardVisualKind.comparison => 2,
      _LessonBoardVisualKind.table => 3,
      _LessonBoardVisualKind.conceptMap => 3,
      _ => 0,
    };
    if (count <= 0) return;
    setState(() => _highlightIndex = (_highlightIndex + 1) % count);
  }

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final kind = _kind;
    return Semantics(
      container: true,
      image: true,
      label: widget.caption,
      child: SimLearningSurface(
        tone: SimSurfaceTone.soft,
        padding: const EdgeInsets.all(SimSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _titleForVisualKind(kind),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SimTypography.label.copyWith(color: palette.text),
                  ),
                ),
                Tooltip(
                  message: t('aula_image_expand'),
                  child: SimIconAction(
                    icon: Icons.open_in_full_rounded,
                    semanticLabel: t('aula_image_expand_lesson'),
                    onPressed: () => showLessonImageInspector(
                      context,
                      data: widget.data,
                      caption: widget.caption,
                    ),
                    size: 40,
                    iconSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SimSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: AspectRatio(
                aspectRatio: lessonImageStudyAspectRatio,
                child: Material(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(SimRadius.lg),
                  child: InkWell(
                    onTap: kind == _LessonBoardVisualKind.staticImage
                        ? () => showLessonImageInspector(
                            context,
                            data: widget.data,
                            caption: widget.caption,
                          )
                        : _cycleHighlight,
                    borderRadius: BorderRadius.circular(SimRadius.lg),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
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
                                data: widget.data,
                                onImageSettled: widget.onImageSettled,
                              ),
                            ),
                            if (kind != _LessonBoardVisualKind.staticImage)
                              _VisualBoardOverlay(
                                kind: kind,
                                stepIndex: _stepIndex,
                                highlightIndex: _highlightIndex,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (kind == _LessonBoardVisualKind.stepByStep) ...[
              const SizedBox(height: SimSpacing.sm),
              Row(
                children: [
                  SimIconAction(
                    icon: Icons.chevron_left,
                    semanticLabel: t('visual_board_previous'),
                    onPressed: _stepIndex == 0 ? null : () => _advanceStep(-1),
                    size: 40,
                  ),
                  const SizedBox(width: SimSpacing.sm),
                  Expanded(
                    child: SimProgressRail(
                      value: (_stepIndex + 1) / _stepCount,
                      semanticLabel: t('visual_board_progress'),
                    ),
                  ),
                  const SizedBox(width: SimSpacing.sm),
                  SimIconAction(
                    icon: Icons.chevron_right,
                    semanticLabel: t('visual_board_next'),
                    onPressed: _stepIndex >= _stepCount - 1
                        ? null
                        : () => _advanceStep(1),
                    size: 40,
                  ),
                ],
              ),
            ],
            const SizedBox(height: SimSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.caption,
                    style: SimTypography.caption.copyWith(color: palette.muted),
                    maxLines: _descriptionExpanded ? 5 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: SimSpacing.xs),
                Tooltip(
                  message: t('visual_board_description'),
                  child: SimIconAction(
                    icon: _descriptionExpanded
                        ? Icons.unfold_less
                        : Icons.notes_outlined,
                    semanticLabel: t('visual_board_show_description'),
                    onPressed: () => setState(
                      () => _descriptionExpanded = !_descriptionExpanded,
                    ),
                    size: 40,
                    iconSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LessonImageStudySurface extends StatelessWidget {
  const LessonImageStudySurface({
    required this.data,
    required this.caption,
    this.onImageSettled,
    super.key,
  });

  final String data;
  final String caption;
  final VoidCallback? onImageSettled;

  @override
  Widget build(BuildContext context) => LessonVisualBoard(
    data: data,
    caption: caption,
    onImageSettled: onImageSettled,
  );
}

enum _LessonBoardVisualKind {
  staticImage,
  comparison,
  table,
  stepByStep,
  conceptMap,
}

_LessonBoardVisualKind _kindForVisualData(String data) {
  final lower = data.toLowerCase();
  if (lower.contains('passo') || lower.contains('step')) {
    return _LessonBoardVisualKind.stepByStep;
  }
  if (lower.contains('compar') || lower.contains('versus')) {
    return _LessonBoardVisualKind.comparison;
  }
  if (lower.contains('tabela') || lower.contains('linha')) {
    return _LessonBoardVisualKind.table;
  }
  if (lower.contains('conceit') || lower.contains('mapa')) {
    return _LessonBoardVisualKind.conceptMap;
  }
  return _LessonBoardVisualKind.staticImage;
}

String _titleForVisualKind(_LessonBoardVisualKind kind) => switch (kind) {
  _LessonBoardVisualKind.comparison => t('visual_board_title_comparison'),
  _LessonBoardVisualKind.table => t('visual_board_title_table'),
  _LessonBoardVisualKind.stepByStep => t('visual_board_title_step_by_step'),
  _LessonBoardVisualKind.conceptMap => t('visual_board_title_concept_map'),
  _ => t('visual_board_title_default'),
};

class _VisualBoardOverlay extends StatelessWidget {
  const _VisualBoardOverlay({
    required this.kind,
    required this.stepIndex,
    required this.highlightIndex,
  });

  final _LessonBoardVisualKind kind;
  final int stepIndex;
  final int highlightIndex;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return IgnorePointer(
      child: CustomPaint(
        painter: _VisualBoardOverlayPainter(
          kind: kind,
          stepIndex: stepIndex,
          highlightIndex: highlightIndex,
          color: palette.primary,
          warning: palette.warning,
        ),
      ),
    );
  }
}

class _VisualBoardOverlayPainter extends CustomPainter {
  const _VisualBoardOverlayPainter({
    required this.kind,
    required this.stepIndex,
    required this.highlightIndex,
    required this.color,
    required this.warning,
  });

  final _LessonBoardVisualKind kind;
  final int stepIndex;
  final int highlightIndex;
  final Color color;
  final Color warning;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withValues(alpha: 0.72);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = warning.withValues(alpha: 0.10);

    Rect rect;
    switch (kind) {
      case _LessonBoardVisualKind.comparison:
        final left = highlightIndex <= 0;
        rect = Rect.fromLTWH(
          left ? size.width * 0.05 : size.width * 0.52,
          size.height * 0.16,
          size.width * 0.43,
          size.height * 0.66,
        );
      case _LessonBoardVisualKind.table:
        final row = highlightIndex < 0 ? 0 : highlightIndex.clamp(0, 2);
        rect = Rect.fromLTWH(
          size.width * 0.08,
          size.height * (0.24 + row * 0.17),
          size.width * 0.84,
          size.height * 0.14,
        );
      case _LessonBoardVisualKind.stepByStep:
        rect = Rect.fromLTWH(
          size.width * 0.10,
          size.height * (0.18 + stepIndex.clamp(0, 3) * 0.16),
          size.width * 0.80,
          size.height * 0.13,
        );
      case _LessonBoardVisualKind.conceptMap:
        final i = highlightIndex < 0 ? 0 : highlightIndex.clamp(0, 2);
        final centers = [
          Offset(size.width * 0.50, size.height * 0.25),
          Offset(size.width * 0.30, size.height * 0.58),
          Offset(size.width * 0.70, size.height * 0.58),
        ];
        final center = centers[i];
        rect = Rect.fromCenter(
          center: center,
          width: size.width * 0.32,
          height: size.height * 0.14,
        );
      case _LessonBoardVisualKind.staticImage:
        return;
    }
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _VisualBoardOverlayPainter oldDelegate) {
    return kind != oldDelegate.kind ||
        stepIndex != oldDelegate.stepIndex ||
        highlightIndex != oldDelegate.highlightIndex ||
        color != oldDelegate.color ||
        warning != oldDelegate.warning;
  }
}

Future<void> showLessonImageInspector(
  BuildContext context, {
  required String data,
  required String caption,
}) {
  final palette = SimThemeScope.paletteOf(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog.fullscreen(
        backgroundColor: palette.background,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SimSpacing.md,
                  SimSpacing.xs,
                  SimSpacing.xs,
                  SimSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('aula_image_alt'),
                        style: SimTypography.title.copyWith(
                          color: palette.text,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: t('aula_image_close'),
                      child: SimIconAction(
                        icon: Icons.close_rounded,
                        semanticLabel: t('aula_image_close'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SimSpacing.sm,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(SimRadius.lg),
                      border: Border.all(color: palette.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(SimRadius.lg),
                      child: Semantics(
                        image: true,
                        label: caption,
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 5,
                          child: Center(
                            child: LessonMediaImageView(data: data),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SimSpacing.lg,
                  SimSpacing.sm,
                  SimSpacing.lg,
                  SimSpacing.lg,
                ),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: SimTypography.caption.copyWith(
                    color: palette.muted,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
