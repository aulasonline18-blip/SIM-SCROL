// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../sim/external_ai/sim_ai_server_config.dart';
import '../sim/external_ai/sim_server_attachment_client.dart';
import '../sim/ui/sim_i18n.dart';

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
  bool profileNameSubmitted = false;
  bool profileAgeSubmitted = false;
  bool profileDifficultiesSubmitted = false;
  bool profileObservationSubmitted = false;
  String studentAge = '';
  bool ageNotDeclared = false;
  List<String> profileDifficulties = [];
  String profileObservation = '';
  String ageRange = '';
  String entryPath = '';
  String materialType = '';
  String subject = '';
  String topic = '';
  String academicLevel = '';
  String countryCurriculum = '';
  String deadline = '';
  String difficulties = '';
  String learningPreference = '';

  void updateFreeText(String value) {
    freeText = value.length > entryFormMaxFreeText
        ? value.substring(0, entryFormMaxFreeText)
        : value;
    notifyListeners();
  }

  void updatePreferredName(String value) {
    preferredName = value;
    if (value.trim().isEmpty) profileNameSubmitted = false;
    notifyListeners();
  }

  void submitProfileName() {
    if (preferredName.trim().isEmpty) return;
    profileNameSubmitted = true;
    notifyListeners();
  }

  void updateStudentAge(String value) {
    studentAge = value.trim();
    if (studentAge.isNotEmpty) ageNotDeclared = false;
    notifyListeners();
  }

  void submitStudentAge({bool notDeclared = false}) {
    ageNotDeclared = notDeclared;
    if (notDeclared) studentAge = '';
    profileAgeSubmitted = true;
    notifyListeners();
  }

  void toggleProfileDifficulty(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    if (clean == 'Não sei dizer') {
      profileDifficulties = profileDifficulties.contains(clean) ? [] : [clean];
    } else {
      final next = profileDifficulties
          .where((item) => item != 'Não sei dizer')
          .toList();
      if (next.contains(clean)) {
        next.remove(clean);
      } else {
        next.add(clean);
      }
      profileDifficulties = next;
    }
    profileDifficultiesSubmitted = false;
    notifyListeners();
  }

  void submitProfileDifficulties() {
    if (profileDifficulties.isEmpty) return;
    profileDifficultiesSubmitted = true;
    notifyListeners();
  }

  void updateProfileObservation(String value) {
    profileObservation = value.trim();
    notifyListeners();
  }

  void submitProfileObservation({bool skipped = false}) {
    if (skipped) profileObservation = '';
    profileObservationSubmitted = true;
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

  void updatePedagogicalField(String key, String value) {
    final clean = value.trim();
    switch (key) {
      case 'age_range':
        ageRange = clean;
        break;
      case 'student_age':
        studentAge = clean;
        ageNotDeclared = false;
        break;
      case 'profile_observation':
        profileObservation = clean;
        break;
      case 'entry_path':
        entryPath = clean;
        break;
      case 'material_type':
        materialType = clean;
        break;
      case 'subject':
        subject = clean;
        break;
      case 'topic':
        topic = clean;
        break;
      case 'academic_level':
        academicLevel = clean;
        break;
      case 'country_curriculum':
        countryCurriculum = clean;
        break;
      case 'deadline':
        deadline = clean;
        break;
      case 'difficulties':
        difficulties = clean;
        break;
      case 'learning_preference':
        learningPreference = clean;
        break;
      default:
        return;
    }
    notifyListeners();
  }

  Map<String, dynamic> buildPedagogicalFicha({
    required String appLocale,
    required String lessonLocale,
    required String explanationLanguage,
    String? targetLanguage,
  }) {
    final materialReceived = <String, dynamic>{
      'types': [
        if (materialType.trim().isNotEmpty) materialType.trim(),
        for (final attachment in attachments) attachment.type,
      ],
      'attachments': [
        for (final attachment in attachments)
          {
            'id': attachment.id,
            'name': attachment.name,
            'type': attachment.type,
            'status': attachment.status,
            if ((attachment.method ?? '').trim().isNotEmpty)
              'method': attachment.method,
          },
      ],
      if (attachmentsText.trim().isNotEmpty) 'extractedText': attachmentsText,
      if (freeText.trim().isNotEmpty) 'freeText': freeText.trim(),
    };
    final ficha =
        <String, dynamic>{
          'preferred_name': preferredName.trim(),
          'app_locale': appLocale,
          'interfaceLocale': appLocale,
          'lesson_locale': lessonLocale,
          'learningLocale': lessonLocale,
          'explanationLanguage': explanationLanguage,
          if ((targetLanguage ?? '').trim().isNotEmpty)
            'targetLanguage': targetLanguage!.trim(),
          'age_range': ageRange.trim(),
          'student_age': studentAge.trim(),
          if (profileAgeSubmitted) 'age_declared': !ageNotDeclared,
          'profile_difficulties': profileDifficulties,
          'profile_observation': profileObservation.trim(),
          'profile_summary': _profileSummary(),
          'initial_adaptation_guidance': _initialAdaptationGuidance(),
          'entry_path': entryPath.trim(),
          'material_type': materialType.trim(),
          'material_received': materialReceived,
          'subject': subject.trim(),
          'topic': topic.trim(),
          'academic_level': academicLevel.trim(),
          'country_curriculum': countryCurriculum.trim(),
          'objective': freeText.trim(),
          'deadline': deadline.trim(),
          'difficulties': difficulties.trim(),
          'learning_preference': learningPreference.trim(),
        }..removeWhere((key, value) {
          if (value == null) return true;
          if (value is String) return value.trim().isEmpty;
          if (value is List) return value.isEmpty;
          if (value is Map) return value.isEmpty;
          return false;
        });
    ficha['human_summary'] = humanPedagogicalSummary(ficha);
    return ficha;
  }

  String humanPedagogicalSummary(Map<String, dynamic> ficha) {
    final name = (ficha['preferred_name'] ?? '').toString().trim();
    final age = (ficha['student_age'] ?? ficha['age_range'] ?? '')
        .toString()
        .trim();
    final lesson = (ficha['lesson_locale'] ?? ficha['learningLocale'] ?? '')
        .toString()
        .trim();
    final objective = (ficha['objective'] ?? '').toString().trim();
    final deadlineValue = (ficha['deadline'] ?? '').toString().trim();
    final profileDifficulty = ficha['profile_difficulties'] is List
        ? (ficha['profile_difficulties'] as List).join(', ')
        : '';
    final difficulty = profileDifficulty.isNotEmpty
        ? profileDifficulty
        : (ficha['difficulties'] ?? '').toString().trim();
    final preference = (ficha['learning_preference'] ?? '').toString().trim();
    return [
      [name, age, lesson].where((value) => value.isNotEmpty).join(' · '),
      if (objective.isNotEmpty)
        deadlineValue.isEmpty
            ? 'Objetivo: $objective'
            : 'Objetivo: $objective · Prazo: $deadlineValue',
      if (difficulty.isNotEmpty) 'Dificuldade: $difficulty',
      if (preference.isNotEmpty) 'Preferencia: $preference',
    ].where((line) => line.trim().isNotEmpty).join('\n');
  }

  String _profileSummary() {
    return [
      if (preferredName.trim().isNotEmpty) 'Nome: ${preferredName.trim()}',
      if (studentAge.trim().isNotEmpty) 'Idade: ${studentAge.trim()}',
      if (ageNotDeclared) 'Idade: nao declarada',
      if (profileDifficulties.isNotEmpty)
        'Dificuldades: ${profileDifficulties.join(', ')}',
      if (profileObservation.trim().isNotEmpty)
        'Observacao: ${profileObservation.trim()}',
    ].join('\n');
  }

  String _initialAdaptationGuidance() {
    final guidance = <String>[
      if (profileDifficulties.isNotEmpty)
        'Adaptar condução para: ${profileDifficulties.join(', ')}.',
      if (studentAge.trim().isNotEmpty)
        'Considerar idade informada pelo aluno: ${studentAge.trim()}.',
      if (ageNotDeclared) 'Não inferir idade; usar linguagem neutra.',
      if (profileObservation.trim().isNotEmpty)
        'Usar observação livre como contexto leve, sem diagnóstico.',
    ];
    return guidance.join(' ');
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
    return t('attachment_read_failed');
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
