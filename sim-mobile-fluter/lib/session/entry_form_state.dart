// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../sim/external_ai/sim_ai_server_config.dart';
import '../sim/external_ai/sim_server_attachment_client.dart';

const entryFormMaxFreeText = 1500;
const entryFormMaxAttachments = 3;
const entryFormMinExtractedChars = 20;
const entryFormAudioNotSupportedMessage =
    'Áudio ainda não está disponível. Envie texto, foto ou arquivo.';
const entryFormVideoNotSupportedMessage =
    'Vídeo ainda não está disponível. Envie texto, foto ou arquivo.';

class AttachmentDraft {
  AttachmentDraft({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.status,
    this.extractedText,
    this.method,
    this.error,
  });

  final String id;
  final String name;
  final String type;
  final int size;
  final String status;
  final String? extractedText;
  final String? method;
  final String? error;

  AttachmentDraft copyWith({
    String? status,
    String? extractedText,
    String? method,
    String? error,
  }) {
    return AttachmentDraft(
      id: id,
      name: name,
      type: type,
      size: size,
      status: status ?? this.status,
      extractedText: extractedText ?? this.extractedText,
      method: method ?? this.method,
      error: error,
    );
  }
}

class EntryFormState extends ChangeNotifier {
  EntryFormState({
    SimServerAttachmentClient? attachmentClient,
    SimAiServerConfig Function()? serverConfig,
  }) : _attachmentClient = attachmentClient,
       _serverConfig = serverConfig;

  final SimServerAttachmentClient? _attachmentClient;
  final SimAiServerConfig Function()? _serverConfig;

  String freeText = '';
  String preferredName = '';
  String otherLanguage = '';
  String? selectedLanguageCode;
  String? stableLang;
  bool allowPaidImages = false;
  List<AttachmentDraft> attachments = [];
  String attachmentsText = '';
  String studentProfileNotes = '';
  String? attachmentError;
  Map<String, String> guidedAnswers = {};

  void updateFreeText(String value) {
    freeText = value.length > entryFormMaxFreeText
        ? value.substring(0, entryFormMaxFreeText)
        : value;
    notifyListeners();
  }

  void updatePreferredName(String value) {
    preferredName = value;
    notifyListeners();
  }

  void updateGuidedAnswer(String key, String value) {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return;
    final cleanValue = value.trim();
    guidedAnswers = {
      ...guidedAnswers,
      if (cleanValue.isNotEmpty) cleanKey: cleanValue,
    }..removeWhere((_, v) => v.trim().isEmpty);
    notifyListeners();
  }

  void updateLanguage(String code, String name) {
    selectedLanguageCode = code;
    final cleanName = name.trim();
    stableLang = cleanName.isEmpty ? null : cleanName;
    notifyListeners();
  }

  void setOtherLanguage(String value) {
    otherLanguage = value;
    notifyListeners();
  }

  void resetLanguage() {
    selectedLanguageCode = null;
    stableLang = null;
    otherLanguage = '';
    notifyListeners();
  }

  void addLabAttachment(String source) {
    if (attachments.length >= entryFormMaxAttachments) return;
    unawaited(_processLabAttachmentFile(_fallbackFileForSource(source)));
  }

  void addLabAttachmentFile(SimAttachmentFile file) {
    if (attachments.length >= entryFormMaxAttachments) return;
    unawaited(_processLabAttachmentFile(file));
  }

  void failAttachmentSelection(Object error) {
    attachmentError = _attachmentErrorMessage(error);
    notifyListeners();
  }

  Future<void> _processLabAttachmentFile(SimAttachmentFile file) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final draft = _draftAttachmentForFile(file, now);
    attachments = [...attachments, draft];
    attachmentError = null;
    notifyListeners();
    try {
      final result = await _attachmentClientForSession().processAttachment(
        file,
      );
      _replaceAttachment(
        draft.id,
        draft.copyWith(
          status: result.error == null ? 'ready' : 'error',
          method: result.method,
          extractedText: result.extractedText,
          error: result.error,
        ),
      );
    } catch (error) {
      _replaceAttachment(
        draft.id,
        draft.copyWith(status: 'error', error: _attachmentErrorMessage(error)),
      );
    }
  }

  void removeAttachment(int index) {
    attachments = [
      for (int i = 0; i < attachments.length; i++)
        if (i != index) attachments[i],
    ];
    notifyListeners();
  }

  void clearAttachments() {
    attachments = [];
    attachmentsText = '';
    attachmentError = null;
    notifyListeners();
  }

  void clearGuidedAnswers() {
    guidedAnswers = {};
    notifyListeners();
  }

  String buildAttachmentsText() {
    final ready = attachments.where(
      (a) =>
          a.status == 'ready' &&
          (a.extractedText?.trim().length ?? 0) >= entryFormMinExtractedChars,
    );
    return ready
        .map((a) {
          final text = a.extractedText?.trim() ?? '';
          final clipped = text.length > 8000
              ? '${text.substring(0, 8000)}\n[...truncado em 8000 chars]'
              : text;
          return '--- Anexo: ${a.name} ---\n$clipped';
        })
        .join('\n\n');
  }

  AttachmentDraft _draftAttachmentForFile(SimAttachmentFile file, int now) {
    final index = attachments.length + 1;
    return AttachmentDraft(
      id: 'att-$now-$index',
      name: _displayName(file.name, file.contentType, index),
      type: file.contentType,
      size: file.bytes.length,
      status: 'processing',
    );
  }

  SimAttachmentFile _fallbackFileForSource(String source) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isDocument = source == 'document';
    final isCamera = source == 'camera';
    final type = isDocument ? 'application/pdf' : 'image/jpeg';
    final name = isDocument
        ? 'arquivo-$now.pdf'
        : isCamera
        ? 'foto-$now.jpg'
        : 'imagem-$now.jpg';
    final bytes = type == 'application/pdf'
        ? utf8.encode('%PDF-1.4\nSIM attachment $now\n%%EOF')
        : <int>[
            0xFF,
            0xD8,
            0xFF,
            0xE0,
            ...utf8.encode('SIM attachment $now'),
            0xFF,
            0xD9,
          ];
    return SimAttachmentFile(name: name, contentType: type, bytes: bytes);
  }

  String _displayName(String name, String contentType, int index) {
    final clean = name.trim();
    if (clean.isNotEmpty) return clean;
    if (contentType == 'application/pdf') return 'arquivo-$index.pdf';
    if (contentType.startsWith('image/')) return 'imagem-$index.jpg';
    if (contentType == 'text/plain') return 'texto-$index.txt';
    if (contentType == 'text/csv') return 'planilha-$index.csv';
    return 'anexo-$index';
  }

  SimServerAttachmentClient _attachmentClientForSession() {
    final client = _attachmentClient;
    if (client != null) return client;
    final config = _serverConfig;
    if (config == null) {
      throw StateError('Attachment client unavailable.');
    }
    return SimServerAttachmentClient(config: config());
  }

  String _attachmentErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('AUDIO_NOT_SUPPORTED')) {
      return entryFormAudioNotSupportedMessage;
    }
    if (text.contains('VIDEO_NOT_SUPPORTED')) {
      return entryFormVideoNotSupportedMessage;
    }
    return 'Não foi possível ler o anexo agora.';
  }

  void _replaceAttachment(String id, AttachmentDraft next) {
    attachments = [
      for (final attachment in attachments)
        if (attachment.id == id) next else attachment,
    ];
    attachmentError = next.status == 'error' ? next.error : null;
    notifyListeners();
  }
}
