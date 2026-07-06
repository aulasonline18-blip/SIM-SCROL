import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_visual_pipeline.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
import 'package:sim_mobile/sim/analytics/visual_learning_feedback.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/media/audio_core.dart';
import 'package:sim_mobile/sim/media/audio_preference.dart';
import 'package:sim_mobile/sim/media/blueprint_prompt.dart';
import 'package:sim_mobile/sim/media/doubt_audio.dart';
import 'package:sim_mobile/sim/media/image_data_url_compression.dart';
import 'package:sim_mobile/sim/media/lesson_audio_api_contract.dart';
import 'package:sim_mobile/sim/media/lesson_audio_controller.dart';
import 'package:sim_mobile/sim/media/lesson_image_api_contract.dart';
import 'package:sim_mobile/sim/media/lesson_paid_image_offer.dart';
import 'package:sim_mobile/sim/media/lesson_visual_models.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';
import 'package:sim_mobile/sim/media/math_templates/math_templates.dart';
import 'package:sim_mobile/sim/media/paid_image_service.dart' as paid;
import 'package:sim_mobile/sim/media/pedagogical_visual_components.dart';
import 'package:sim_mobile/sim/media/pedagogical_visual_hierarchy.dart';
import 'package:sim_mobile/sim/media/pedagogical_visual_layout.dart';
import 'package:sim_mobile/sim/media/pedagogical_visual_level.dart';
import 'package:sim_mobile/sim/media/pedagogical_visual_palette.dart';
import 'package:sim_mobile/sim/media/platform_audio_adapter.dart';
import 'package:sim_mobile/sim/media/sim_visual_identity.dart';
import 'package:sim_mobile/sim/media/software_render_catalog.dart';
import 'package:sim_mobile/sim/media/student_lesson_media_service.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

class FakeGeneratedAudioClient implements GeneratedAudioClient {
  int calls = 0;
  String? lastLang;
  String? lastVoice;

  @override
  Future<String?> generateAudio({
    required String text,
    required String lang,
    required String voice,
    required String lessonKey,
  }) async {
    calls += 1;
    lastLang = lang;
    lastVoice = voice;
    return 'data:audio/wav;base64,AAAA';
  }
}

class ThrowingVisualRouterClient implements LessonVisualRouterClient {
  const ThrowingVisualRouterClient();

  @override
  Future<VisualN3Result> routeVisual({
    required VisualN2Result n2,
    String? topic,
    String? visualType,
    String? imagePrompt,
    List<String> keyElements = const [],
    String? pedagogicalNeed,
    String? highlightFocus,
    String? complexity,
    String? stableLang,
  }) async {
    throw StateError('HTTP 401 Unauthorized requestId=vis-test');
  }
}

class CapturingVisualRouterClient implements LessonVisualRouterClient {
  CapturingVisualRouterClient({
    this.result = const VisualN3Result(
      verdict: VisualVerdict.ai,
      reason: 'TEST_N3_AI',
    ),
  });

  final VisualN3Result result;
  VisualN2Result? lastN2;
  String? lastTopic;
  String? lastVisualType;
  String? lastImagePrompt;
  List<String>? lastKeyElements;
  String? lastPedagogicalNeed;
  String? lastHighlightFocus;
  String? lastComplexity;
  String? lastStableLang;
  int calls = 0;

  @override
  Future<VisualN3Result> routeVisual({
    required VisualN2Result n2,
    String? topic,
    String? visualType,
    String? imagePrompt,
    List<String> keyElements = const [],
    String? pedagogicalNeed,
    String? highlightFocus,
    String? complexity,
    String? stableLang,
  }) async {
    calls += 1;
    lastN2 = n2;
    lastTopic = topic;
    lastVisualType = visualType;
    lastImagePrompt = imagePrompt;
    lastKeyElements = keyElements;
    lastPedagogicalNeed = pedagogicalNeed;
    lastHighlightFocus = highlightFocus;
    lastComplexity = complexity;
    lastStableLang = stableLang;
    return result;
  }
}

class SequenceVisualRouterClient implements LessonVisualRouterClient {
  SequenceVisualRouterClient(this.results);

  final List<VisualN3Result> results;
  final prompts = <String?>[];
  int calls = 0;

  @override
  Future<VisualN3Result> routeVisual({
    required VisualN2Result n2,
    String? topic,
    String? visualType,
    String? imagePrompt,
    List<String> keyElements = const [],
    String? pedagogicalNeed,
    String? highlightFocus,
    String? complexity,
    String? stableLang,
  }) async {
    prompts.add(imagePrompt);
    final index = calls < results.length ? calls : results.length - 1;
    calls += 1;
    return results[index];
  }
}

class StubSoftwareRenderCatalog extends SoftwareRenderCatalog {
  const StubSoftwareRenderCatalog({this.result});

  final SoftwareRenderResult? result;

  @override
  SoftwareRenderResult? render(SoftwareVisualRequest request) => result;
}

class CapturingSoftwareRenderCatalog extends SoftwareRenderCatalog {
  CapturingSoftwareRenderCatalog();

  SoftwareVisualRequest? lastRequest;

  @override
  SoftwareRenderResult? render(SoftwareVisualRequest request) {
    lastRequest = request;
    return null;
  }
}

String _renderSoftwareSvg(SoftwareVisualRequest request) {
  final result = const SoftwareRenderCatalog().render(request);
  expect(result, isNotNull);
  return Uri.decodeFull(result!.dataUrl);
}

SoftwareRenderResult _renderSoftwareResult(SoftwareVisualRequest request) {
  final result = const SoftwareRenderCatalog().render(request);
  expect(result, isNotNull);
  return result!;
}

class ThrowingGeneratedAudioClient implements GeneratedAudioClient {
  int calls = 0;

  @override
  Future<String?> generateAudio({
    required String text,
    required String lang,
    required String voice,
    required String lessonKey,
  }) async {
    calls += 1;
    throw StateError('remote down');
  }
}

class CountingPlaybackAdapter implements AudioPlaybackAdapter {
  int dataUrlPlays = 0;
  int platformTtsCalls = 0;
  int stops = 0;
  String? lastTtsText;
  bool failDataUrl = false;
  bool failPlatformTts = false;

  @override
  Future<bool> playDataUrl(String dataUrl, SpeakOptions opts) async {
    if (failDataUrl) {
      opts.onEnd?.call();
      return false;
    }
    dataUrlPlays += 1;
    opts.onStart?.call();
    opts.onEnd?.call();
    return true;
  }

  @override
  Future<bool> speakWithPlatformTts(String text, SpeakOptions opts) async {
    if (failPlatformTts) {
      opts.onEnd?.call();
      return false;
    }
    platformTtsCalls += 1;
    lastTtsText = text;
    opts.onStart?.call();
    opts.onEnd?.call();
    return true;
  }

  @override
  void stop() {
    stops += 1;
  }
}

class FakeAudioT02Client implements T02LessonClient {
  int calls = 0;

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    calls += 1;
    return T02LessonMaterial(
      explanation: 'Explicacao ${request.item}',
      question: 'Pergunta?',
      options: const {
        AnswerLetter.A: 'A1',
        AnswerLetter.B: 'B1',
        AnswerLetter.C: 'C1',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'A.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'fake-audio',
    );
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) =>
      completeLesson(request);
}

class FakeImageClient implements LessonImageClient {
  String? next = 'data:image/jpeg;base64,AAAA';
  String? lastPrompt;
  Map<String, dynamic>? lastVisualTrigger;
  Map<String, dynamic>? lastLessonContext;
  int calls = 0;

  @override
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
    Map<String, dynamic>? visualTrigger,
    Map<String, dynamic>? lessonContext,
  }) async {
    calls += 1;
    lastPrompt = prompt;
    lastVisualTrigger = visualTrigger;
    lastLessonContext = lessonContext;
    return next;
  }
}

class FakePaidOrchestrator implements LessonPaidImageOrchestrator {
  int accepted = 0;
  int declined = 0;

  @override
  Future<void> acceptPaidImageOffer(String lessonKey) async {
    accepted += 1;
  }

  @override
  void declinePaidImageOffer(String lessonKey) {
    declined += 1;
  }
}

class FakeCredits implements CreditsGateway {
  int balance = 14;

  @override
  Future<int> getMyCredits() async => balance;
}

StudentLearningState seedState() {
  return StudentLearningState.empty(
    lessonLocalId: 'l1',
  ).copyWith(events: const []);
}

