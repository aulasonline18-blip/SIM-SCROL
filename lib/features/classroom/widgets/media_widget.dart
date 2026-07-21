part of '../chat_aula_widgets.dart';

class ChatImageBubble extends StatefulWidget {
  const ChatImageBubble({
    required this.message,
    this.onImageSettled,
    super.key,
  });

  final ChatLessonMessage message;
  final VoidCallback? onImageSettled;

  @override
  State<ChatImageBubble> createState() => _ChatImageBubbleState();
}

class _ChatImageBubbleState extends State<ChatImageBubble> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onImageSettled?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.message.imageData?.trim();
    if (widget.message.imageStatus.toLowerCase() == 'failed') {
      return _StatusText(
        icon: Icons.image_not_supported_outlined,
        text: widget.message.text ?? t('aula_image_unavailable_short'),
        tone: SimSurfaceTone.warning,
      );
    }
    if (data == null || data.isEmpty) {
      return _StatusText(
        icon: Icons.image_outlined,
        text: t('aula_image_loading'),
        tone: SimSurfaceTone.soft,
        loading: true,
      );
    }
    final caption = widget.message.text ?? t('aula_image_alt');
    return LessonVisualBoard(
      data: data,
      caption: caption,
      onImageSettled: widget.onImageSettled,
    );
  }
}
