// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../sim/external_ai/sim_ai_server_config.dart';
import '../sim/external_ai/sim_server_attachment_client.dart';
import '../sim/localization/sim_locale_contract.dart';
import '../sim/ui/sim_i18n.dart';

const entryFormMaxFreeText = 1500;
const entryFormMaxAttachments = 3;
const entryFormMaxAttachmentBytes = 10 * 1024 * 1024;
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
  bool interfaceLanguageSubmitted = false;
  bool learningLanguageSubmitted = false;
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
  bool simLearningGoalSubmitted = false;
  bool simLearningLevelSubmitted = false;
  String materialType = '';
  String subject = '';
  String topic = '';
  String academicLevel = '';
  String countryCurriculum = '';
  String deadline = '';
  String deadlineCustom = '';
  bool traversalGoalSubmitted = false;
  bool traversalDeadlineSubmitted = false;
  bool traversalExpectedResultSubmitted = false;
  String traversalGoal = '';
  String traversalGoalCustom = '';
  String expectedResult = '';
  String difficulties = '';
  String learningPreference = '';
  bool describeMaterialWithoutAttachment = false;

  void updateFreeText(String value) {
    freeText = value;
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

  void submitInterfaceLanguage() {
    interfaceLanguageSubmitted = true;
    notifyListeners();
  }

  void submitLearningLanguage() {
    learningLanguageSubmitted = true;
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
      case 'material_description_only':
        describeMaterialWithoutAttachment =
            clean == 'true' || clean == '1' || clean == 'yes';
        break;
      case 'material_type':
        materialType = clean;
        break;
      case 'subject':
        subject = clean;
        break;
      case 'topic':
        topic = clean;
        simLearningGoalSubmitted = false;
        break;
      case 'academic_level':
        academicLevel = clean;
        simLearningLevelSubmitted = false;
        break;
      case 'country_curriculum':
        countryCurriculum = clean;
        break;
      case 'deadline':
        deadline = clean;
        traversalDeadlineSubmitted = false;
        break;
      case 'deadline_custom':
        deadlineCustom = clean;
        traversalDeadlineSubmitted = false;
        break;
      case 'traversal_goal':
        traversalGoal = clean;
        traversalGoalSubmitted = false;
        break;
      case 'traversal_goal_custom':
        traversalGoalCustom = clean;
        traversalGoalSubmitted = false;
        break;
      case 'expected_result':
        expectedResult = clean;
        traversalExpectedResultSubmitted = false;
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

  void submitSimLearningGoal() {
    if (topic.trim().isEmpty) return;
    simLearningGoalSubmitted = true;
    notifyListeners();
  }

  void submitSimLearningLevel() {
    if (academicLevel.trim().isEmpty) return;
    simLearningLevelSubmitted = true;
    notifyListeners();
  }

  void submitTraversalGoal() {
    if (traversalGoal.trim().isEmpty && traversalGoalCustom.trim().isEmpty) {
      return;
    }
    traversalGoalSubmitted = true;
    notifyListeners();
  }

  void submitTraversalDeadline() {
    if (deadline.trim().isEmpty && deadlineCustom.trim().isEmpty) return;
    traversalDeadlineSubmitted = true;
    notifyListeners();
  }

  void submitTraversalExpectedResult({bool skipped = false}) {
    if (!skipped && expectedResult.trim().isEmpty) return;
    if (skipped) expectedResult = '';
    traversalExpectedResultSubmitted = true;
    notifyListeners();
  }

  Map<String, dynamic> buildPedagogicalFicha({
    required String appLocale,
    required String lessonLocale,
    required String explanationLanguage,
    String? targetLanguage,
    SimLocaleContract? localeContract,
  }) {
    final locale =
        (localeContract ??
                SimLocaleContract.fromUserSelection(
                  interfaceLocale: appLocale,
                  learningLocale: lessonLocale,
                  explanationLanguage: explanationLanguage,
                  targetLanguage: targetLanguage,
                  source: SimLocaleSource.migrated,
                ))
            .normalized();
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
    final pedagogicalEntry = _structuredPedagogicalEntry(
      locale: locale,
      materialReceived: materialReceived,
    );
    final ficha =
        <String, dynamic>{
          'preferred_name': preferredName.trim(),
          'app_locale': appLocale,
          'interfaceLocale': locale.interfaceLocale,
          'lesson_locale': locale.learningLocale,
          'learningLocale': locale.learningLocale,
          'explanationLanguage': locale.explanationLanguage,
          'mediaTextLanguage': locale.mediaTextLanguage,
          if ((locale.targetLanguage ?? '').trim().isNotEmpty)
            'targetLanguage': locale.targetLanguage!.trim(),
          'localeContract': locale.toJson(),
          'human_summary_locale': locale.explanationLanguage,
          'age_range': ageRange.trim(),
          'student_age': studentAge.trim(),
          if (profileAgeSubmitted) 'age_declared': !ageNotDeclared,
          'profile_difficulties': profileDifficulties,
          'profile_observation': profileObservation.trim(),
          'profile_summary': _profileSummary(locale),
          'profile_summary_locale': locale.explanationLanguage,
          'initial_adaptation_guidance': _initialAdaptationGuidance(locale),
          'initial_adaptation_guidance_locale': locale.explanationLanguage,
          'entry_path': entryPath.trim(),
          'subject_status': subject.trim().isEmpty
              ? 'not_informed'
              : 'informed',
          'topic_status': topic.trim().isEmpty ? 'not_informed' : 'informed',
          'material_description_only': describeMaterialWithoutAttachment,
          'material_type': materialType.trim(),
          'material_received': materialReceived,
          'subject': subject.trim(),
          'topic': topic.trim(),
          'academic_level': academicLevel.trim(),
          'country_curriculum': countryCurriculum.trim(),
          'objective': freeText.trim(),
          'learning_goal': _effectiveLearningGoal,
          'student_goal': pedagogicalEntry['student_goal'],
          'traversal_goal': traversalGoal.trim(),
          'traversal_goal_custom': traversalGoalCustom.trim(),
          'goal_summary': _goalSummary(locale),
          'goal_summary_locale': locale.explanationLanguage,
          'goal_type': _goalType['code'],
          'goal_type_source': _goalType['source'],
          if (_isExamGoal) 'exam_goal': _effectiveTraversalGoal,
          if (_isRealUseGoal) 'real_use_goal': _effectiveTraversalGoal,
          'deadline': deadline.trim(),
          'deadline_custom': deadlineCustom.trim(),
          if (_effectiveDeadline.isNotEmpty) 'session_goal': _effectiveDeadline,
          'expected_result': expectedResult.trim(),
          'difficulties': difficulties.trim(),
          'learning_preference': learningPreference.trim(),
          'pedagogical_entry': pedagogicalEntry,
          'pedagogical_entry_ficha': pedagogicalEntry,
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
    final app = (ficha['interfaceLocale'] ?? ficha['app_locale'] ?? '')
        .toString()
        .trim();
    final lesson = (ficha['lesson_locale'] ?? ficha['learningLocale'] ?? '')
        .toString()
        .trim();
    final objective = (ficha['objective'] ?? '').toString().trim();
    final goal = (ficha['traversal_goal'] ?? '').toString().trim();
    final deadlineValue = (ficha['session_goal'] ?? ficha['deadline'] ?? '')
        .toString()
        .trim();
    final profileDifficulty = ficha['profile_difficulties'] is List
        ? (ficha['profile_difficulties'] as List).join(', ')
        : '';
    final difficulty = profileDifficulty.isNotEmpty
        ? profileDifficulty
        : (ficha['difficulties'] ?? '').toString().trim();
    final preference = (ficha['learning_preference'] ?? '').toString().trim();
    final locale = _summaryLocaleFromFicha(ficha);
    return [
      [name, age].where((value) => value.isNotEmpty).join(' · '),
      [
        if (app.isNotEmpty) '${_summaryLabel(locale, 'interface')}: $app',
        if (lesson.isNotEmpty) '${_summaryLabel(locale, 'lesson')}: $lesson',
      ].join(' · '),
      if (objective.isNotEmpty)
        deadlineValue.isEmpty
            ? '${_summaryLabel(locale, 'objective')}: $objective'
            : '${_summaryLabel(locale, 'objective')}: $objective · ${_summaryLabel(locale, 'deadline')}: $deadlineValue',
      if (goal.isNotEmpty) '${_summaryLabel(locale, 'realGoal')}: $goal',
      if (difficulty.isNotEmpty)
        '${_summaryLabel(locale, 'difficulty')}: $difficulty',
      if (preference.isNotEmpty)
        '${_summaryLabel(locale, 'preference')}: $preference',
    ].where((line) => line.trim().isNotEmpty).join('\n');
  }

  String _profileSummary(SimLocaleContract locale) {
    return [
      if (preferredName.trim().isNotEmpty)
        '${_summaryLabel(locale.explanationLanguage, 'name')}: ${preferredName.trim()}',
      if (studentAge.trim().isNotEmpty)
        '${_summaryLabel(locale.explanationLanguage, 'age')}: ${studentAge.trim()}',
      if (ageNotDeclared)
        '${_summaryLabel(locale.explanationLanguage, 'age')}: ${_summaryLabel(locale.explanationLanguage, 'notDeclared')}',
      if (profileDifficulties.isNotEmpty)
        '${_summaryLabel(locale.explanationLanguage, 'difficulties')}: ${profileDifficulties.join(', ')}',
      if (profileObservation.trim().isNotEmpty)
        '${_summaryLabel(locale.explanationLanguage, 'observation')}: ${profileObservation.trim()}',
    ].join('\n');
  }

  String _initialAdaptationGuidance(SimLocaleContract locale) {
    final guidance = <String>[
      if (profileDifficulties.isNotEmpty)
        '${_summarySentence(locale.explanationLanguage, 'adaptFor')} ${profileDifficulties.join(', ')}.',
      if (studentAge.trim().isNotEmpty)
        '${_summarySentence(locale.explanationLanguage, 'considerAge')} ${studentAge.trim()}.',
      if (ageNotDeclared)
        _summarySentence(locale.explanationLanguage, 'doNotInferAge'),
      if (profileObservation.trim().isNotEmpty)
        _summarySentence(locale.explanationLanguage, 'useObservation'),
    ];
    return guidance.join(' ');
  }

  String get _effectiveTraversalGoal {
    final custom = traversalGoalCustom.trim();
    if (custom.isNotEmpty) return custom;
    return traversalGoal.trim();
  }

  String get _effectiveLearningGoal {
    final explicitTopic = topic.trim();
    if (explicitTopic.isNotEmpty) return explicitTopic;
    return freeText.trim();
  }

  String get _effectiveDeadline {
    final custom = deadlineCustom.trim();
    if (custom.isNotEmpty) return custom;
    return deadline.trim();
  }

  Map<String, String> get _goalType {
    final custom = traversalGoalCustom.trim();
    if (custom.isNotEmpty) {
      return const {'code': 'custom', 'source': 'student_free_text'};
    }
    final exact = traversalGoal.trim().toLowerCase();
    const known = {
      'prova': 'exam',
      'exam': 'exam',
      'examen': 'exam',
      'lição de casa': 'homework',
      'licao de casa': 'homework',
      'homework': 'homework',
      'deberes': 'homework',
      'trabalho/prática': 'real_use',
      'trabalho/pratica': 'real_use',
      'work/practice': 'real_use',
      'trabajo/práctica': 'real_use',
      'trabajo/practica': 'real_use',
      'curiosidade própria': 'self_study',
      'curiosidade propria': 'self_study',
      'self-study': 'self_study',
      'curiosidad propia': 'self_study',
      'concurso': 'contest',
      'contest': 'contest',
      'oposición': 'contest',
      'oposicion': 'contest',
      'ainda não sei': 'unknown',
      'ainda nao sei': 'unknown',
      'not sure yet': 'unknown',
      'todavía no sé': 'unknown',
      'todavia no se': 'unknown',
    };
    final code = known[exact];
    if (code == null) {
      return const {'code': 'unspecified', 'source': 'not_inferred'};
    }
    return {'code': code, 'source': 'explicit_choice'};
  }

  bool get _isExamGoal {
    final code = _goalType['code'];
    return code == 'exam' || code == 'contest';
  }

  bool get _isRealUseGoal {
    return _goalType['code'] == 'real_use';
  }

  String _goalSummary(SimLocaleContract locale) {
    return [
      if (topic.trim().isNotEmpty)
        '${_summaryLabel(locale.explanationLanguage, 'content')}: ${topic.trim()}',
      if (_effectiveTraversalGoal.isNotEmpty)
        '${_summaryLabel(locale.explanationLanguage, 'realGoal')}: $_effectiveTraversalGoal',
      if (_effectiveDeadline.isNotEmpty)
        '${_summaryLabel(locale.explanationLanguage, 'deadline')}: $_effectiveDeadline',
      if (expectedResult.trim().isNotEmpty)
        '${_summaryLabel(locale.explanationLanguage, 'expectedResult')}: ${expectedResult.trim()}',
    ].join('\n');
  }

  Map<String, dynamic> _structuredPedagogicalEntry({
    required SimLocaleContract locale,
    required Map<String, dynamic> materialReceived,
  }) {
    return <String, dynamic>{
      'version': 1,
      'localeContract': locale.toJson(),
      'student_goal': {
        'objective': freeText.trim(),
        'learning_goal': _effectiveLearningGoal,
        'subject': subject.trim(),
        'subject_status': subject.trim().isEmpty ? 'not_informed' : 'informed',
        'topic': topic.trim(),
        'topic_status': topic.trim().isEmpty ? 'not_informed' : 'informed',
        'goal_type': _goalType,
        'deadline': _effectiveDeadline,
        'expected_result': expectedResult.trim(),
      }..removeWhere((_, value) => value is String && value.trim().isEmpty),
      'academic_context': {
        'academic_level': academicLevel.trim(),
        'country_curriculum': countryCurriculum.trim(),
      }..removeWhere((_, value) => value.trim().isEmpty),
      'material': {
        'description_only': describeMaterialWithoutAttachment,
        'material_type': materialType.trim(),
        'received': materialReceived,
      },
      'student_profile':
          {
            'preferred_name': preferredName.trim(),
            'student_age': studentAge.trim(),
            if (profileAgeSubmitted) 'age_declared': !ageNotDeclared,
            'age_not_declared': ageNotDeclared,
            'difficulties': profileDifficulties,
            'observation': profileObservation.trim(),
            'learning_preference': learningPreference.trim(),
          }..removeWhere((_, value) {
            if (value is String) return value.trim().isEmpty;
            if (value is List) return value.isEmpty;
            return false;
          }),
      'entry_path': entryPath.trim().isEmpty ? 'guided_path' : entryPath.trim(),
    };
  }

  String _summaryLocaleFromFicha(Map<String, dynamic> ficha) {
    final locale =
        ficha['human_summary_locale'] ?? ficha['explanationLanguage'];
    return locale?.toString() ?? 'Portuguese';
  }

  String _summaryLabel(String locale, String key) {
    final language = locale.toLowerCase();
    final en = language.startsWith('english') || language == 'en';
    final es = language.startsWith('spanish') || language == 'es';
    final labels = en
        ? const {
            'interface': 'Interface language',
            'lesson': 'Lesson language',
            'objective': 'Objective',
            'deadline': 'Deadline',
            'realGoal': 'Real goal',
            'difficulty': 'Difficulty',
            'preference': 'Preference',
            'name': 'Name',
            'age': 'Age',
            'notDeclared': 'not declared',
            'difficulties': 'Difficulties',
            'observation': 'Observation',
            'content': 'Content',
            'expectedResult': 'Expected result',
          }
        : es
        ? const {
            'interface': 'Idioma de la interfaz',
            'lesson': 'Idioma de la clase',
            'objective': 'Objetivo',
            'deadline': 'Plazo',
            'realGoal': 'Meta real',
            'difficulty': 'Dificultad',
            'preference': 'Preferencia',
            'name': 'Nombre',
            'age': 'Edad',
            'notDeclared': 'no declarada',
            'difficulties': 'Dificultades',
            'observation': 'Observación',
            'content': 'Contenido',
            'expectedResult': 'Resultado esperado',
          }
        : const {
            'interface': 'Idioma do app',
            'lesson': 'Idioma da aula',
            'objective': 'Objetivo',
            'deadline': 'Prazo',
            'realGoal': 'Alvo real',
            'difficulty': 'Dificuldade',
            'preference': 'Preferencia',
            'name': 'Nome',
            'age': 'Idade',
            'notDeclared': 'nao declarada',
            'difficulties': 'Dificuldades',
            'observation': 'Observacao',
            'content': 'Conteudo',
            'expectedResult': 'Resultado esperado',
          };
    return labels[key] ?? key;
  }

  String _summarySentence(String locale, String key) {
    final language = locale.toLowerCase();
    final en = language.startsWith('english') || language == 'en';
    final es = language.startsWith('spanish') || language == 'es';
    final labels = en
        ? const {
            'adaptFor': 'Adapt guidance for:',
            'considerAge': 'Consider the age declared by the student:',
            'doNotInferAge': 'Do not infer age; use neutral language.',
            'useObservation':
                'Use the free observation as light context, without diagnosis.',
          }
        : es
        ? const {
            'adaptFor': 'Adaptar la conducción para:',
            'considerAge': 'Considerar la edad informada por el estudiante:',
            'doNotInferAge': 'No inferir edad; usar lenguaje neutral.',
            'useObservation':
                'Usar la observación libre como contexto leve, sin diagnóstico.',
          }
        : const {
            'adaptFor': 'Adaptar conducao para:',
            'considerAge': 'Considerar idade informada pelo aluno:',
            'doNotInferAge': 'Nao inferir idade; usar linguagem neutra.',
            'useObservation':
                'Usar observacao livre como contexto leve, sem diagnostico.',
          };
    return labels[key] ?? key;
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
    attachmentError = _attachmentErrorMessage(
      StateError('ATTACHMENT_PICKER_REQUIRED'),
    );
    notifyListeners();
  }

  void addLabAttachmentFile(SimAttachmentFile file) {
    if (attachments.length >= entryFormMaxAttachments) {
      attachmentError = 'Limite de 3 anexos por envio.';
      notifyListeners();
      return;
    }
    final contentType = file.contentType.toLowerCase();
    if (contentType.startsWith('audio/')) {
      attachmentError = entryFormAudioNotSupportedMessage;
      notifyListeners();
      return;
    }
    if (contentType.startsWith('video/')) {
      attachmentError = entryFormVideoNotSupportedMessage;
      notifyListeners();
      return;
    }
    if (file.bytes.length > entryFormMaxAttachmentBytes) {
      attachmentError = 'Arquivo maior que 10 MB. Escolha um arquivo menor.';
      notifyListeners();
      return;
    }
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
      final extracted = result.extractedText.trim();
      final status = result.error != null
          ? 'error'
          : extracted.length >= entryFormMinExtractedChars
          ? 'ready'
          : 'insufficient';
      _replaceAttachment(
        draft.id,
        draft.copyWith(
          status: status,
          method: result.method,
          extractedText: result.extractedText,
          error: status == 'insufficient'
              ? t('objective_attachment_insufficient')
              : result.error,
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
    attachmentError = _firstAttachmentIssue();
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
              ? '${text.substring(0, 8000)}\n[...truncated_at_8000_chars]'
              : text;
          return '--- attachment: ${a.name} ---\n$clipped';
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
    attachmentError = _firstAttachmentIssue();
    notifyListeners();
  }

  String? _firstAttachmentIssue() {
    for (final attachment in attachments) {
      if ((attachment.status == 'error' ||
              attachment.status == 'insufficient') &&
          (attachment.error ?? '').trim().isNotEmpty) {
        return attachment.error!.trim();
      }
    }
    return null;
  }
}