void main() {
  test('audio preference defaults on and notifies listeners', () {
    final preference = AudioPreference();
    var notified = false;
    preference.subscribe((enabled) => notified = !enabled);

    expect(preference.getAudioEnabled(), true);
    preference.setAudioEnabled(false);
    expect(preference.getAudioEnabled(), false);
    expect(notified, true);
  });

  test('audio preference persists with SharedPrefs storage', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final preference = AudioPreference(
      storage: SharedPrefsAudioPreferenceStorage(prefs),
    );

    preference.setAudioEnabled(false);
    final reloaded = AudioPreference(
      storage: SharedPrefsAudioPreferenceStorage(prefs),
    );

    expect(reloaded.getAudioEnabled(), false);
  });

  test(
    'production/session audio wiring uses PlatformAudioAdapter, not Noop',
    () {
      final labSession = File(
        'lib/features/session/lab_session.dart',
      ).readAsStringSync();
      final organism = File(
        'lib/sim/organism/sim_organism.dart',
      ).readAsStringSync();

      expect(labSession, contains('playback: PlatformAudioAdapter()'));
      expect(
        RegExp(
          r'playback:\s*NoopAudioPlaybackAdapter\(\)',
        ).hasMatch(labSession),
        false,
      );
      expect(organism, contains('playback ?? PlatformAudioAdapter()'));
    },
  );

  test('platform TTS maps broad stable language names to native locales', () {
    expect(simTtsLanguageForStableLang('Portuguese'), 'pt-BR');
    expect(simTtsLanguageForStableLang('French'), 'fr-FR');
    expect(simTtsLanguageForStableLang('German'), 'de-DE');
    expect(simTtsLanguageForStableLang('Italian'), 'it-IT');
    expect(simTtsLanguageForStableLang('Arabic'), 'ar');
    expect(simTtsLanguageForStableLang('Hindi'), 'hi-IN');
    expect(simTtsLanguageForStableLang('Chinese'), 'zh-CN');
    expect(simTtsLanguageForStableLang('Korean'), 'ko-KR');
    expect(simTtsLanguageForStableLang('Russian'), 'ru-RU');
    expect(simTtsLanguageForStableLang('Kiribati'), 'en-US');
  });

  test('audio core maps stable language and caches generated audio', () async {
    final preference = AudioPreference();
    final playback = NoopAudioPlaybackAdapter();
    final client = FakeGeneratedAudioClient();
    final core = AudioCore(
      preference: preference,
      playback: playback,
      generatedAudioClient: client,
      stableLangProvider: () => 'Portuguese',
    );

    expect(stableLangToBCP47('Portuguese'), 'pt-BR');
    expect(await core.speak('Oi', const SpeakOptions(lessonKey: 'k')), true);
    expect(await core.speak('Oi', const SpeakOptions(lessonKey: 'k')), true);
    expect(client.calls, 1);
    expect(client.lastLang, 'pt-BR');
    expect(client.lastVoice, 'Charon');
  });

  test('audio disabled skips generated client and local playback', () async {
    final preference = AudioPreference()..setAudioEnabled(false);
    final playback = CountingPlaybackAdapter();
    final client = FakeGeneratedAudioClient();
    final core = AudioCore(
      preference: preference,
      playback: playback,
      generatedAudioClient: client,
    );

    expect(
      await core.speak('Nao tocar', const SpeakOptions(lessonKey: 'k')),
      false,
    );
    expect(client.calls, 0);
    expect(playback.platformTtsCalls, 0);
  });

  test('audio play failure does not call onStart or report playing', () async {
    final preference = AudioPreference();
    final playback = CountingPlaybackAdapter()
      ..failDataUrl = true
      ..failPlatformTts = true;
    final client = FakeGeneratedAudioClient();
    var started = false;
    var ended = false;
    final core = AudioCore(
      preference: preference,
      playback: playback,
      generatedAudioClient: client,
    );

    final ok = await core.speak(
      'Falha controlada',
      SpeakOptions(
        lessonKey: 'k',
        onStart: () => started = true,
        onEnd: () => ended = true,
      ),
    );

    expect(ok, false);
    expect(started, false);
    expect(ended, true);
    expect(playback.dataUrlPlays, 0);
  });

  test('audio cache key separates lesson language voice and text', () {
    final core = AudioCore(
      preference: AudioPreference(),
      playback: NoopAudioPlaybackAdapter(),
    );

    final pt = core.audioCacheKey(
      'texto',
      const SpeakOptions(lessonKey: 'lesson-a', lang: 'pt-BR', voice: 'Charon'),
    );
    final en = core.audioCacheKey(
      'texto',
      const SpeakOptions(lessonKey: 'lesson-a', lang: 'en-US', voice: 'Charon'),
    );
    final otherLesson = core.audioCacheKey(
      'texto',
      const SpeakOptions(lessonKey: 'lesson-b', lang: 'pt-BR', voice: 'Charon'),
    );
    final otherText = core.audioCacheKey(
      'texto diferente',
      const SpeakOptions(lessonKey: 'lesson-a', lang: 'pt-BR', voice: 'Charon'),
    );

    expect({pt, en, otherLesson, otherText}, hasLength(4));
    expect(pt, isNot(contains('Instance of')));
  });

  test(
    'remote audio failure falls back to local TTS without blocking lesson',
    () async {
      final preference = AudioPreference();
      final playback = CountingPlaybackAdapter();
      final client = ThrowingGeneratedAudioClient();
      Object? reportedError;
      final core = AudioCore(
        preference: preference,
        playback: playback,
        generatedAudioClient: client,
        onGeneratedAudioError: (error) => reportedError = error,
      );

      expect(
        await core.speak('Fallback local', const SpeakOptions(lessonKey: 'k')),
        true,
      );
      expect(client.calls, 1);
      expect(reportedError, isA<StateError>());
      expect(playback.platformTtsCalls, 1);
      expect(playback.lastTtsText, 'Fallback local');
    },
  );

  test('lesson audio controller preserves lesson reading sequence', () async {
    final states = {'l1': seedState()};
    final preference = AudioPreference();
    final media = StudentLessonMediaService(
      audioCore: AudioCore(
        preference: preference,
        playback: NoopAudioPlaybackAdapter(),
      ),
      readState: (id) => states[id]!,
      writeState: (state) => states[state.lessonLocalId] = state,
    );
    final controller = LessonAudioController(
      lessonLocalId: 'l1',
      mediaService: media,
      preference: preference,
    );
    final content = LessonContent(
      explanation: 'Explicacao',
      question: 'Pergunta',
      options: const {
        AnswerLetter.A: 'A1',
        AnswerLetter.B: 'B1',
        AnswerLetter.C: 'C1',
      },
      correctAnswer: AnswerLetter.A,
    );

    expect(await controller.playConteudo(content, 'M1', LessonLayer.l1), true);
    expect(
      states['l1']!.events.map((event) => event.type),
      contains('AUDIO_STARTED'),
    );
    expect(
      states['l1']!.events.map((event) => event.type),
      contains('AUDIO_READY'),
    );
    expect(states['l1']!.audio.status, 'ready');
  });

  test(
    'lesson audio failure clears playing state and records recoverable error',
    () async {
      final states = {'l1': seedState()};
      final playback = CountingPlaybackAdapter()..failPlatformTts = true;
      final media = StudentLessonMediaService(
        audioCore: AudioCore(preference: AudioPreference(), playback: playback),
        readState: (id) => states[id]!,
        writeState: (state) => states[state.lessonLocalId] = state,
      );
      final controller = LessonAudioController(
        lessonLocalId: 'l1',
        mediaService: media,
        preference: AudioPreference(),
      );
      final content = LessonContent(
        explanation: 'Explicacao',
        question: 'Pergunta',
        options: const {
          AnswerLetter.A: 'A1',
          AnswerLetter.B: 'B1',
          AnswerLetter.C: 'C1',
        },
        correctAnswer: AnswerLetter.A,
      );

      expect(
        await controller.playConteudo(content, 'M1', LessonLayer.l1),
        false,
      );
      expect(states['l1']!.audio.status, 'failed');
      expect(states['l1']!.audio.playing, false);
      expect(states['l1']!.audio.error, 'audio_playback_unavailable');
      expect(
        states['l1']!.events.map((event) => event.type),
        containsAll(['AUDIO_STARTED', 'AUDIO_FAILED']),
      );
    },
  );

  test('ready material prepares audioText without starting playback', () async {
    final service = StudentLearningStateService(seed: {'l1': seedState()});
    final playback = CountingPlaybackAdapter();
    final media = StudentLessonMediaService(
      audioCore: AudioCore(preference: AudioPreference(), playback: playback),
      readState: (id) => service.ensure(lessonLocalId: id),
      writeState: service.write,
    );
    final orchestrator = LessonOrchestrator(
      t02Client: FakeAudioT02Client(),
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
      visualPipeline: fakeVisualPipeline(),
    );
    orchestrator.setAudioTextPreparer((params, lesson) {
      media.prepareLessonAudioText(
        LessonMediaPosition(
          lessonLocalId: params.lessonLocalId,
          itemMarker: params.marker,
          layer: params.layer,
        ),
        [
          lesson.conteudo.explanation,
          lesson.conteudo.question,
          lesson.conteudo.options[AnswerLetter.A],
          lesson.conteudo.options[AnswerLetter.B],
          lesson.conteudo.options[AnswerLetter.C],
        ],
      );
    });

    await orchestrator.prefetchCompleteLesson(
      const CompleteLessonParams(
        lessonLocalId: 'l1',
        item: 'Item 1',
        lang: 'pt-BR',
        academic: 'base',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      ),
      priority: 'background',
    );

    final state = service.read('l1')!;
    expect(state.events.map((event) => event.type), contains('AUDIO_READY'));
    expect(playback.dataUrlPlays, 0);
    expect(playback.platformTtsCalls, 0);
  });

  test('doubt audio appends doubt suffix and respects preference', () async {
    final preference = AudioPreference();
    final playback = NoopAudioPlaybackAdapter();
    final audio = DoubtAudio(
      audioCore: AudioCore(preference: preference, playback: playback),
      preference: preference,
    );

    expect(await audio.speakDoubt('Duvida', lessonKey: 'l1:M1'), true);
    expect(await audio.speakText('Revisao', lessonKey: 'l1:review:0'), true);
    preference.setAudioEnabled(false);
    expect(await audio.speakDoubt('Duvida', lessonKey: 'l1:M1'), false);
    expect(
      await audio.speakText('Recuperacao', lessonKey: 'l1:recovery:0'),
      false,
    );
  });

  test(
    'audio stop covers answer selection, signal, advance and dispose paths',
    () {
      final playback = CountingPlaybackAdapter();
      final core = AudioCore(preference: AudioPreference(), playback: playback);
      core.stop();
      core.stop();
      core.stop();
      core.stop();

      expect(playback.stops, 4);
    },
  );

  test('LabSession stopActiveAudio clears playing and loading state', () {
    final session = LabSession()
      ..audioPlaying = true
      ..audioLoading = true;

    session.stopActiveAudio(notify: false);

    expect(session.audioPlaying, false);
    expect(session.audioLoading, false);
  });

  test('LabSession does not invent paid image offer from visual trigger', () {
    final session = LabSession()
      ..aulaSnapshot = LessonRuntimeSnapshot(
        authReady: true,
        authed: true,
        hasCurriculum: true,
        isDone: false,
        viewModel: const LessonMainViewModel(
          progress: 0,
          headerLabel: 'item',
          options: [],
          locked: false,
          nextLabel: '',
        ),
        phase: ClassroomPhase.reading(),
        history: const [],
        conteudo: const LessonContent(
          explanation: 'Explicacao',
          question: 'Pergunta?',
          options: {
            AnswerLetter.A: 'A',
            AnswerLetter.B: 'B',
            AnswerLetter.C: 'C',
          },
          correctAnswer: AnswerLetter.A,
          visualTrigger: {
            'needs_image': true,
            'pedagogical_need': 'important',
            'render_strategy': 'ai',
            'topic': 'foto realista de um coracao humano',
            'visual_type': 'anatomy',
            'image_prompt': 'foto realista de um coracao humano',
          },
        ),
        imagem: null,
        itemMarker: 'M1',
        itemText: 'Coracao humano',
      );

    expect(session.lessonPaidImagePrompt, isNull);
    expect(session.hasLessonPaidImageOffer, isFalse);
  });

  test(
    'LabSession toggleAudio stop does not disable audio preference',
    () async {
      final session = LabSession()
        ..audioEnabled = true
        ..audioPlaying = true;

      await session.toggleAudio();

      expect(session.audioPlaying, false);
      expect(session.audioEnabled, true);
    },
  );

  test('lesson image media events preserve cache key item and layer', () {
    var state = StudentLearningState.empty(lessonLocalId: 'l1');
    final service = StudentLessonMediaService(
      audioCore: AudioCore(
        preference: AudioPreference(),
        playback: CountingPlaybackAdapter(),
        generatedAudioClient: FakeGeneratedAudioClient(),
      ),
      readState: (_) => state,
      writeState: (next) => state = next,
    );
    const position = LessonMediaPosition(
      lessonLocalId: 'l1',
      itemMarker: 'M1',
      layer: LessonLayer.l2,
    );

    service.markLessonImageStarted(position, cacheKey: 'image:user:a');
    service.markLessonImageReady(
      position,
      cacheKey: 'image:user:a',
      imageUrl: 'data:image/png;base64,AAAA',
    );
    service.markLessonImageFailed(position, error: 'requestId=rid-1');

    expect(state.events.map((event) => event.type), [
      'IMAGE_STARTED',
      'IMAGE_READY',
      'IMAGE_FAILED',
    ]);
    expect(state.events[0].payload['cacheKey'], 'image:user:a');
    expect(state.events[0].payload['itemMarker'], 'M1');
    expect(state.events[0].payload['layer'], 2);
    expect(state.events[1].payload['imageUrlHead'], startsWith('data:image'));
    expect(state.events[2].payload['errorMessage'], 'requestId=rid-1');
  });

  test('visual learning feedback tracks answers and doubt after image', () {
    final session = LabSession()
      ..aulaSnapshot = LessonRuntimeSnapshot(
        authReady: true,
        authed: true,
        hasCurriculum: true,
        isDone: false,
        viewModel: const LessonMainViewModel(
          progress: 0,
          headerLabel: 'item',
          options: [],
          locked: false,
          nextLabel: '',
        ),
        phase: ClassroomPhase.reading(),
        history: const [
          QuestionHistoryEntry(
            id: 'q1',
            text: 'Pergunta 1',
            options: [],
            chosenOptionId: AnswerLetter.A,
            correct: true,
            imageUrl: 'data:image/svg+xml;utf8,%3Csvg%3E%3C%2Fsvg%3E',
          ),
          QuestionHistoryEntry(
            id: 'q2',
            text: 'Pergunta 2',
            options: [],
            chosenOptionId: AnswerLetter.B,
            correct: false,
          ),
        ],
        conteudo: const LessonContent(
          explanation: 'Explicacao',
          question: 'Pergunta?',
          options: {},
          correctAnswer: AnswerLetter.A,
        ),
        imagem: 'data:image/svg+xml;utf8,%3Csvg%3E%3C%2Fsvg%3E',
        itemMarker: 'M1',
        itemText: 'Item',
      );
    session.setDoubt(
      const DoubtState(status: DoubtStatus.processing, progress: 30),
    );

    final report = session.visualLearningFeedbackReport;

    expect(report.answeredWithImage, 1);
    expect(report.correctWithImage, 1);
    expect(report.incorrectWithImage, 0);
    expect(report.accuracyAfterImage, 1);
    expect(report.currentItemHasImage, isTrue);
    expect(report.doubtAfterImage, isTrue);
    expect(report.hasLearningSignal, isTrue);
  });

  test('visual operational report combines funnel and learning signals', () {
    final telemetry = VisualFunnelTelemetry();
    telemetry
      ..record(
        const VisualFunnelEvent(
          lessonKey: 'lesson',
          outcome: 'software',
          source: 'n3_software',
        ),
      )
      ..record(
        const VisualFunnelEvent(
          lessonKey: 'lesson',
          outcome: 'failed',
          source: 'ai_failed',
        ),
      );
    const feedback = VisualLearningFeedbackReport(
      answeredWithImage: 2,
      correctWithImage: 1,
      incorrectWithImage: 1,
      doubtAfterImage: false,
      currentItemHasImage: true,
    );

    final report = VisualOperationalReport(
      funnel: telemetry.snapshot(),
      feedback: feedback,
    );

    expect(report.hasEnoughSignals, isTrue);
    expect(report.needsHumanReview, isTrue);
    expect(report.toJson()['needsHumanReview'], isTrue);
  });

  test('visual prompt preserves language directive and image validation', () {
    final prompt = buildNaturalImagePrompt(
      topic: 'Intestino',
      teacherPrompt: 'Mostre nutrientes',
      lang: 'pt-BR',
    );
    expect(prompt, contains('Brazilian Portuguese'));
    expect(prompt, contains('Writing visible text in English'));
    expect(isUsableImageDataUrl('data:image/webp;base64,AAAA'), true);
    expect(isUsableImageDataUrl('http://x'), false);
  });

  test('image critic judges visual quality instead of raw text count', () {
    const critic = ImagePedagogicalCritic(maxTextNodes: 2);
    String dataUrl(String body) {
      return sanitizeAndEncodeSvg(
        '<svg viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">$body</svg>',
      )!;
    }

    final richOrganized = dataUrl(
      '<rect x="40" y="40" width="220" height="120" fill="#DCFCE7"/>'
      '<rect x="340" y="40" width="220" height="120" fill="#E0F2FE"/>'
      '<rect x="640" y="40" width="220" height="120" fill="#FEF3C7"/>'
      '<path d="M260 100 L340 100 M560 100 L640 100" stroke="#334155"/>'
      '<text x="60" y="80" fill="#0F172A" font-size="18">coleta seletiva</text>'
      '<text x="60" y="110" fill="#0F172A" font-size="18">separar materiais</text>'
      '<text x="360" y="80" fill="#0F172A" font-size="18">triagem</text>'
      '<text x="360" y="110" fill="#0F172A" font-size="18">classificar residuos</text>'
      '<text x="660" y="80" fill="#0F172A" font-size="18">reciclagem</text>'
      '<text x="660" y="110" fill="#0F172A" font-size="18">novo ciclo produtivo</text>',
    );
    final richManyConcepts = dataUrl(
      List.generate(8, (index) {
        final x = 60 + (index % 4) * 200;
        final y = 80 + (index ~/ 4) * 180;
        return '<rect x="$x" y="$y" width="150" height="70" fill="#F8FAFC" stroke="#1E293B"/>'
            '<text x="${x + 12}" y="${y + 32}" fill="#0F172A" font-size="16">conceito ${index + 1}</text>'
            '<text x="${x + 12}" y="${y + 55}" fill="#475569" font-size="13">função pedagógica</text>';
      }).join(),
    );
    final usefulLegend = dataUrl(
      '<rect x="120" y="90" width="660" height="150" fill="#DCFCE7"/>'
      '<text x="160" y="175" fill="#0F172A" font-size="24">verde: conceito principal</text>'
      '<rect x="120" y="280" width="660" height="150" fill="#FEF3C7"/>'
      '<text x="160" y="365" fill="#0F172A" font-size="24">amarelo: foco de atenção</text>',
    );
    final smallClean = dataUrl(
      '<circle cx="120" cy="120" r="48" fill="#DCFCE7" stroke="#16A34A"/>'
      '<text x="92" y="126" fill="#0F172A" font-size="18">força</text>',
    );

    expect(critic.evaluateSvgDataUrl(richOrganized).accepted, isTrue);
    expect(critic.evaluateSvgDataUrl(richManyConcepts).accepted, isTrue);
    expect(critic.evaluateSvgDataUrl(usefulLegend).accepted, isTrue);
    expect(critic.evaluateSvgDataUrl(smallClean).accepted, isFalse);
    expect(
      critic.evaluateSvgDataUrl(smallClean).reason,
      'critic_tiny_visual_footprint',
    );

    expect(
      critic
          .evaluateSvgDataUrl(
            dataUrl(
              '<text x="40" y="40" fill="#0F172A" font-size="6">microtexto</text>',
            ),
          )
          .reason,
      'critic_illegible_text',
    );
    expect(
      critic
          .evaluateSvgDataUrl(
            dataUrl(
              '<text x="40" y="40" fill="#FFFFFF" font-size="16">invisivel</text>',
            ),
          )
          .reason,
      'critic_low_contrast_text',
    );
    expect(
      critic
          .evaluateSvgDataUrl(
            dataUrl(
              '<rect x="120" y="90" width="660" height="350"/>'
              '<text x="200" y="210" font-size="22">eco</text>'
              '<text x="420" y="280" font-size="22">eco</text>'
              '<text x="640" y="350" font-size="22">eco</text>',
            ),
          )
          .reason,
      'critic_duplicate_text',
    );
    expect(
      critic
          .evaluateSvgDataUrl(
            dataUrl(
              '<text x="220" y="180" font-size="22">1</text>'
              '<text x="360" y="240" font-size="22">2</text>'
              '<text x="500" y="300" font-size="22">3</text>'
              '<text x="640" y="360" font-size="22">4</text>',
            ),
          )
          .reason,
      'critic_text_without_visual_structure',
    );
    expect(critic.evaluateSvgDataUrl('not-svg').reason, 'critic_invalid_svg');
    expect(
      critic
          .evaluateSvgDataUrl(
            'data:image/svg+xml;utf8,${Uri.encodeComponent('<svg viewBox="0 0 10 10"><script>alert(1)</script></svg>')}',
          )
          .reason,
      'critic_svg_unsafe',
    );
  });

  test('final visual quality accepts SVG that teaches the lesson context', () {
    const critic = ImagePedagogicalCritic();
    const evaluator = VisualFinalQualityEvaluator.standard;
    final svg = sanitizeAndEncodeSvg(
      '<svg viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="40" y="40" width="220" height="120" fill="#DCFCE7"/>'
      '<path d="M260 100 L340 100" stroke="#334155"/>'
      '<text x="70" y="88" fill="#0F172A" font-size="18">glicose</text>'
      '<text x="360" y="88" fill="#0F172A" font-size="18">ATP</text>'
      '<text x="560" y="88" fill="#0F172A" font-size="18">mitocôndria</text>'
      '<text x="70" y="138" fill="#0F172A" font-size="18">energia celular</text>'
      '</svg>',
    )!;
    const request = SoftwareVisualRequest(
      n2: VisualN2Result(
        verdict: VisualVerdict.svg,
        matched: ['diagrama'],
        reason: 'TEST',
      ),
      topic: 'respiração celular',
      visualType: 'diagram',
      keyElements: ['glicose', 'ATP', 'mitocôndria'],
      highlightFocus: 'energia celular',
      academicLevel: 'Ensino Médio',
    );
    final critique = critic.evaluateSvgDataUrl(svg);
    final result = evaluator.evaluateSvg(
      dataUrl: svg,
      request: request,
      critique: critique,
      source: 'local_software',
    );

    expect(result.action, VisualFinalQualityAction.accepted);
    expect(result.coveredKeyElements, 3);
    expect(result.focusCovered, isTrue);
  });

  test('final visual quality escalates SVG that ignores lesson keys', () {
    const critic = ImagePedagogicalCritic();
    const evaluator = VisualFinalQualityEvaluator.standard;
    final svg = sanitizeAndEncodeSvg(
      '<svg viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="120" y="90" width="660" height="350" rx="28" fill="#DCFCE7" stroke="#16A34A"/>'
      '<text x="450" y="275" text-anchor="middle" fill="#0F172A" font-size="26">modelo genérico</text>'
      '</svg>',
    )!;
    const request = SoftwareVisualRequest(
      n2: VisualN2Result(
        verdict: VisualVerdict.svg,
        matched: ['diagrama'],
        reason: 'TEST',
      ),
      topic: 'metabolismo celular',
      visualType: 'diagram',
      keyElements: ['glicose', 'ATP', 'mitocôndria', 'oxigênio'],
      highlightFocus: 'produção de ATP',
      complexity: 'complex',
      academicLevel: 'Universitário',
    );
    final critique = critic.evaluateSvgDataUrl(svg);
    final result = evaluator.evaluateSvg(
      dataUrl: svg,
      request: request,
      critique: critique,
      source: 'local_software',
    );

    expect(result.action, VisualFinalQualityAction.needsN3);
    expect(result.reason, contains('key_coverage'));
  });

  test('final visual quality preserves simple useful SVG for young levels', () {
    const critic = ImagePedagogicalCritic();
    const evaluator = VisualFinalQualityEvaluator.standard;
    final svg = sanitizeAndEncodeSvg(
      '<svg viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="330" cy="270" r="120" fill="#DCFCE7" stroke="#16A34A"/>'
      '<circle cx="570" cy="270" r="120" fill="#FEF3C7" stroke="#CA8A04"/>'
      '<path d="M450 270 L450 270" stroke="#0F172A" stroke-width="5"/>'
      '<text x="330" y="278" text-anchor="middle" fill="#0F172A" font-size="28">luz</text>'
      '<text x="570" y="278" text-anchor="middle" fill="#0F172A" font-size="28">planta</text>'
      '</svg>',
    )!;
    const request = SoftwareVisualRequest(
      n2: VisualN2Result(
        verdict: VisualVerdict.svg,
        matched: ['diagrama'],
        reason: 'TEST',
      ),
      topic: 'fotossíntese',
      visualType: 'diagram',
      keyElements: ['luz', 'planta', 'alimento'],
      academicLevel: 'Educação Infantil',
    );
    final critique = critic.evaluateSvgDataUrl(svg);
    final result = evaluator.evaluateSvg(
      dataUrl: svg,
      request: request,
      critique: critique,
      source: 'local_software',
    );

    expect(result.action, VisualFinalQualityAction.accepted);
  });

  test('final visual quality follows critic rejection for illegible SVG', () {
    const critic = ImagePedagogicalCritic();
    const evaluator = VisualFinalQualityEvaluator.standard;
    final svg = sanitizeAndEncodeSvg(
      '<svg viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">'
      '<text x="40" y="40" fill="#0F172A" font-size="6">glicose</text>'
      '</svg>',
    )!;
    const request = SoftwareVisualRequest(
      n2: VisualN2Result(
        verdict: VisualVerdict.svg,
        matched: ['diagrama'],
        reason: 'TEST',
      ),
      topic: 'respiração celular',
      visualType: 'diagram',
      keyElements: ['glicose'],
    );
    final critique = critic.evaluateSvgDataUrl(svg);
    final result = evaluator.evaluateSvg(
      dataUrl: svg,
      request: request,
      critique: critique,
      source: 'local_software',
    );

    expect(critique.reason, 'critic_illegible_text');
    expect(result.action, VisualFinalQualityAction.rejected);
    expect(result.reason, contains('critic_illegible_text'));
  });

  test('image data URL compression rewrites raster image to jpeg data URL', () {
    final pngBytes = img.encodePng(img.Image(width: 2, height: 2));
    final png = 'data:image/png;base64,${base64Encode(pngBytes)}';
    final compressed = compressImageDataUrl(png);
    expect(compressed, startsWith('data:image/jpeg;base64,'));
  });

  test('SoftwareVisualRequest accepts complete visual context fields', () {
    const legend = [
      BlueprintColorLegendItem(id: 1, label: 'força', color: '#FF1744'),
      BlueprintColorLegendItem(id: 2, label: 'movimento', color: '#2979FF'),
    ];
    const request = SoftwareVisualRequest(
      n2: VisualN2Result(
        verdict: VisualVerdict.svg,
        matched: ['diagrama'],
        reason: 'TEST',
      ),
      topic: 'forças em bloco',
      visualType: 'diagram',
      imagePrompt: 'mostrar setas e bloco',
      colorLegend: legend,
      keyElements: ['bloco', 'força', 'atrito'],
      highlightFocus: 'direção da força resultante',
      complexity: 'moderate',
      pedagogicalNeed: 'important',
      academicLevel: 'Ensino Fundamental',
      pedagogicalGoal: 'direção da força resultante',
    );

    expect(request.colorLegend, legend);
    expect(request.keyElements, ['bloco', 'força', 'atrito']);
    expect(request.highlightFocus, 'direção da força resultante');
    expect(request.complexity, 'moderate');
    expect(request.pedagogicalNeed, 'important');
    expect(request.academicLevel, 'Ensino Fundamental');
    expect(request.pedagogicalGoal, 'direção da força resultante');
    expect(request.visualType, 'diagram');
    expect(request.imagePrompt, 'mostrar setas e bloco');
    expect(request.topic, 'forças em bloco');
  });

  test(
    'pedagogical visual palette exposes semantic roles and safe contrast',
    () {
      const palette = PedagogicalVisualPalette.standard;

      expect(palette.primaryConcept, '#16A34A');
      expect(palette.supportingContext, '#0284C7');
      expect(palette.attention, '#D97706');
      expect(palette.critical, '#DC2626');
      expect(palette.definition, '#7C3AED');
      expect(palette.neutral, '#64748B');
      expect(contrastRatio(palette.text, palette.background), greaterThan(4.5));
      for (final role in PedagogicalVisualRole.values) {
        expect(
          contrastRatio(palette.text, palette.fillFor(role)),
          greaterThan(4.5),
        );
      }
    },
  );

  test('pedagogical visual hierarchy exposes reusable visual weights', () {
    const hierarchy = PedagogicalVisualHierarchy.standard;

    expect(
      hierarchy.fontSize(PedagogicalVisualHierarchyRole.primary),
      greaterThan(hierarchy.fontSize(PedagogicalVisualHierarchyRole.secondary)),
    );
    expect(
      hierarchy.strokeWidth(PedagogicalVisualHierarchyRole.primary),
      greaterThan(
        hierarchy.strokeWidth(PedagogicalVisualHierarchyRole.connector),
      ),
    );
    expect(
      hierarchy.opacity(PedagogicalVisualHierarchyRole.connector),
      lessThan(hierarchy.opacity(PedagogicalVisualHierarchyRole.primary)),
    );
    expect(
      hierarchy.radius(PedagogicalVisualHierarchyRole.primary),
      greaterThan(hierarchy.radius(PedagogicalVisualHierarchyRole.neutral)),
    );
    expect(
      hierarchy.textAttrs(PedagogicalVisualHierarchyRole.critical),
      contains('font-weight="800"'),
    );
  });

  test('SIM visual identity centralizes brand tokens for software images', () {
    const identity = SimVisualIdentity.standard;
    const palette = PedagogicalVisualPalette.standard;

    expect(identity.fontFamily, contains('Inter'));
    expect(identity.canvasWidth, 900);
    expect(identity.canvasHeightDefault, 560);
    expect(identity.titleFontSize, 30);
    expect(identity.badgeFontSize, 16);
    expect(identity.arrowMarkerSize, 12);
    expect(identity.largeArrowMarkerSize, 14);
    expect(identity.canvasBackground(palette), contains('height="560"'));
    expect(identity.compactCanvasBackground(palette), contains('height="520"'));
    expect(identity.fontGroupAttrs(palette), contains('font-family="Inter'));
    expect(identity.cardShadow(), contains('feDropShadow'));
  });

  test('pedagogical visual level detects cognitive profiles safely', () {
    expect(
      PedagogicalVisualLevelProfile.fromAcademicLevel(
        'Educação Infantil',
      ).level,
      PedagogicalVisualLevel.child,
    );
    expect(
      PedagogicalVisualLevelProfile.fromAcademicLevel(
        'Ensino Fundamental',
      ).level,
      PedagogicalVisualLevel.fundamental,
    );
    expect(
      PedagogicalVisualLevelProfile.fromAcademicLevel('Ensino Médio').level,
      PedagogicalVisualLevel.highSchool,
    );
    expect(
      PedagogicalVisualLevelProfile.fromAcademicLevel('Vestibular ENEM').level,
      PedagogicalVisualLevel.examPrep,
    );
    expect(
      PedagogicalVisualLevelProfile.fromAcademicLevel('Universitário').level,
      PedagogicalVisualLevel.advanced,
    );
    expect(
      PedagogicalVisualLevelProfile.fromAcademicLevel(null).level,
      PedagogicalVisualLevel.highSchool,
    );
    expect(
      PedagogicalVisualLevelProfile.advanced.detailSlots,
      greaterThan(PedagogicalVisualLevelProfile.fundamental.detailSlots),
    );
    expect(
      PedagogicalVisualLevelProfile.child.maxPrimaryElements,
      lessThan(PedagogicalVisualLevelProfile.highSchool.maxPrimaryElements),
    );
  });

  test('pedagogical visual layout wraps and spaces labels safely', () {
    const layout = PedagogicalVisualLayout.standard;

    final lines = layout.wrapLabel(
      'fotossíntese transforma energia luminosa em energia química',
      maxCharsPerLine: 14,
      maxLines: 2,
    );
    expect(lines, hasLength(2));
    expect(lines.last, endsWith('...'));
    for (final line in lines) {
      expect(line.length, lessThanOrEqualTo(14));
    }

    final svgText = layout.svgText(
      x: 120,
      y: 80,
      text: 'clorofila captura luz solar',
      attrs: 'font-size="18" font-weight="700"',
      maxCharsPerLine: 12,
      maxLines: 2,
    );
    expect(svgText, contains('<tspan'));
    expect(svgText, contains('font-family="Inter, Arial, sans-serif"'));
    expect(svgText, contains('font-size="18"'));

    final centers = layout.evenlySpacedCenters(count: 3, start: 80, end: 820);
    expect(centers, [80, 450, 820]);
    expect(layout.alternatingOffsets(4), [72, -56, 72, -56]);
  });

  test('pedagogical visual components render reusable SVG bricks only', () {
    const components = PedagogicalVisualComponents.standard;
    const palette = PedagogicalVisualPalette.standard;

    final box = components.semanticBox(
      x: 10,
      y: 20,
      width: 120,
      height: 60,
      palette: palette,
      fillRole: PedagogicalVisualRole.primaryConcept,
      hierarchyRole: PedagogicalVisualHierarchyRole.primary,
    );
    expect(box, contains('<rect'));
    expect(box, contains(palette.primaryConceptFill));
    expect(box, contains('stroke-width="4.8"'));

    final marker = components.arrowMarker(palette: palette);
    expect(marker, contains('<marker id="arrow"'));
    expect(marker, contains('fill="${palette.connector}"'));
    expect(marker, contains('markerWidth="12"'));

    final connector = components.connectorGroup(
      palette: palette,
      markerId: 'arrow',
      paths: const ['<path d="M10 10 H90"/>'],
    );
    expect(connector, contains('marker-end="url(#arrow)"'));
    expect(connector, contains('<path d="M10 10 H90"/>'));

    final caption = components.caption(
      x: 100,
      y: 120,
      text: 'texto pedagógico reutilizável com quebra segura',
      palette: palette,
      maxCharsPerLine: 16,
    );
    expect(caption, contains('<tspan'));
    expect(caption, contains('font-family="Inter, Arial, sans-serif"'));

    final title = components.title('SIM visual unificado', palette);
    expect(title, contains('font-size="30"'));
    expect(title, contains('font-family="Inter, Arial, sans-serif"'));

    final badge = components.badge(
      x: 10,
      y: 20,
      label: 'SIM',
      palette: palette,
    );
    expect(badge, contains('font-family="Inter, Arial, sans-serif"'));
    expect(badge, contains('font-size="16"'));

    final all = [box, marker, connector, caption, title, badge].join('\n');
    expect(all, isNot(contains('data:image')));
    expect(all, isNot(contains('lessonKey')));
    expect(all, isNot(contains('cache')));
  });

  test('pedagogical visual palette accepts safe colorLegend overrides', () {
    final palette = PedagogicalVisualPalette.fromColorLegend(const [
      BlueprintColorLegendItem(
        id: 1,
        label: 'conceito principal',
        color: '#00E676',
      ),
      BlueprintColorLegendItem(
        id: 2,
        label: 'atenção do aluno',
        color: '#FFEA00',
      ),
    ]);

    expect(palette.primaryConceptFill, '#00E676');
    expect(palette.attentionFill, '#FFEA00');
    expect(
      palette.supportingContextFill,
      PedagogicalVisualPalette.standard.supportingContextFill,
    );
  });

  test('pedagogical visual palette rejects unsafe colorLegend overrides', () {
    final palette = PedagogicalVisualPalette.fromColorLegend(const [
      BlueprintColorLegendItem(
        id: 1,
        label: 'conceito principal',
        color: '#000000',
      ),
      BlueprintColorLegendItem(id: 2, label: 'apoio', color: 'blue'),
    ]);

    expect(
      palette.primaryConceptFill,
      PedagogicalVisualPalette.standard.primaryConceptFill,
    );
    expect(
      palette.supportingContextFill,
      PedagogicalVisualPalette.standard.supportingContextFill,
    );
  });

  test(
    'local flowchart renderer uses lesson context instead of placeholders',
    () {
      final svg = _renderSoftwareSvg(
        const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['fluxograma'],
            reason: 'TEST',
          ),
          topic: 'fluxograma da reciclagem do plástico',
          visualType: 'flowchart',
          keyElements: ['coleta seletiva', 'triagem', 'reciclagem'],
          highlightFocus: 'ordem correta das etapas',
          imagePrompt: 'mostrar o processo de reciclagem',
        ),
      );

      expect(svg, contains('fluxograma da reciclagem do plástico'));
      expect(svg, contains('coleta'));
      expect(svg, contains('seletiva'));
      expect(svg, contains('triagem'));
      expect(svg, contains('reciclagem'));
      expect(svg, contains('ordem correta das etapas'));
      expect(svg, isNot(contains('observar')));
      expect(svg, isNot(contains('decidir')));
      expect(svg, isNot(contains('aplicar')));
    },
  );

  test('local flowchart renderer applies semantic palette and colorLegend', () {
    final svg = _renderSoftwareSvg(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['fluxograma'],
          reason: 'TEST',
        ),
        topic: 'fluxograma da fotossíntese',
        visualType: 'flowchart',
        keyElements: ['luz', 'clorofila', 'glicose'],
        colorLegend: [
          BlueprintColorLegendItem(
            id: 1,
            label: 'conceito principal',
            color: '#00E676',
          ),
        ],
      ),
    );

    expect(svg, contains('#00E676'));
    expect(
      svg,
      contains(PedagogicalVisualPalette.standard.supportingContextFill),
    );
    expect(svg, contains(PedagogicalVisualPalette.standard.attentionFill));
    expect(svg, isNot(contains('fill="#000000"')));
  });

  test('local renderer final SVG carries unified SIM visual identity', () {
    final result = _renderSoftwareResult(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['fluxograma'],
          reason: 'TEST',
        ),
        topic: 'fluxograma da aprendizagem ativa',
        visualType: 'flowchart',
        keyElements: ['observar', 'comparar', 'concluir'],
        highlightFocus: 'ordem de leitura do raciocínio',
      ),
    );
    final svg = Uri.decodeFull(result.dataUrl);

    expect(result.renderer, 'FlowchartRenderer');
    expect(svg, contains('font-family="Inter, Arial, sans-serif"'));
    expect(svg, contains('width="900" height="520"'));
    expect(svg, contains('markerWidth="12"'));
    expect(svg, contains(PedagogicalVisualPalette.standard.background));
    expect(svg, contains(PedagogicalVisualPalette.standard.primaryConceptFill));
    expect(svg, contains('stroke-width="4.8"'));
    expect(svg, isNot(contains('font-family="Arial, sans-serif"')));
  });

  test('local renderer changes visual richness by academic level', () {
    SoftwareVisualRequest requestFor(String academicLevel) =>
        SoftwareVisualRequest(
          n2: const VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['fluxograma'],
            reason: 'TEST',
          ),
          topic: 'fluxograma da investigação científica',
          visualType: 'flowchart',
          academicLevel: academicLevel,
          keyElements: const [
            'observar',
            'perguntar',
            'testar',
            'medir',
            'registrar',
            'revisar',
          ],
        );

    final child = _renderSoftwareSvg(requestFor('Educação Infantil'));
    final highSchool = _renderSoftwareSvg(requestFor('Ensino Médio'));
    final advanced = _renderSoftwareSvg(requestFor('Universitário'));

    expect(child, contains('observar'));
    expect(child, contains('perguntar'));
    expect(child, isNot(contains('medir')));
    expect(child, isNot(contains('data-visual-level')));

    expect(highSchool, contains('testar'));
    expect(highSchool, contains('data-visual-level="Ensino Médio"'));
    expect(highSchool, contains('medir'));
    expect(highSchool, contains('registrar'));
    expect(highSchool, isNot(contains('revisar')));

    expect(advanced, contains('data-visual-level="Avançado"'));
    expect(advanced, contains('medir'));
    expect(advanced, contains('registrar'));
    expect(advanced, contains('revisar'));
    expect(advanced.length, greaterThan(child.length));
  });

  test(
    'local renderers wrap long lesson labels instead of overflowing boxes',
    () {
      final flowchart = _renderSoftwareSvg(
        const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['fluxograma'],
            reason: 'TEST',
          ),
          topic: 'fluxograma de fotossíntese',
          visualType: 'flowchart',
          keyElements: [
            'energia luminosa absorvida pela clorofila',
            'gás carbônico combinado com água',
            'glicose armazenando energia química',
          ],
        ),
      );

      expect(flowchart, contains('<tspan'));
      expect(flowchart, contains('...'));
      expect(
        flowchart,
        isNot(contains('energia luminosa absorvida pela clorofila</text>')),
      );

      final table = _renderSoftwareSvg(
        const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['tabela'],
            reason: 'TEST',
          ),
          topic: 'tabela de transformações de energia',
          visualType: 'table',
          keyElements: [
            'situação observada',
            'energia inicial',
            'energia final',
            'lâmpada incandescente acesa',
            'energia elétrica',
            'energia luminosa',
            'painel solar exposto ao sol',
            'energia luminosa',
            'energia elétrica',
            'freio aquecendo a roda',
            'energia cinética',
            'energia térmica',
          ],
        ),
      );

      expect(table, contains('<tspan'));
      expect(table, contains('incandescente'));
      expect(table, contains('font-size="24"'));
    },
  );

  test(
    'math template labels compact long text without expanding graph layout',
    () {
      final dataUrl = tryRenderMathTemplate({
        'math_template': {
          'name': 'linear_function',
          'params': {
            'a': 1,
            'b': 2,
            'labels': {
              'title': 'função linear',
              'root': 'raiz horizontal muito longa para caber no gráfico',
            },
          },
        },
      });

      expect(dataUrl, startsWith('data:image/svg+xml;utf8,'));
      final decoded = Uri.decodeFull(dataUrl!);
      expect(decoded, contains('...'));
      expect(
        decoded,
        isNot(contains('raiz horizontal muito longa para caber no gráfico')),
      );
    },
  );

  test('local renderer ignores invalid colorLegend without breaking SVG', () {
    final svg = _renderSoftwareSvg(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['fluxograma'],
          reason: 'TEST',
        ),
        topic: 'fluxograma seguro',
        visualType: 'flowchart',
        keyElements: ['entrada', 'processo', 'saída'],
        colorLegend: [
          BlueprintColorLegendItem(
            id: 1,
            label: 'conceito principal',
            color: '#000000',
          ),
        ],
      ),
    );

    expect(svg, contains(PedagogicalVisualPalette.standard.primaryConceptFill));
    expect(svg, isNot(contains('fill="#000000"')));
  });

  test('local diagram renderers apply the pedagogical palette safely', () {
    final cases = [
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['fluxograma'],
            reason: 'TEST',
          ),
          topic: 'fluxograma da fotossíntese',
          visualType: 'flowchart',
          keyElements: ['luz', 'clorofila', 'glicose'],
        ),
        expectedColors: [
          PedagogicalVisualPalette.standard.supportingContextFill,
          PedagogicalVisualPalette.standard.primaryConceptFill,
          PedagogicalVisualPalette.standard.attentionFill,
        ],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['comparação'],
            reason: 'TEST',
          ),
          topic: 'comparação entre mitose e meiose',
          visualType: 'comparison',
          keyElements: ['mitose', 'meiose', 'uma divisão', 'duas divisões'],
        ),
        expectedColors: [
          PedagogicalVisualPalette.standard.supportingContextFill,
          PedagogicalVisualPalette.standard.primaryConceptFill,
        ],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['ciclo'],
            reason: 'TEST',
          ),
          topic: 'ciclo da água',
          visualType: 'cycle',
          keyElements: [
            'evaporação',
            'condensação',
            'precipitação',
            'escoamento',
          ],
        ),
        expectedColors: [
          PedagogicalVisualPalette.standard.supportingContextFill,
          PedagogicalVisualPalette.standard.primaryConceptFill,
          PedagogicalVisualPalette.standard.attentionFill,
          PedagogicalVisualPalette.standard.criticalFill,
        ],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['mapa conceitual'],
            reason: 'TEST',
          ),
          topic: 'mapa conceitual da fotossíntese',
          visualType: 'concept map',
          keyElements: ['fotossíntese', 'luz', 'água', 'glicose'],
        ),
        expectedColors: [
          PedagogicalVisualPalette.standard.primaryConceptFill,
          PedagogicalVisualPalette.standard.supportingContextFill,
          PedagogicalVisualPalette.standard.attentionFill,
          PedagogicalVisualPalette.standard.definitionFill,
        ],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['força'],
            reason: 'TEST',
          ),
          topic: 'diagrama de corpo livre',
          visualType: 'diagram',
          keyElements: ['bloco', 'normal', 'peso', 'força', 'atrito'],
        ),
        expectedColors: [PedagogicalVisualPalette.standard.primaryConceptFill],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['circuito'],
            reason: 'TEST',
          ),
          topic: 'circuito elétrico simples',
          visualType: 'diagram',
          keyElements: ['positivo', 'negativo', 'resistor', 'LED', 'fonte'],
        ),
        expectedColors: [PedagogicalVisualPalette.standard.attentionFill],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['linha do tempo'],
            reason: 'TEST',
          ),
          topic: 'linha do tempo da Revolução Francesa',
          visualType: 'timeline',
          keyElements: ['Estados Gerais', 'Bastilha', 'República', 'Diretório'],
        ),
        expectedColors: [
          PedagogicalVisualPalette.standard.supportingContextFill,
          PedagogicalVisualPalette.standard.primaryConceptFill,
          PedagogicalVisualPalette.standard.attentionFill,
          PedagogicalVisualPalette.standard.criticalFill,
        ],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['tabela'],
            reason: 'TEST',
          ),
          topic: 'tabela de classes gramaticais',
          visualType: 'table',
          keyElements: ['classe', 'função', 'exemplo'],
        ),
        expectedColors: [PedagogicalVisualPalette.standard.definitionFill],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['árvore sintática'],
            reason: 'TEST',
          ),
          topic: 'árvore sintática',
          visualType: 'diagram',
          keyElements: ['frase', 'sujeito', 'predicado', 'núcleo'],
        ),
        expectedColors: [
          PedagogicalVisualPalette.standard.definitionFill,
          PedagogicalVisualPalette.standard.primaryConceptFill,
          PedagogicalVisualPalette.standard.attentionFill,
        ],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['cadeia alimentar'],
            reason: 'TEST',
          ),
          topic: 'cadeia alimentar',
          visualType: 'diagram',
          keyElements: [
            'capim',
            'gafanhoto',
            'herbívoro',
            'sapo',
            'carnívoro',
            'fungos',
          ],
        ),
        expectedColors: [
          PedagogicalVisualPalette.standard.primaryConceptFill,
          PedagogicalVisualPalette.standard.supportingContextFill,
          PedagogicalVisualPalette.standard.attentionFill,
          PedagogicalVisualPalette.standard.criticalFill,
        ],
      ),
    ];

    for (final testCase in cases) {
      final svg = _renderSoftwareSvg(testCase.request);
      for (final color in testCase.expectedColors) {
        expect(svg, contains(color));
      }
      expect(svg, isNot(contains('fill="#000000"')));
      expect(svg, isNot(contains('stroke="#000000"')));
    }
  });

  test('local renderers encode visual hierarchy in final SVG', () {
    final flowchart = _renderSoftwareSvg(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['fluxograma'],
          reason: 'TEST',
        ),
        topic: 'fluxograma da fotossíntese',
        visualType: 'flowchart',
        keyElements: ['luz', 'clorofila', 'glicose'],
        highlightFocus: 'clorofila transforma energia',
      ),
    );
    expect(flowchart, contains('font-size="24"'));
    expect(flowchart, contains('font-size="20"'));
    expect(flowchart, contains('stroke-width="4.8"'));
    expect(flowchart, contains('stroke-width="3.4"'));
    expect(flowchart, contains('opacity="0.78"'));

    final comparison = _renderSoftwareSvg(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['comparação'],
          reason: 'TEST',
        ),
        topic: 'comparação entre mitose e meiose',
        visualType: 'comparison',
        keyElements: ['mitose', 'meiose', 'uma divisão', 'duas divisões'],
        highlightFocus: 'meiose reduz cromossomos',
      ),
    );
    expect(comparison, contains('font-size="24"'));
    expect(comparison, contains('font-size="18"'));
    expect(comparison, contains('stroke-width="4.8"'));
    expect(comparison, contains('opacity="0.72"'));

    final foodChain = _renderSoftwareSvg(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['cadeia alimentar'],
          reason: 'TEST',
        ),
        topic: 'cadeia alimentar',
        visualType: 'diagram',
        keyElements: [
          'capim',
          'gafanhoto',
          'herbívoro',
          'sapo',
          'carnívoro',
          'fungos',
        ],
      ),
    );
    expect(foodChain, contains('font-size="24"'));
    expect(foodChain, contains('font-size="21"'));
    expect(foodChain, contains('stroke-width="4.4"'));
  });

  test('local math renderers apply palette without weakening axes', () {
    final linear = _renderSoftwareSvg(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['linear'],
          reason: 'TEST',
        ),
        topic: 'função linear',
        visualType: 'graph',
        imagePrompt: 'reta crescente com intercepto em y',
      ),
    );
    expect(linear, contains(PedagogicalVisualPalette.standard.primaryConcept));
    expect(linear, contains(PedagogicalVisualPalette.standard.attention));
    expect(linear, contains(PedagogicalVisualPalette.standard.critical));
    expect(linear, contains(PedagogicalVisualPalette.standard.border));
    expect(linear, contains(PedagogicalVisualPalette.standard.neutralFill));
    expect(linear, contains('stroke-width="4.2"'));
    expect(linear, contains('r="10.5"'));
    expect(linear, contains('font-size="17.0"'));

    final quadratic = _renderSoftwareSvg(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['parábola'],
          reason: 'TEST',
        ),
        topic: 'parábola',
        visualType: 'graph',
        imagePrompt: 'f(x)=x^2-1',
      ),
    );
    expect(
      quadratic,
      contains(PedagogicalVisualPalette.standard.primaryConcept),
    );
    expect(quadratic, contains(PedagogicalVisualPalette.standard.attention));
    expect(quadratic, contains(PedagogicalVisualPalette.standard.critical));
    expect(quadratic, contains(PedagogicalVisualPalette.standard.border));
    expect(quadratic, contains(PedagogicalVisualPalette.standard.neutralFill));
    expect(quadratic, contains('stroke-width="4.2"'));
    expect(quadratic, contains('r="10.5"'));
    expect(quadratic, contains('font-size="17.0"'));
  });

  test('local cycle renderer uses key elements from the lesson', () {
    final svg = _renderSoftwareSvg(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['ciclo'],
          reason: 'TEST',
        ),
        topic: 'ciclo da água',
        visualType: 'cycle',
        keyElements: [
          'evaporação',
          'condensação',
          'precipitação',
          'escoamento',
        ],
        highlightFocus: 'mudança de estado da água',
      ),
    );

    expect(svg, contains('ciclo da água'));
    expect(svg, contains('evaporação'));
    expect(svg, contains('condensação'));
    expect(svg, contains('precipitação'));
    expect(svg, contains('escoamento'));
    expect(svg, isNot(contains('etapa 1')));
    expect(svg, isNot(contains('etapa 2')));
    expect(svg, isNot(contains('retorno')));
  });

  test('local comparison renderer replaces generic comparison labels', () {
    final svg = _renderSoftwareSvg(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['comparação'],
          reason: 'TEST',
        ),
        topic: 'comparação entre mitose e meiose',
        visualType: 'comparison',
        keyElements: [
          'mitose',
          'meiose',
          'uma divisão',
          'duas divisões',
          'células iguais',
          'células diferentes',
          'crescimento',
          'gametas',
        ],
        highlightFocus: 'diferença entre quantidade de divisões',
      ),
    );

    expect(svg, contains('comparação entre mitose e meiose'));
    expect(svg, contains('mitose'));
    expect(svg, contains('meiose'));
    expect(svg, contains('uma divisão'));
    expect(svg, contains('duas divisões'));
    expect(svg, contains('gametas'));
    expect(svg, isNot(contains('ideia A')));
    expect(svg, isNot(contains('ideia B')));
    expect(svg, isNot(contains('característica')));
  });

  test('local structure renderers use context and keep legacy fallback', () {
    final conceptMap = _renderSoftwareSvg(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['mapa conceitual'],
          reason: 'TEST',
        ),
        topic: 'mapa conceitual da fotossíntese',
        visualType: 'concept map',
        keyElements: ['fotossíntese', 'luz solar', 'água', 'glicose'],
      ),
    );
    expect(conceptMap, contains('fotossíntese'));
    expect(conceptMap, contains('luz solar'));
    expect(conceptMap, isNot(contains('parte 1')));

    final fallback = _renderSoftwareSvg(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['fluxograma'],
          reason: 'TEST',
        ),
        topic: 'fluxograma',
        visualType: 'flowchart',
      ),
    );
    expect(fallback, contains('observar'));
    expect(fallback, contains('decidir'));
    expect(fallback, contains('aplicar'));
  });

  test(
    'remaining local renderers replace generic labels when context exists',
    () {
      final cases = [
        (
          request: const SoftwareVisualRequest(
            n2: VisualN2Result(
              verdict: VisualVerdict.svg,
              matched: ['linha do tempo'],
              reason: 'TEST',
            ),
            topic: 'linha do tempo da Revolução Francesa',
            visualType: 'timeline',
            keyElements: [
              'Estados Gerais',
              'Bastilha',
              'República',
              'Diretório',
            ],
            highlightFocus: 'ordem dos acontecimentos principais',
          ),
          expected: ['Estados Gerais', 'Bastilha', 'República', 'Diretório'],
          blocked: ['início', 'mudança', 'evento-chave', 'resultado'],
        ),
        (
          request: const SoftwareVisualRequest(
            n2: VisualN2Result(
              verdict: VisualVerdict.svg,
              matched: ['tabela'],
              reason: 'TEST',
            ),
            topic: 'tabela de classes gramaticais',
            visualType: 'table',
            keyElements: [
              'classe',
              'função',
              'exemplo',
              'substantivo',
              'nomeia',
              'casa',
              'verbo',
              'ação',
              'correr',
              'adjetivo',
              'qualifica',
              'azul',
            ],
          ),
          expected: ['classe', 'função', 'substantivo', 'qualifica'],
          blocked: ['tipo', 'característica', 'regra', 'atenção'],
        ),
        (
          request: const SoftwareVisualRequest(
            n2: VisualN2Result(
              verdict: VisualVerdict.svg,
              matched: ['força'],
              reason: 'TEST',
            ),
            topic: 'diagrama de corpo livre',
            visualType: 'diagram',
            keyElements: [
              'caixa',
              'normal',
              'peso',
              'força aplicada',
              'atrito cinético',
            ],
            highlightFocus: 'sentido das forças no bloco',
          ),
          expected: [
            'caixa',
            'normal',
            'peso',
            'força aplicada',
            'atrito cinético',
          ],
          blocked: ['>N<', '>P<'],
        ),
        (
          request: const SoftwareVisualRequest(
            n2: VisualN2Result(
              verdict: VisualVerdict.svg,
              matched: ['circuito'],
              reason: 'TEST',
            ),
            topic: 'circuito elétrico simples',
            visualType: 'diagram',
            keyElements: [
              'polo positivo',
              'polo negativo',
              'resistor 10Ω',
              'LED',
              'bateria',
            ],
          ),
          expected: ['polo positivo', 'polo negativo', 'resistor 10Ω', 'LED'],
          blocked: ['lâmpada'],
        ),
        (
          request: const SoftwareVisualRequest(
            n2: VisualN2Result(
              verdict: VisualVerdict.svg,
              matched: ['árvore sintática'],
              reason: 'TEST',
            ),
            topic: 'árvore sintática da frase simples',
            visualType: 'diagram',
            keyElements: [
              'frase',
              'menino',
              'correu',
              'núcleo nominal',
              'adjunto',
              'verbo',
              'circunstância',
            ],
          ),
          expected: ['frase', 'menino', 'correu', 'circunstâ'],
          blocked: ['oração', 'sujeito', 'predicado', 'complemento'],
        ),
        (
          request: const SoftwareVisualRequest(
            n2: VisualN2Result(
              verdict: VisualVerdict.svg,
              matched: ['cadeia alimentar'],
              reason: 'TEST',
            ),
            topic: 'cadeia alimentar do campo',
            visualType: 'diagram',
            keyElements: [
              'capim',
              'gafanhoto',
              'herbívoro',
              'sapo',
              'carnívoro',
              'fungos',
            ],
            highlightFocus: 'fluxo de energia entre seres vivos',
          ),
          expected: ['capim', 'gafanhoto', 'herbívoro', 'sapo', 'fungos'],
          blocked: ['produtor', 'consumidor', 'decomp.'],
        ),
      ];

      for (final testCase in cases) {
        final svg = _renderSoftwareSvg(testCase.request);
        for (final expected in testCase.expected) {
          for (final part in expected.split(' ')) {
            expect(svg, contains(part));
          }
        }
        for (final blocked in testCase.blocked) {
          expect(svg, isNot(contains(blocked)));
        }
      }
    },
  );

  test('software catalog selects specialized renderers by domain evidence', () {
    final cases = [
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['fluxograma'],
            reason: 'TEST',
          ),
          topic: 'algoritmo de entrada processamento e saída',
          visualType: 'flowchart',
          keyElements: ['entrada', 'validação', 'decisão', 'saída'],
          imagePrompt: 'fluxo lógico de programação',
        ),
        renderer: 'ProgrammingFlowRenderer',
        expected: ['PROGRAMAÇÃO', 'entrada', 'validação', 'decisão', 'saída'],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['reação'],
            reason: 'TEST',
          ),
          topic: 'reação química entre reagentes e produtos',
          visualType: 'diagram',
          keyElements: ['reagentes', 'catalisador', 'produtos', 'evidência'],
          imagePrompt: 'moléculas antes e depois da reação',
        ),
        renderer: 'ChemistryReactionRenderer',
        expected: ['química', 'reagentes', 'catalisador', 'produtos'],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['mapa'],
            reason: 'TEST',
          ),
          topic: 'geografia do relevo clima e região',
          visualType: 'mapa',
          keyElements: ['região', 'relevo', 'clima', 'fluxo', 'impacto'],
          imagePrompt: 'camadas espaciais de uma região',
        ),
        renderer: 'GeographyLayersRenderer',
        expected: ['geografia', 'região', 'relevo', 'clima', 'fluxo'],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['premissa'],
            reason: 'TEST',
          ),
          topic: 'lógica com premissa e conclusão',
          visualType: 'diagram',
          keyElements: [
            'premissa maior',
            'premissa menor',
            'inferência',
            'conclusão',
          ],
          imagePrompt: 'argumento lógico com regra de inferência',
        ),
        renderer: 'LogicArgumentRenderer',
        expected: ['lógica', 'premissa maior', 'inferência', 'conclusão'],
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['oferta'],
            reason: 'TEST',
          ),
          topic: 'economia de oferta demanda e mercado',
          visualType: 'diagram',
          keyElements: ['oferta', 'demanda', 'preço', 'equilíbrio', 'lucro'],
          imagePrompt: 'relação econômica entre oferta e demanda',
        ),
        renderer: 'BusinessFlowRenderer',
        expected: ['economia', 'oferta', 'demanda', 'preço', 'equilíbrio'],
      ),
    ];

    for (final testCase in cases) {
      final result = _renderSoftwareResult(testCase.request);
      final svg = Uri.decodeFull(result.dataUrl);

      expect(result.renderer, testCase.renderer);
      expect(
        svg,
        contains(PedagogicalVisualPalette.standard.primaryConceptFill),
      );
      expect(svg, contains('font-size="20"'));
      expect(svg, contains('stroke-width="4.8"'));
      for (final expected in testCase.expected) {
        for (final part in expected.split(' ')) {
          expect(svg, contains(part));
        }
      }
      expect(svg, isNot(contains('fill="#000000"')));
    }
  });

  test('existing domain engines remain selected before generic fallback', () {
    final cases = [
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['parábola'],
            reason: 'TEST',
          ),
          topic: 'matemática função quadrática parábola',
          visualType: 'graph',
          imagePrompt: 'f(x)=x²-4x+3',
        ),
        renderer: 'QuadraticRenderer',
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['força'],
            reason: 'TEST',
          ),
          topic: 'física diagrama de corpo livre com força resultante',
          visualType: 'diagram',
          keyElements: ['bloco', 'normal', 'peso', 'força', 'atrito'],
        ),
        renderer: 'ForceDiagramRenderer',
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['cadeia alimentar'],
            reason: 'TEST',
          ),
          topic: 'biologia cadeia alimentar do ecossistema',
          visualType: 'diagram',
          keyElements: ['capim', 'gafanhoto', 'sapo', 'cobra', 'fungos'],
        ),
        renderer: 'FoodChainRenderer',
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['linha do tempo'],
            reason: 'TEST',
          ),
          topic: 'história linha do tempo da Revolução Francesa',
          visualType: 'timeline',
          keyElements: ['Estados Gerais', 'Bastilha', 'República', 'Diretório'],
        ),
        renderer: 'TimelineRenderer',
      ),
      (
        request: const SoftwareVisualRequest(
          n2: VisualN2Result(
            verdict: VisualVerdict.svg,
            matched: ['árvore sintática'],
            reason: 'TEST',
          ),
          topic: 'gramática árvore sintática com sujeito e predicado',
          visualType: 'diagram',
          keyElements: ['oração', 'sujeito', 'predicado', 'verbo'],
        ),
        renderer: 'SyntaxTreeRenderer',
      ),
    ];

    for (final testCase in cases) {
      final result = _renderSoftwareResult(testCase.request);
      expect(result.renderer, testCase.renderer);
      expect(Uri.decodeFull(result.dataUrl), contains('<svg'));
    }
  });

  test('unknown domain keeps safe generic renderer fallback', () {
    final result = _renderSoftwareResult(
      const SoftwareVisualRequest(
        n2: VisualN2Result(
          verdict: VisualVerdict.svg,
          matched: ['fluxograma'],
          reason: 'TEST',
        ),
        topic: 'fluxograma operacional sem matéria definida',
        visualType: 'flowchart',
        keyElements: ['receber pedido', 'verificar dados', 'responder'],
      ),
    );
    final svg = Uri.decodeFull(result.dataUrl);

    expect(result.renderer, 'FlowchartRenderer');
    expect(svg, contains('receber'));
    expect(svg, contains('pedido'));
    expect(svg, contains(PedagogicalVisualPalette.standard.primaryConceptFill));
    expect(svg, contains('<tspan'));
  });

  test('visual pipeline fetches only usable paid image data url', () async {
    final client = FakeImageClient();
    final pipeline = LessonVisualPipeline(
      imageClient: client,
      visualRouterClient: const FakeVisualRouterClient(),
    );

    expect(
      await pipeline.fetchPaidLessonImage(
        'prompt',
        'lesson',
        acceptedOfferId: 'offer-1',
      ),
      isNotNull,
    );
    client.next = 'bad';
    expect(
      await pipeline.fetchPaidLessonImage(
        'prompt',
        'lesson',
        acceptedOfferId: 'offer-2',
      ),
      isNull,
    );
  });

  test(
    'local software resolves schematic visual as free SVG without paid image',
    () async {
      final client = FakeImageClient();
      final router = CapturingVisualRouterClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: router,
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'important',
          topic: 'diagrama de etapas de um algoritmo',
          visualType: 'diagram',
        ),
        lessonKey: 'lesson',
        allowPaidImages: false,
      );

      expect(result.source, 'local_software');
      expect(result.displayUrl, startsWith('data:image/svg+xml;utf8,'));
      expect(client.calls, 0);
      expect(router.calls, 0);
    },
  );

  test('visual escalation sends rich local candidate to N3 first', () async {
    final client = FakeImageClient();
    final n3Svg = sanitizeAndEncodeSvg(
      '<svg viewBox="0 0 900 560"><rect width="900" height="560" fill="#F8FAFC"/>'
      '<text x="80" y="90" fill="#0F172A" font-size="18">sintoma inicial</text>'
      '<text x="80" y="130" fill="#0F172A" font-size="18">triagem</text>'
      '<text x="80" y="170" fill="#0F172A" font-size="18">hipótese</text>'
      '<text x="80" y="210" fill="#0F172A" font-size="18">conduta final</text></svg>',
    );
    final router = CapturingVisualRouterClient(
      result: VisualN3Result(
        verdict: VisualVerdict.svg,
        reason: 'TEST_N3_RICH_SVG',
        svgDataUrl: n3Svg,
      ),
    );
    final pipeline = LessonVisualPipeline(
      imageClient: client,
      visualRouterClient: router,
    );

    final result = await pipeline.resolveVisual(
      trigger: const LessonVisualTrigger(
        needsImage: true,
        pedagogicalNeed: 'essential',
        topic: 'fluxograma contextual de decisão clínica',
        visualType: 'flowchart',
        keyElements: [
          'sintoma inicial',
          'triagem',
          'hipótese',
          'exame',
          'risco',
          'conduta',
        ],
        highlightFocus: 'relação entre risco, hipótese e conduta final',
        complexity: 'high',
        imagePrompt: 'composição rica em camadas com decisões específicas',
      ),
      lessonKey: 'rich-local-goes-n3',
      allowPaidImages: false,
    );

    expect(result.source, 'n3_software');
    expect(result.displayUrl, n3Svg);
    expect(router.calls, 1);
    expect(router.lastComplexity, 'high');
    expect(router.lastKeyElements, contains('conduta'));
    expect(client.calls, 0);
  });

  test(
    'visual escalation calls N3 before paid image when complexity demands it',
    () async {
      final client = FakeImageClient();
      final router = CapturingVisualRouterClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: router,
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'sophisticated visual explanation',
          topic: 'mapa conceitual de equilíbrio ecológico',
          visualType: 'diagram',
          keyElements: [
            'produtores',
            'consumidores',
            'decompositores',
            'energia',
            'matéria',
            'impacto humano',
          ],
          highlightFocus: 'como energia e matéria mudam em relações múltiplas',
          complexity: 'complex',
          imagePrompt: 'visual rico e contextual com múltiplos níveis',
        ),
        lessonKey: 'n3-before-paid',
        allowPaidImages: true,
        acceptedOfferId: 'offer-rich',
      );

      expect(router.calls, 1);
      expect(result.source, 'ai_blueprint');
      expect(client.calls, 1);
      expect(client.lastVisualTrigger?['complexity'], 'complex');
    },
  );

  test('visual escalation rejects generic local candidate before paid path', () async {
    final client = FakeImageClient();
    final n3Svg = sanitizeAndEncodeSvg(
      '<svg viewBox="0 0 900 560"><rect width="900" height="560" fill="#F8FAFC"/>'
      '<text x="80" y="90" fill="#0F172A" font-size="18">glicose</text>'
      '<text x="80" y="130" fill="#0F172A" font-size="18">ATP</text>'
      '<text x="80" y="170" fill="#0F172A" font-size="18">mitocôndria</text>'
      '<text x="80" y="210" fill="#0F172A" font-size="18">oxigênio</text></svg>',
    );
    final router = CapturingVisualRouterClient(
      result: VisualN3Result(
        verdict: VisualVerdict.svg,
        reason: 'TEST_N3_SPECIFIC_SVG',
        svgDataUrl: n3Svg,
      ),
    );
    final genericSvg = sanitizeAndEncodeSvg(
      '<svg viewBox="0 0 900 560"><rect x="40" y="40" width="160" height="80"/>'
      '<text x="60" y="88" fill="#0F172A" font-size="16">modelo genérico</text></svg>',
    )!;
    final pipeline = LessonVisualPipeline(
      imageClient: client,
      visualRouterClient: router,
      softwareRenderCatalog: StubSoftwareRenderCatalog(
        result: SoftwareRenderResult(
          dataUrl: genericSvg,
          renderer: 'FlowchartRenderer',
          role: inferVisualPedagogicalRole(visualType: 'flowchart'),
        ),
      ),
    );

    final result = await pipeline.resolveVisual(
      trigger: const LessonVisualTrigger(
        needsImage: true,
        pedagogicalNeed: 'important',
        topic: 'fluxograma de metabolismo celular',
        visualType: 'flowchart',
        keyElements: ['glicose', 'ATP', 'mitocôndria', 'oxigênio'],
        highlightFocus: 'relação entre glicose, oxigênio e produção de ATP',
        imagePrompt: 'desenho específico do metabolismo',
      ),
      lessonKey: 'generic-local-escalates',
      allowPaidImages: false,
    );

    expect(router.calls, 1);
    expect(result.source, 'n3_software');
    expect(result.displayUrl, n3Svg);
    expect(client.calls, 0);
  });

  test(
    'visual escalation falls back to accepted local SVG when N3 transport fails',
    () async {
      final client = FakeImageClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: const ThrowingVisualRouterClient(),
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'essential',
          topic: 'fluxograma contextual de decisão',
          visualType: 'flowchart',
          keyElements: [
            'entrada',
            'validação',
            'decisão',
            'resultado',
            'erro',
            'correção',
          ],
          highlightFocus: 'relação entre erro e correção',
          complexity: 'high',
          imagePrompt: 'fluxo rico com múltiplas etapas',
        ),
        lessonKey: 'n3-fails-local-fallback',
        allowPaidImages: true,
        acceptedOfferId: 'offer-should-not-run',
      );

      expect(result.source, 'local_software');
      expect(result.displayUrl, startsWith('data:image/svg+xml;utf8,'));
      expect(client.calls, 0);
    },
  );

  test(
    'visual pipeline passes complete trigger context to local renderer',
    () async {
      const legend = [
        BlueprintColorLegendItem(id: 1, label: 'entrada', color: '#00E5FF'),
        BlueprintColorLegendItem(id: 2, label: 'saída', color: '#00E676'),
      ];
      final catalog = CapturingSoftwareRenderCatalog();
      final router = CapturingVisualRouterClient();
      final pipeline = LessonVisualPipeline(
        imageClient: FakeImageClient(),
        visualRouterClient: router,
        softwareRenderCatalog: catalog,
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'essential',
          topic: 'fluxograma de entrada e saída',
          visualType: 'diagram',
          keyElements: ['entrada', 'processamento', 'saída'],
          colorLegend: legend,
          highlightFocus: 'diferença entre entrada e saída',
          complexity: 'technical',
          imagePrompt: 'desenhar caixas conectadas por setas',
        ),
        lessonKey: 'context-transport',
        stableLang: 'pt-BR',
        academicLevel: 'Ensino Médio',
        allowPaidImages: false,
      );

      expect(result.source, 'skip_no_paid');
      final request = catalog.lastRequest;
      expect(request, isNotNull);
      expect(request!.colorLegend, legend);
      expect(request.keyElements, ['entrada', 'processamento', 'saída']);
      expect(request.highlightFocus, 'diferença entre entrada e saída');
      expect(request.complexity, 'technical');
      expect(request.pedagogicalNeed, 'essential');
      expect(request.visualType, 'diagram');
      expect(request.imagePrompt, 'desenhar caixas conectadas por setas');
      expect(request.topic, 'fluxograma de entrada e saída');
      expect(request.academicLevel, 'Ensino Médio');
      expect(request.pedagogicalGoal, 'diferença entre entrada e saída');
      expect(router.lastKeyElements, ['entrada', 'processamento', 'saída']);
    },
  );

  test('math template custom formula renders deterministic SVG', () {
    final dataUrl = tryRenderMathTemplate({
      'math_template': {
        'name': 'custom',
        'formula': 'y = 3x^2 - 2x + 1',
        'params': {
          'labels': {'title': 'formula custom'},
        },
      },
    });

    expect(dataUrl, startsWith('data:image/svg+xml;utf8,'));
    final decoded = Uri.decodeFull(dataUrl!);
    expect(decoded, contains('y = 3'));
    expect(decoded, contains('x²'));
  });

  test('math template custom formula accepts f(x) notation', () {
    final dataUrl = tryRenderMathTemplate({
      'math_template': {
        'name': 'custom',
        'params': {
          'formula': 'f(x)=x²-4x+3',
          'labels': {'title': 'f(x)'},
        },
      },
    });

    expect(dataUrl, startsWith('data:image/svg+xml;utf8,'));
    final decoded = Uri.decodeFull(dataUrl!);
    expect(decoded, contains('x²'));
    expect(decoded, contains('− 4'));
    expect(decoded, contains('+ 3'));
  });

  test('math template aliases render parabola as free quadratic SVG', () {
    final dataUrl = tryRenderMathTemplate({
      'math_template': {
        'name': 'parabola',
        'params': {
          'a': 1,
          'b': 0,
          'c': 0,
          'labels': {'title': 'Parabola'},
        },
      },
    });

    expect(dataUrl, startsWith('data:image/svg+xml;utf8,'));
    final decoded = Uri.decodeFull(dataUrl!);
    expect(decoded, contains('Parabola'));
    expect(decoded, contains('x²'));
  });

  test(
    'N3 delegates schematic routing to injected visual router client',
    () async {
      final n2 = classifyVisualByKeywords(
        topic: 'segunda lei de Newton',
        visualType: 'diagram',
        imagePrompt: 'diagrama de forca resultante em um bloco',
      );
      final svg = sanitizeAndEncodeSvg(
        '<svg width="120" height="80"><text x="10" y="20">Forca</text></svg>',
      );

      final n3 = await routeVisualCheapN3(
        client: FakeVisualRouterClient(svgDataUrl: svg),
        n2: n2,
        topic: 'segunda lei de Newton',
        visualType: 'diagram',
        imagePrompt: 'diagrama de forca resultante em um bloco',
      );
      final decoded = Uri.decodeFull(n3.svgDataUrl ?? '');

      expect(n3.verdict, VisualVerdict.svg);
      expect(decoded, contains('Forca'));
    },
  );

  test('N3 transport failure keeps status and requestId explicit', () async {
    final n3 = await routeVisualCheapN3(
      client: const ThrowingVisualRouterClient(),
      n2: const VisualN2Result(
        verdict: VisualVerdict.ambiguous,
        matched: ['graph'],
        reason: 'N2_AMBIGUOUS',
      ),
      topic: 'grafico',
      visualType: 'graph',
      imagePrompt: 'grafico de funcao',
    );

    expect(n3.verdict, VisualVerdict.ambiguous);
    expect(n3.transportFailed, isTrue);
    expect(n3.statusCode, 401);
    expect(n3.requestId, 'vis-test');
    expect(n3.reason, startsWith('N3_TRANSPORT_FAILED_401'));
  });

  test('visual pipeline rejects N3 SVG when critic flags it', () async {
    final client = FakeImageClient()..next = null;
    final noisySvg = sanitizeAndEncodeSvg(
      '<svg viewBox="0 0 10 10">'
      '<text x="1" y="1">1</text><text x="1" y="2">2</text>'
      '<text x="1" y="3">3</text><text x="1" y="4">4</text>'
      '</svg>',
    );
    final pipeline = LessonVisualPipeline(
      imageClient: client,
      visualRouterClient: FakeVisualRouterClient(svgDataUrl: noisySvg),
      imageCritic: const ImagePedagogicalCritic(maxTextNodes: 2),
    );

    final result = await pipeline.resolveVisual(
      trigger: const LessonVisualTrigger(
        needsImage: true,
        pedagogicalNeed: 'important',
        topic: 'diagrama pedagogico sem template local',
        visualType: 'diagram',
        imagePrompt: 'diagrama muito textual',
      ),
      lessonKey: 'critic-rejects-n3',
      allowPaidImages: false,
    );

    expect(result.displayUrl, isNot(noisySvg));
    expect(client.calls, 0);
  });

  test('visual pipeline retries N3 when SVG has tiny footprint', () async {
    final tinySvg = sanitizeAndEncodeSvg(
      '<svg viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="430" cy="280" r="30" fill="#DCFCE7" stroke="#16A34A"/>'
      '<text x="430" y="286" text-anchor="middle" fill="#0F172A" font-size="16">ATP</text>'
      '</svg>',
    )!;
    final correctedSvg = sanitizeAndEncodeSvg(
      '<svg viewBox="0 0 900 560" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="120" y="90" width="660" height="350" rx="28" fill="#DCFCE7" stroke="#16A34A"/>'
      '<circle cx="270" cy="260" r="72" fill="#E0F2FE" stroke="#0284C7"/>'
      '<circle cx="450" cy="260" r="72" fill="#FEF3C7" stroke="#CA8A04"/>'
      '<circle cx="630" cy="260" r="72" fill="#FCE7F3" stroke="#BE185D"/>'
      '<path d="M342 260 L378 260 M522 260 L558 260" stroke="#0F172A" stroke-width="5"/>'
      '<text x="270" y="266" text-anchor="middle" fill="#0F172A" font-size="22">entrada</text>'
      '<text x="450" y="266" text-anchor="middle" fill="#0F172A" font-size="22">transformação</text>'
      '<text x="630" y="266" text-anchor="middle" fill="#0F172A" font-size="22">saída</text>'
      '</svg>',
    )!;
    final router = SequenceVisualRouterClient([
      VisualN3Result(
        verdict: VisualVerdict.svg,
        reason: 'TEST_TINY_SVG',
        svgDataUrl: tinySvg,
      ),
      VisualN3Result(
        verdict: VisualVerdict.svg,
        reason: 'TEST_STRICT_SVG',
        svgDataUrl: correctedSvg,
      ),
    ]);
    final pipeline = LessonVisualPipeline(
      imageClient: FakeImageClient()..next = null,
      visualRouterClient: router,
      softwareRenderCatalog: const StubSoftwareRenderCatalog(),
    );

    final result = await pipeline.resolveVisual(
      trigger: const LessonVisualTrigger(
        needsImage: true,
        pedagogicalNeed: 'important',
        topic: 'fluxograma de entrada e saída de energia',
        visualType: 'diagram',
        imagePrompt: 'mostre entrada, transformação e saída de energia',
        keyElements: ['entrada', 'transformação', 'saída'],
      ),
      lessonKey: 'retry-tiny-svg',
      stableLang: 'pt-BR',
      allowPaidImages: false,
    );

    expect(router.calls, 2);
    expect(router.prompts.last, contains('Hard visual contract'));
    expect(result.displayUrl, correctedSvg);
    expect(result.source, 'n3_software_strict_retry');
  });

  test(
    'N3 failure keeps diagnostic reason before falling back to paid path',
    () async {
      final n2 = classifyVisualByKeywords(
        topic: 'parábola de uma função quadrática',
        visualType: 'graph',
        imagePrompt: 'desenhe a parábola',
      );

      final n3 = await routeVisualCheapN3(
        client: const ThrowingVisualRouterClient(),
        n2: n2,
        topic: 'parábola de uma função quadrática',
        visualType: 'graph',
        imagePrompt: 'desenhe a parábola',
      );

      expect(n3.verdict, VisualVerdict.ambiguous);
      expect(n3.reason, contains('N3_TRANSPORT_FAILED_401'));
      expect(n3.reason, contains('401'));
    },
  );

  test('visual pipeline forwards pedagogical trigger context to N3', () async {
    final router = CapturingVisualRouterClient();
    final pipeline = LessonVisualPipeline(
      imageClient: FakeImageClient(),
      visualRouterClient: router,
      softwareRenderCatalog: const StubSoftwareRenderCatalog(),
    );

    await pipeline.resolveVisual(
      trigger: const LessonVisualTrigger(
        needsImage: true,
        pedagogicalNeed: 'important',
        topic: 'fluxograma de entrada e saída',
        visualType: 'diagram',
        keyElements: ['entrada', 'processamento', 'saída'],
        highlightFocus: 'ordem entre entrada e saída',
        complexity: 'simple',
        imagePrompt: 'desenhar caixas conectadas por setas',
      ),
      lessonKey: 'n3-context',
      stableLang: 'pt-BR',
      allowPaidImages: false,
    );

    expect(router.lastTopic, 'fluxograma de entrada e saída');
    expect(router.lastVisualType, 'diagram');
    expect(router.lastImagePrompt, 'desenhar caixas conectadas por setas');
    expect(router.lastKeyElements, ['entrada', 'processamento', 'saída']);
    expect(router.lastPedagogicalNeed, 'important');
    expect(router.lastHighlightFocus, 'ordem entre entrada e saída');
    expect(router.lastComplexity, 'simple');
    expect(router.lastStableLang, 'pt-BR');
    expect(router.lastN2?.pedagogicalRole?.id, isNotEmpty);
  });

  test('visual pipeline respects N3 no_image without paid offer', () async {
    final client = FakeImageClient();
    final telemetry = VisualFunnelTelemetry();
    final router = CapturingVisualRouterClient(
      result: const VisualN3Result(
        verdict: VisualVerdict.noImage,
        reason: 'TEST_VISUAL_NOT_HELPFUL',
        confidence: 0.84,
        pedagogicalRole: 'concept_anchor',
      ),
    );
    final pipeline = LessonVisualPipeline(
      imageClient: client,
      visualRouterClient: router,
      telemetry: telemetry,
      softwareRenderCatalog: const StubSoftwareRenderCatalog(),
    );

    final result = await pipeline.resolveVisual(
      trigger: const LessonVisualTrigger(
        needsImage: true,
        pedagogicalNeed: 'important',
        topic: 'fluxograma visual que pode entregar a resposta',
        visualType: 'diagram',
        imagePrompt:
            'desenhar caixas conectadas por setas com risco pedagógico',
      ),
      lessonKey: 'n3-no-image',
      allowPaidImages: true,
      acceptedOfferId: null,
    );

    expect(result.source, 'n3_no_image');
    expect(result.displayUrl, isNull);
    expect(client.calls, 0);
    expect(telemetry.snapshot().noImage, 1);
    expect(telemetry.events.single.source, 'n3_no_image');
  });

  test('visual funnel telemetry measures software rate', () async {
    final telemetry = VisualFunnelTelemetry();
    final svg = sanitizeAndEncodeSvg(
      '<svg viewBox="0 0 10 10"><text x="1" y="5">ok</text></svg>',
    );
    final pipeline = LessonVisualPipeline(
      imageClient: FakeImageClient(),
      visualRouterClient: FakeVisualRouterClient(svgDataUrl: svg),
      telemetry: telemetry,
    );

    await pipeline.resolveVisual(
      trigger: const LessonVisualTrigger(
        needsImage: true,
        pedagogicalNeed: 'important',
        topic: 'diagrama de etapas',
        visualType: 'diagram',
      ),
      lessonKey: 'telemetry-software',
      allowPaidImages: false,
    );

    final snapshot = telemetry.snapshot();
    expect(snapshot.total, 1);
    expect(snapshot.software, 1);
    expect(snapshot.softwareRate, 1);
    expect(telemetry.events.single.source, 'local_software');
  });

  test(
    'N3 unavailable uses local software before paid offer when deterministic',
    () async {
      final client = FakeImageClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: const ThrowingVisualRouterClient(),
      );

      const trigger = LessonVisualTrigger(
        needsImage: true,
        pedagogicalNeed: 'important',
        topic: 'parábola de uma função quadrática com intercepto Y em (0, 3)',
        visualType: 'graph',
        imagePrompt: 'Observe a parábola no gráfico.',
      );

      final result = await pipeline.resolveVisual(
        trigger: trigger,
        lessonKey: 'parabola-lesson',
        allowPaidImages: true,
        acceptedOfferId: null,
      );

      expect(result.source, 'local_software');
      expect(result.displayUrl, startsWith('data:image/svg+xml;utf8,'));
      expect(client.calls, 0);
    },
  );

  test(
    'deterministic graph stays local even when visual request is rich',
    () async {
      final client = FakeImageClient();
      final router = CapturingVisualRouterClient(
        result: const VisualN3Result(
          verdict: VisualVerdict.svg,
          reason: 'N3_SHOULD_NOT_BE_NEEDED_FOR_EXACT_GRAPH',
          svgDataUrl: 'data:image/svg+xml;utf8,%3Csvg%3Ebad%3C%2Fsvg%3E',
        ),
      );
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: router,
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'essential',
          topic: 'função quadrática',
          visualType: 'graph',
          keyElements: [
            'coeficiente a',
            'coeficiente b',
            'coeficiente c',
            'vértice',
            'intercepto',
          ],
          complexity: 'high',
          highlightFocus: 'mostrar a parábola exata sem alterar coeficientes',
          imagePrompt: 'desenhe h(t) = -2t^2 + 8t + 10 com vértice e eixos',
        ),
        lessonKey: 'deterministic-rich-graph',
        allowPaidImages: true,
        acceptedOfferId: 'offer-should-not-be-used',
      );

      expect(result.source, 'local_software');
      expect(Uri.decodeFull(result.displayUrl!), contains('-2·x² + 8·x + 10'));
      expect(router.calls, 0);
      expect(client.calls, 0);
    },
  );

  test(
    'formula without math_template renders local SVG before paid offer',
    () async {
      final client = FakeImageClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: const ThrowingVisualRouterClient(),
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'important',
          topic: 'parábola',
          visualType: 'graph',
          imagePrompt: 'desenhe f(x)=x²-4x+3 no plano cartesiano',
        ),
        lessonKey: 'parabola-exact-formula',
        allowPaidImages: true,
        acceptedOfferId: null,
      );

      expect(result.source, 'local_software');
      expect(result.displayUrl, startsWith('data:image/svg+xml;utf8,'));
      expect(Uri.decodeFull(result.displayUrl!), contains('x²'));
      expect(client.calls, 0);
    },
  );

  test(
    'physics height function h(t) renders exact local quadratic SVG before paid offer',
    () async {
      final client = FakeImageClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: const ThrowingVisualRouterClient(),
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'important',
          topic: 'apoio visual',
          visualType: 'graph',
          imagePrompt:
              'A altura h(t) = -2t^2 + 8t + 10 descreve uma bola lançada '
              'para cima. Mostre o gráfico altura por tempo e a altura inicial.',
        ),
        lessonKey: 'physics-height-ht',
        allowPaidImages: true,
        acceptedOfferId: null,
      );

      expect(result.source, 'local_software');
      expect(result.displayUrl, startsWith('data:image/svg+xml;utf8,'));
      final decoded = Uri.decodeFull(result.displayUrl!);
      expect(decoded, contains('x²'));
      expect(decoded, contains('-2'));
      expect(decoded, contains('+ 8'));
      expect(decoded, contains('+ 10'));
      expect(client.calls, 0);
    },
  );

  test(
    'poor but recoverable math visual trigger renders local graph before paid offer',
    () async {
      final client = FakeImageClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: const ThrowingVisualRouterClient(),
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'important',
          topic: 'apoio visual',
          visualType: 'diagram',
          imagePrompt:
              'Para f(x)=2x^2-3x+1, desenhar plano cartesiano com parábola, eixo x, eixo y e vértice.',
        ),
        lessonKey: 'recovered-poor-math-trigger',
        allowPaidImages: true,
        acceptedOfferId: null,
      );

      expect(result.source, 'local_software');
      expect(result.displayUrl, startsWith('data:image/svg+xml;utf8,'));
      expect(Uri.decodeFull(result.displayUrl!), contains('<svg'));
      expect(client.calls, 0);
    },
  );

  test(
    'poor but recoverable physics force trigger renders local SVG before paid offer',
    () async {
      final client = FakeImageClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: const ThrowingVisualRouterClient(),
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'important',
          topic: 'apoio visual',
          visualType: 'diagram',
          imagePrompt:
              'Um bloco recebe peso, normal, atrito e força aplicada; mostrar vetores e força resultante.',
        ),
        lessonKey: 'recovered-poor-force-trigger',
        allowPaidImages: true,
        acceptedOfferId: null,
      );

      expect(result.source, 'local_software');
      final svg = Uri.decodeFull(result.displayUrl!);
      expect(svg, contains('peso'));
      expect(svg, contains('normal'));
      expect(svg, contains('resultante'));
      expect(client.calls, 0);
    },
  );

  test(
    'physics position function lesson renders local kinematics SVG before paid offer',
    () async {
      final client = FakeImageClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: const ThrowingVisualRouterClient(),
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'important',
          topic: 'função horária da posição no movimento uniforme',
          visualType: 'graph',
          keyElements: [
            'posição inicial 15 km',
            'velocidade constante 25 km/h',
            's = 15 + 25t',
          ],
          highlightFocus:
              'mostrar que a posição inicial soma com a velocidade vezes o tempo',
          imagePrompt:
              'Um ciclista inicia no marco de 15 km e mantém velocidade constante de 25 km/h; desenhar gráfico posição x tempo e a equação s = 15 + 25t.',
        ),
        lessonKey: 'physics-position-function',
        allowPaidImages: true,
        acceptedOfferId: null,
      );

      expect(result.source, 'local_software');
      final svg = Uri.decodeFull(result.displayUrl!);
      expect(svg, contains('15'));
      expect(svg, contains('25'));
      expect(svg, contains('s(t)'));
      expect(client.calls, 0);
    },
  );

  test(
    'poor but recoverable chemistry trigger renders local SVG before paid offer',
    () async {
      final client = FakeImageClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: const ThrowingVisualRouterClient(),
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'important',
          topic: 'apoio visual',
          visualType: 'diagram',
          imagePrompt:
              'Reação química com reagentes, seta de reação, produtos e conservação dos átomos.',
        ),
        lessonKey: 'recovered-poor-chemistry-trigger',
        allowPaidImages: true,
        acceptedOfferId: null,
      );

      expect(result.source, 'local_software');
      final svg = Uri.decodeFull(result.displayUrl!);
      expect(svg, contains('Reação'));
      expect(svg, contains('reagentes'));
      expect(client.calls, 0);
    },
  );

  test(
    'software catalog candidates render locally when N3 is unavailable',
    () async {
      final cases = [
        (
          lessonKey: 'timeline-lesson',
          topic: 'linha do tempo da Revolucao Francesa',
          visualType: 'timeline',
          prompt: 'mostre uma linha do tempo com inicio, mudança e resultado',
        ),
        (
          lessonKey: 'flowchart-lesson',
          topic: 'fluxograma para resolver uma equacao em tres passos',
          visualType: 'flowchart',
          prompt: 'organize os passos do raciocinio',
        ),
        (
          lessonKey: 'comparison-lesson',
          topic: 'comparacao entre substantivo concreto e abstrato',
          visualType: 'comparison',
          prompt: 'compare as duas ideias sem foto realista',
        ),
        (
          lessonKey: 'cycle-lesson',
          topic: 'ciclo da agua com evaporacao condensacao e precipitacao',
          visualType: 'cycle',
          prompt: 'desenhe um ciclo esquematico',
        ),
        (
          lessonKey: 'table-lesson',
          topic: 'tabela de classes gramaticais',
          visualType: 'table',
          prompt: 'organize em colunas tipo caracteristica e exemplo',
        ),
        (
          lessonKey: 'force-lesson',
          topic: 'diagrama de corpo livre com forca resultante em um bloco',
          visualType: 'diagram',
          prompt:
              'mostre as setas de força normal peso atrito e força aplicada',
        ),
        (
          lessonKey: 'circuit-lesson',
          topic: 'circuito eletrico simples com fonte resistor e lampada',
          visualType: 'diagram',
          prompt: 'desenhe um circuito esquematico',
        ),
        (
          lessonKey: 'syntax-tree-lesson',
          topic: 'arvore sintatica com sujeito e predicado',
          visualType: 'diagram',
          prompt: 'mostrar analise sintatica em uma arvore',
        ),
        (
          lessonKey: 'food-chain-lesson',
          topic: 'cadeia alimentar com produtor consumidor e decompositor',
          visualType: 'diagram',
          prompt: 'mostrar fluxo de energia sem foto realista',
        ),
      ];

      for (final sample in cases) {
        final client = FakeImageClient();
        final pipeline = LessonVisualPipeline(
          imageClient: client,
          visualRouterClient: const ThrowingVisualRouterClient(),
        );

        final result = await pipeline.resolveVisual(
          trigger: LessonVisualTrigger(
            needsImage: true,
            pedagogicalNeed: 'important',
            topic: sample.topic,
            visualType: sample.visualType,
            imagePrompt: sample.prompt,
          ),
          lessonKey: sample.lessonKey,
          allowPaidImages: true,
          acceptedOfferId: null,
        );

        expect(result.source, 'local_software', reason: sample.lessonKey);
        expect(
          result.displayUrl,
          startsWith('data:image/svg+xml;utf8,'),
          reason: sample.lessonKey,
        );
        expect(
          Uri.decodeFull(result.displayUrl!),
          contains('<svg'),
          reason: sample.lessonKey,
        );
        expect(client.calls, 0, reason: sample.lessonKey);
      }
    },
  );

  test(
    'N3 sends realistic ambiguous visual to paid path only when allowed',
    () async {
      final client = FakeImageClient();
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: const FakeVisualRouterClient(),
      );
      const trigger = LessonVisualTrigger(
        needsImage: true,
        pedagogicalNeed: 'important',
        topic: 'diagrama com foto realista de um processo historico',
        visualType: 'diagram',
        imagePrompt: 'foto realista com etapas visuais',
      );

      final blocked = await pipeline.resolveVisual(
        trigger: trigger,
        lessonKey: 'lesson',
        allowPaidImages: false,
      );
      expect(blocked.source, 'skip_no_paid');
      expect(client.calls, 0);

      final paid = await pipeline.resolveVisual(
        trigger: trigger,
        lessonKey: 'lesson',
        allowPaidImages: true,
        acceptedOfferId: 'offer-paid',
      );
      expect(paid.source, 'ai_blueprint');
      expect(client.calls, 1);
      expect(client.lastVisualTrigger?['needs_image'], isTrue);
      expect(client.lastVisualTrigger?['visual_type'], 'diagram');
      expect(client.lastLessonContext?['stableLang'], isNull);
      expect(client.lastLessonContext?['source'], 'sim_app_flutter');
    },
  );

  test('paid image offer accepts, declines and routes to credits', () async {
    final orchestrator = FakePaidOrchestrator();
    final credits = FakeCredits();
    final navigations = <String>[];
    final controller = LessonPaidImageOfferController(
      orchestrator: orchestrator,
      creditsGateway: credits,
      onNavigate: navigations.add,
    );

    controller.registerPaidOffer(
      'k',
      const LessonPaidImageOffer(
        offerId: 'offer-k',
        prompt: 'p',
        lessonKey: 'l',
        creditCost: 10,
        source: 'test',
      ),
    );
    await controller.acceptPaidImage();
    expect(orchestrator.accepted, 1);
    expect(controller.creditBalance, 14);
    controller.declinePaidImage();
    expect(orchestrator.declined, 1);
    controller.handleInsufficientCredits(kind: 'lesson');
    expect(controller.navigationTarget, '/creditos?returnTo=/cyber/aula');
    expect(navigations, ['/creditos?returnTo=/cyber/aula']);
  });

  test(
    'PaidImageService offers before paid fetch and consumes only after accept',
    () async {
      final stateService = StudentLearningStateService(
        seed: {'l1': StudentLearningState.empty(lessonLocalId: 'l1')},
      );
      var fetches = 0;
      final service = paid.PaidImageService(
        stateService: stateService,
        fetcher:
            ({
              required prompt,
              required lessonKey,
              required acceptedOfferId,
              required idempotencyKey,
            }) async {
              fetches += 1;
              expect(acceptedOfferId, startsWith('img_offer_'));
              expect(idempotencyKey, acceptedOfferId);
              return 'data:image/png;base64,AAAA';
            },
      );

      final offer = service.offer(
        lessonKey: 'lesson-key',
        lessonLocalId: 'l1',
        visualTrigger: const {
          'needs_image': true,
          'pedagogical_need': 'important',
          'render_strategy': 'ai',
          'image_prompt': 'foto realista de um coracao humano',
        },
      );

      expect(offer.status, paid.PaidImageOfferStatus.pending);
      expect(fetches, 0);
      expect(
        stateService.read('l1')!.events.map((event) => event.type),
        contains('PAID_IMAGE_OFFERED'),
      );

      final image = await service.consume(
        offerId: offer.offerId,
        lessonLocalId: 'l1',
      );
      expect(image, 'data:image/png;base64,AAAA');
      expect(fetches, 1);
      expect(offer.status, paid.PaidImageOfferStatus.consumed);
    },
  );

  test(
    'PaidImageService keeps stable offer/idempotency key and blocks double consume',
    () async {
      final stateService = StudentLearningStateService(
        seed: {'l1': StudentLearningState.empty(lessonLocalId: 'l1')},
      );
      var fetches = 0;
      String? seenAcceptedOfferId;
      String? seenIdempotencyKey;
      final service = paid.PaidImageService(
        stateService: stateService,
        fetcher:
            ({
              required prompt,
              required lessonKey,
              required acceptedOfferId,
              required idempotencyKey,
            }) async {
              fetches += 1;
              seenAcceptedOfferId = acceptedOfferId;
              seenIdempotencyKey = idempotencyKey;
              await Future<void>.delayed(const Duration(milliseconds: 1));
              return 'data:image/png;base64,AAAA';
            },
      );
      const trigger = {
        'needs_image': true,
        'pedagogical_need': 'important',
        'render_strategy': 'ai',
        'image_prompt': 'foto realista de um coração humano',
      };

      final first = service.offer(
        lessonKey: 'lesson-key',
        lessonLocalId: 'l1',
        visualTrigger: trigger,
      );
      final second = service.offer(
        lessonKey: 'lesson-key',
        lessonLocalId: 'l1',
        visualTrigger: trigger,
      );

      expect(second.offerId, first.offerId);
      expect(first.offerId, startsWith('img_offer_'));

      final results = await Future.wait([
        service.consume(offerId: first.offerId, lessonLocalId: 'l1'),
        service.consume(offerId: first.offerId, lessonLocalId: 'l1'),
      ]);

      expect(results.whereType<String>(), hasLength(1));
      expect(fetches, 1);
      expect(seenAcceptedOfferId, first.offerId);
      expect(seenIdempotencyKey, first.offerId);
    },
  );

  test('api contracts preserve limits and constants without secrets', () {
    final image = GenerateLessonImageRequest(
      prompt: 'p' * 5000,
      lessonKey: 'k' * 200,
      aspectRatio: 'bad',
    ).normalized();
    expect(image.prompt.length, 4000);
    expect(image.lessonKey.length, 160);
    expect(image.aspectRatio, '1:1');
    expect(lessonImageModelPath, 'google/nano-banana-pro');

    final audio = GenerateLessonAudioRequest(
      text: 'a' * 5000,
      lessonKey: 'l' * 200,
      lang: 'pt-BR',
    ).normalized();
    expect(audio.text.length, maxAudioInputChars);
    expect(audio.lessonKey.length, 180);
    expect(voiceByLang('es'), 'Fenrir');
    expect(voiceByLang('pt-BR'), 'Charon');
    expect(voiceByLang('en-US'), 'Charon');
    expect(audio.voice, 'Charon');
    expect(geminiTtsModel, 'gemini-2.5-flash-preview-tts');
  });

  test('CompleteLesson.copyWith can clear stale image explicitly', () {
    const lesson = CompleteLesson(
      conteudo: LessonContent(
        explanation: 'Explicacao',
        question: 'Pergunta?',
        options: {
          AnswerLetter.A: 'A',
          AnswerLetter.B: 'B',
          AnswerLetter.C: 'C',
        },
        correctAnswer: AnswerLetter.A,
      ),
      imagem: 'data:image/png;base64,AAAA',
      audioText: 'Explicacao. Pergunta?',
    );

    final cleared = lesson.copyWith(imagem: null);

    expect(cleared.imagem, isNull);
    expect(cleared.conteudo.question, 'Pergunta?');
  });

  test(
    'SVG sanitizer accepts valid SVG without viewBox and keeps security blocks',
    () {
      expect(
        sanitizeAndEncodeSvg('<svg><rect width="10"/></svg>'),
        startsWith('data:image/svg+xml;utf8,'),
      );
      expect(
        sanitizeAndEncodeSvg(
          '<svg viewBox="0 0 10 10"><rect width="10"/></svg>',
        ),
        startsWith('data:image/svg+xml;utf8,'),
      );
      expect(
        sanitizeAndEncodeSvg(
          '<svg viewBox="0 0 10 10"><script>alert(1)</script></svg>',
        ),
        isNull,
      );
    },
  );
}
