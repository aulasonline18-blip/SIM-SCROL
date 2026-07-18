import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../shared/widgets/shared_widgets.dart';
import '../../sim/ui/sim_i18n.dart';
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
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          SimAulaMenuButton(
            onTap: () => showAulaMenu(context, session, textScale: textScale),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerLabel ?? t('lesson'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (progress != null)
                  LinearProgressIndicator(value: (progress! / 100).clamp(0, 1)),
              ],
            ),
          ),
          if (onFontScaleTap != null)
            IconButton(
              tooltip: t('aula_font_scale_label', {
                'level': fontScaleLevel ?? 1,
              }),
              onPressed: onFontScaleTap,
              icon: const Icon(Icons.format_size),
            ),
          if (showReviewButton)
            IconButton(
              tooltip: t('aula_open_review'),
              onPressed: session.openReviewRoom,
              icon: const Icon(Icons.history_edu),
            ),
        ],
      ),
    ),
  );
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
        padding: const EdgeInsets.all(12),
        child: LessonImageStudySurface(
          data: data,
          width: 420,
          height: 560,
          caption: lessonImageCaption(session),
          onImageSettled: onImageSettled,
        ),
      );
    }
    if (session.aulaRuntimeLoading || session.imageStatus == 'loading') {
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
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: caption,
    child: AspectRatio(
      aspectRatio: width / height,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LessonMediaImageView(data: data, onImageSettled: onImageSettled),
            Align(
              alignment: Alignment.bottomCenter,
              child: ColoredBox(
                color: Colors.black54,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    caption,
                    style: const TextStyle(color: Colors.white),
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
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon),
    title: Text(text),
    onTap: onTap,
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
