import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/sim_constants.dart';
import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/auxiliary/doubt_input_sheet.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/responsive/sim_responsive.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';

class DoubtInputSheet extends StatefulWidget {
  const DoubtInputSheet({
    required this.controller,
    required this.busy,
    required this.onSubmit,
    required this.onClose,
    this.initialImage,
    super.key,
  });

  final TextEditingController controller;
  final bool busy;
  final void Function(DoubtInputDraft input) onSubmit;
  final VoidCallback onClose;

  @visibleForTesting
  final DoubtImagePayload? initialImage;

  @override
  State<DoubtInputSheet> createState() => _DoubtInputSheetState();
}

class _DoubtInputSheetState extends State<DoubtInputSheet> {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFocusNode = FocusNode();
  final GlobalKey _textFieldKey = GlobalKey();
  DoubtImagePayload? _image;
  bool _menuOpen = false;
  String? _error;
  double _lastBottomInset = -1;

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage;
    _textFocusNode.addListener(() {
      if (_textFocusNode.hasFocus) {
        _ensureTextFieldVisible();
      }
    });
  }

  @override
  void dispose() {
    _textFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _error = null;
      _menuOpen = false;
    });
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? 'image/jpeg';
      final payload = DoubtImagePayload(
        name: picked.name.isEmpty ? 'foto-da-duvida.jpg' : picked.name,
        type: mime,
        size: bytes.length,
        dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
      );
      final validation = DoubtInputDraft(image: payload).validate();
      if (validation != null && validation != emptyDoubtMessage) {
        setState(() => _error = validation);
        return;
      }
      setState(() => _image = payload);
    } catch (_) {
      setState(() => _error = imageOnlyMessage);
    }
  }

  void _submit() {
    final draft = DoubtInputDraft(text: widget.controller.text, image: _image);
    final validation = draft.validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    widget.onSubmit(draft);
    setState(() {
      _image = null;
      _error = null;
      _menuOpen = false;
    });
  }

  void _ensureTextFieldVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fieldContext = _textFieldKey.currentContext;
      if (fieldContext == null) return;
      Scrollable.ensureVisible(
        fieldContext,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        alignment: 0.72,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final media = MediaQuery.of(context);
    final responsive = SimResponsive.fromContext(context);
    final bottomInset = media.viewInsets.bottom;
    final textLength = widget.controller.text.length;
    final keyboardOpen = bottomInset > 0;
    final visibleHeight = (media.size.height - bottomInset - media.padding.top)
        .clamp(0.0, media.size.height);
    final maxHeight = keyboardOpen ? visibleHeight : media.size.height * 0.72;
    final horizontalPadding = responsive.isCompact ? 16.0 : 20.0;
    if (_lastBottomInset != bottomInset) {
      _lastBottomInset = bottomInset;
      if (_textFocusNode.hasFocus) {
        _ensureTextFieldVisible();
      }
    }
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: media.disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            key: const Key('doubt-input-sheet-frame'),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      18,
                      horizontalPadding,
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enviar dúvida',
                          style: SimTypography.title.copyWith(
                            color: palette.text,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Escreva sua dúvida ou envie uma foto do exercício, resolução, fórmula, gráfico ou tabela.',
                          style: SimTypography.caption.copyWith(
                            color: palette.muted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_image != null) ...[
                          SimStatusSurface(
                            tone: SimSurfaceTone.selected,
                            icon: Icons.image_outlined,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Foto: ${_image!.name}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.text,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                SimTextAction(
                                  label: t('remove'),
                                  semanticLabel: t('remove_doubt_photo'),
                                  onPressed: () =>
                                      setState(() => _image = null),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Container(
                          key: _textFieldKey,
                          decoration: BoxDecoration(
                            color: palette.surfaceSoft,
                            borderRadius: BorderRadius.circular(SimRadius.lg),
                            border: Border.all(color: palette.border),
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Stack(
                            children: [
                              TextField(
                                focusNode: _textFocusNode,
                                controller: widget.controller,
                                minLines: 4,
                                maxLines: 5,
                                maxLength: doubtTextMaxLength,
                                scrollPadding: const EdgeInsets.only(
                                  bottom: 96,
                                ),
                                decoration: InputDecoration(
                                  hintText: t('doubt_placeholder'),
                                  border: InputBorder.none,
                                  counterText: '',
                                  contentPadding: const EdgeInsets.only(
                                    bottom: 28,
                                  ),
                                ),
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 16,
                                  height: 1.35,
                                ),
                                onTap: _ensureTextFieldVisible,
                                onChanged: (_) => setState(() => _error = null),
                              ),
                              Positioned(
                                left: 0,
                                bottom: 0,
                                child: SimIconAction(
                                  icon: Icons.attach_file,
                                  semanticLabel: t('doubt_add_photo'),
                                  onPressed: widget.busy
                                      ? null
                                      : () => setState(
                                          () => _menuOpen = !_menuOpen,
                                        ),
                                  size: 40,
                                  iconSize: 21,
                                ),
                              ),
                              if (_menuOpen)
                                Positioned(
                                  left: 0,
                                  bottom: 38,
                                  child: Container(
                                    width: 210,
                                    decoration: BoxDecoration(
                                      color: palette.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: palette.border),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x26000000),
                                          blurRadius: 12,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _DoubtImageMenuLine(
                                          label: t('attach_camera'),
                                          onTap: () => unawaited(
                                            _pickImage(ImageSource.camera),
                                          ),
                                        ),
                                        _DoubtImageMenuLine(
                                          label: t('attach_image'),
                                          onTap: () => unawaited(
                                            _pickImage(ImageSource.gallery),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Text(
                                  '$textLength/$doubtTextMaxLength',
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 12,
                                    fontFamily: kMono,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          SimStatusSurface(
                            tone: SimSurfaceTone.danger,
                            icon: Icons.info_outline,
                            child: Text(
                              _error!,
                              style: SimTypography.caption.copyWith(
                                color: palette.danger,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    0,
                    horizontalPadding,
                    16 + media.padding.bottom,
                  ),
                  child: KeyedSubtree(
                    key: const Key('doubt-input-submit-button'),
                    child: SimActionButton(
                      label: widget.busy ? 'Enviando...' : 'Enviar dúvida',
                      onPressed: widget.busy ? null : _submit,
                      tone: SimActionTone.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoubtImageMenuLine extends StatelessWidget {
  const _DoubtImageMenuLine({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Text(
              label,
              style: TextStyle(
                color: palette.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
