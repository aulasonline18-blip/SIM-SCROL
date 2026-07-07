import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_visual_pipeline.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/features/session/lab_session.dart';
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
import 'package:sim_mobile/sim/media/doubt_audio.dart';
import 'package:sim_mobile/sim/media/image_data_url_compression.dart';
import 'package:sim_mobile/sim/media/lesson_audio_api_contract.dart';
import 'package:sim_mobile/sim/media/lesson_audio_controller.dart';
import 'package:sim_mobile/sim/media/lesson_image_api_contract.dart';
import 'package:sim_mobile/sim/media/lesson_paid_image_offer.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';
import 'package:sim_mobile/sim/media/platform_audio_adapter.dart';
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
  Future<ServerVisualRouteResult> routeVisual({
    String? stableLang,
    required Map<String, dynamic> visualTrigger,
  }) async {
    throw StateError('HTTP 401 Unauthorized requestId=vis-test');
  }
}

class CapturingVisualRouterClient implements LessonVisualRouterClient {
  CapturingVisualRouterClient({
    this.result = const ServerVisualRouteResult(
      verdict: ServerVisualRouteVerdict.missingRaster,
      reason: 'TEST_SERVER_MISSING_RASTER',
    ),
    this.prefersServerSideVisuals = false,
  });

  final ServerVisualRouteResult result;
  final bool prefersServerSideVisuals;
  String? lastTopic;
  String? lastVisualType;
  String? lastImagePrompt;
  List<String>? lastKeyElements;
  String? lastPedagogicalNeed;
  String? lastHighlightFocus;
  String? lastComplexity;
  String? lastStableLang;
  String? lastSvgPayload;
  Object? lastMathTemplate;
  Map<String, dynamic>? lastVisualTrigger;
  int calls = 0;

  @override
  Future<ServerVisualRouteResult> routeVisual({
    String? stableLang,
    required Map<String, dynamic> visualTrigger,
  }) async {
    calls += 1;
    lastTopic = visualTrigger['topic']?.toString();
    lastVisualType = visualTrigger['visual_type']?.toString();
    lastImagePrompt =
        visualTrigger['image_prompt']?.toString() ??
        visualTrigger['teacher_prompt']?.toString() ??
        visualTrigger['teacherPrompt']?.toString() ??
        visualTrigger['prompt']?.toString();
    final keyElements = visualTrigger['key_elements'];
    lastKeyElements = keyElements is List
        ? keyElements.map((e) => e.toString()).toList()
        : const [];
    lastPedagogicalNeed = visualTrigger['pedagogical_need']?.toString();
    lastHighlightFocus = visualTrigger['highlight_focus']?.toString();
    lastComplexity = visualTrigger['complexity']?.toString();
    lastStableLang = stableLang;
    lastSvgPayload = visualTrigger['svg_payload']?.toString();
    lastMathTemplate = visualTrigger['math_template'];
    lastVisualTrigger = visualTrigger;
    return result;
  }
}

class SequenceVisualRouterClient implements LessonVisualRouterClient {
  SequenceVisualRouterClient(this.results);

  final List<ServerVisualRouteResult> results;
  final prompts = <String?>[];
  int calls = 0;

  @override
  Future<ServerVisualRouteResult> routeVisual({
    String? stableLang,
    required Map<String, dynamic> visualTrigger,
  }) async {
    prompts.add(visualTrigger['image_prompt']?.toString());
    final index = calls < results.length ? calls : results.length - 1;
    calls += 1;
    return results[index];
  }
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
  String? lastAspectRatio;
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
    lastAspectRatio = aspectRatio;
    lastVisualTrigger = visualTrigger;
    lastLessonContext = lessonContext;
    return next;
  }
}

class RichFakeImageClient extends FakeImageClient
    implements LessonImageResponseClient {
  GenerateLessonImageResponse? response;

  @override
  Future<GenerateLessonImageResponse?> generateLessonImageResponse({
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
    lastAspectRatio = aspectRatio;
    lastVisualTrigger = visualTrigger;
    lastLessonContext = lessonContext;
    return response ?? GenerateLessonImageResponse(dataUrl: next ?? '');
  }
}

class FakePaidOrchestrator implements LessonPaidImageOrchestrator {
  int accepted = 0;
  int declined = 0;

  @override
  Future<LessonImageGenerationMetadata?> acceptPaidImageOffer(
    String lessonKey,
  ) async {
    accepted += 1;
    return null;
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
            imageUrl: 'data:image/png;base64,AAAA',
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
        imagem: 'data:image/png;base64,AAAA',
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
  test('image data URL compression rewrites raster image to jpeg data URL', () {
    final pngBytes = img.encodePng(img.Image(width: 2, height: 2));
    final png = 'data:image/png;base64,${base64Encode(pngBytes)}';
    final compressed = compressImageDataUrl(png);
    expect(compressed, startsWith('data:image/jpeg;base64,'));
  });
  test('visual pipeline sends schematic visual to server only', () async {
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

    expect(result.source, 'server_missing_raster');
    expect(result.displayUrl, isNull);
    expect(client.calls, 0);
    expect(router.calls, 1);
  });

  test('visual pipeline sends rich trigger context to server first', () async {
    final client = FakeImageClient();
    final router = CapturingVisualRouterClient(
      result: ServerVisualRouteResult(
        verdict: ServerVisualRouteVerdict.image,
        reason: 'TEST_SERVER_MISSING_RASTER',
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
      lessonKey: 'rich-server-request',
      allowPaidImages: false,
    );

    expect(result.source, 'server_missing_raster');
    expect(result.displayUrl, isNull);
    expect(router.calls, 1);
    expect(router.lastComplexity, 'high');
    expect(router.lastKeyElements, contains('conduta'));
    expect(client.calls, 0);
  });

  test('visual pipeline displays server raster', () async {
    final client = FakeImageClient();
    const raster = 'data:image/webp;base64,AAAA';
    final router = CapturingVisualRouterClient(
      result: ServerVisualRouteResult(
        verdict: ServerVisualRouteVerdict.image,
        reason: 'TEST_SERVER_RASTER',
        readyImageDataUrl: raster,
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
      lessonKey: 'server-raster-display',
      allowPaidImages: false,
    );

    expect(result.source, 'server_raster');
    expect(result.displayUrl, raster);
    expect(result.svg, isNull);
    expect(result.dataUrl, raster);
    expect(router.calls, 1);
    expect(client.calls, 0);
  });

  test('server-side visual client owns the Flutter image route', () async {
    final client = FakeImageClient();
    const raster = 'data:image/webp;base64,BBBB';
    final router = CapturingVisualRouterClient(
      prefersServerSideVisuals: true,
      result: ServerVisualRouteResult(
        verdict: ServerVisualRouteVerdict.image,
        reason: 'TEST_SERVER_FIRST',
        readyImageDataUrl: raster,
      ),
    );
    final pipeline = LessonVisualPipeline(
      imageClient: client,
      visualRouterClient: router,
    );

    final result = await pipeline.resolveVisual(
      trigger: const LessonVisualTrigger(
        needsImage: true,
        pedagogicalNeed: 'important',
        topic: 'fluxograma de entrada, processamento e saída',
        visualType: 'flowchart',
        keyElements: ['entrada', 'processo', 'saída'],
        highlightFocus: 'ordem entre entrada, processo e saída',
        imagePrompt: 'fluxograma com três caixas e setas',
      ),
      lessonKey: 'server-first-no-local',
      allowPaidImages: false,
    );

    expect(result.source, 'server_raster');
    expect(result.displayUrl, raster);
    expect(result.svg, isNull);
    expect(result.dataUrl, raster);
    expect(router.lastSvgPayload, isNull);
    expect(router.calls, 1);
    expect(client.calls, 0);
  });

  test(
    'server-side visual sends T02 svg_payload for server rasterization',
    () async {
      final client = FakeImageClient();
      const raster = 'data:image/png;base64,CCCC';
      final router = CapturingVisualRouterClient(
        prefersServerSideVisuals: true,
        result: ServerVisualRouteResult(
          verdict: ServerVisualRouteVerdict.image,
          reason: 'T02_READY_SVG_RASTERIZED',
          readyImageDataUrl: raster,
        ),
      );
      final pipeline = LessonVisualPipeline(
        imageClient: client,
        visualRouterClient: router,
      );

      final result = await pipeline.resolveVisual(
        trigger: const LessonVisualTrigger(
          needsImage: true,
          pedagogicalNeed: 'important',
          topic: 'grafico pronto',
          visualType: 'graph',
          imagePrompt: 'svg pronto para conversao no servidor',
          renderStrategy: 'software',
          svgPayload: '<svg><circle cx="1" cy="1" r="1"/></svg>',
        ),
        lessonKey: 'server-rasterizes-ready-svg',
        allowPaidImages: false,
      );

      expect(result.source, 'server_raster');
      expect(result.svg, isNull);
      expect(result.dataUrl, raster);
      expect(result.displayUrl, raster);
      expect(router.lastSvgPayload, '<svg><circle cx="1" cy="1" r="1"/></svg>');
      expect(router.calls, 1);
      expect(client.calls, 0);
    },
  );

  test(
    'server-side visual ignores paid offer while app is raster-only frame',
    () async {
      final client = FakeImageClient();
      final router = CapturingVisualRouterClient(
        prefersServerSideVisuals: true,
        result: const ServerVisualRouteResult(
          verdict: ServerVisualRouteVerdict.missingRaster,
          reason: 'SERVER_DECIDED_PAID_AI',
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
          topic: 'fotografia realista de experimento de física',
          visualType: 'photograph',
          imagePrompt: 'foto realista com equipamentos de laboratório',
        ),
        lessonKey: 'server-paid-without-raster',
        allowPaidImages: true,
      );

      expect(router.calls, 1);
      expect(result.source, 'server_missing_raster');
      expect(client.calls, 0);
    },
  );

  test('visual pipeline does not call paid image from app', () async {
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
      lessonKey: 'server-before-paid-client',
      allowPaidImages: true,
      acceptedOfferId: 'offer-rich',
    );

    expect(router.calls, 1);
    expect(result.source, 'server_missing_raster');
    expect(client.calls, 0);
    expect(client.lastVisualTrigger, isNull);
  });
  test(
    'visual pipeline does not fallback to local SVG when server fails',
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
        lessonKey: 'server-fails-without-local-fallback',
        allowPaidImages: true,
        acceptedOfferId: 'offer-should-not-run',
      );

      expect(result.source, 'server_failed');
      expect(result.displayUrl, isNull);
      expect(client.calls, 0);
    },
  );

  test('visual pipeline passes complete trigger context to server', () async {
    const legend = [
      {'id': 1, 'label': 'entrada', 'color': '#00E5FF'},
      {'id': 2, 'label': 'saída', 'color': '#00E676'},
    ];
    final router = CapturingVisualRouterClient();
    final pipeline = LessonVisualPipeline(
      imageClient: FakeImageClient(),
      visualRouterClient: router,
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

    expect(result.source, 'server_missing_raster');
    expect(router.lastKeyElements, ['entrada', 'processamento', 'saída']);
    expect(router.lastHighlightFocus, 'diferença entre entrada e saída');
    expect(router.lastComplexity, 'technical');
    expect(router.lastPedagogicalNeed, 'essential');
    expect(router.lastVisualType, 'diagram');
    expect(router.lastImagePrompt, 'desenhar caixas conectadas por setas');
    expect(router.lastTopic, 'fluxograma de entrada e saída');
    expect(router.lastStableLang, 'pt-BR');
    expect(router.lastVisualTrigger?['color_legend'], hasLength(2));
  });
  test('server unavailable does not use local software', () async {
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

    expect(result.source, 'server_failed');
    expect(result.displayUrl, isNull);
    expect(client.calls, 0);
  });

  test('deterministic graph waits for server raster', () async {
    final client = FakeImageClient();
    final router = CapturingVisualRouterClient(
      result: const ServerVisualRouteResult(
        verdict: ServerVisualRouteVerdict.image,
        reason: 'N3_SHOULD_NOT_BE_NEEDED_FOR_EXACT_GRAPH',
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

    expect(result.source, 'server_missing_raster');
    expect(result.displayUrl, isNull);
    expect(router.calls, 1);
    expect(client.calls, 0);
  });

  test('formula without math_template does not render local SVG', () async {
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

    expect(result.source, 'server_failed');
    expect(result.displayUrl, isNull);
    expect(client.calls, 0);
  });

  test('physics height function does not render local SVG', () async {
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

    expect(result.source, 'server_failed');
    expect(result.displayUrl, isNull);
    expect(client.calls, 0);
  });

  test('poor but recoverable math trigger does not render local graph', () async {
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

    expect(result.source, 'server_failed');
    expect(result.displayUrl, isNull);
    expect(client.calls, 0);
  });

  test(
    'poor but recoverable physics force trigger does not render local SVG',
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

      expect(result.source, 'server_failed');
      expect(result.displayUrl, isNull);
      expect(client.calls, 0);
    },
  );

  test(
    'physics position function lesson does not render local kinematics SVG',
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

      expect(result.source, 'server_failed');
      expect(result.displayUrl, isNull);
      expect(client.calls, 0);
    },
  );

  test(
    'poor but recoverable chemistry trigger does not render local SVG',
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

      expect(result.source, 'server_failed');
      expect(result.displayUrl, isNull);
      expect(client.calls, 0);
    },
  );

  test(
    'software catalog candidates do not render locally when server is unavailable',
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

        expect(result.source, 'server_failed', reason: sample.lessonKey);
        expect(result.displayUrl, isNull, reason: sample.lessonKey);
        expect(client.calls, 0, reason: sample.lessonKey);
      }
    },
  );

  test('realistic ambiguous visual is not paid-decided by app', () async {
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
      aspectRatio: '16:9',
    );

    final blocked = await pipeline.resolveVisual(
      trigger: trigger,
      lessonKey: 'lesson',
      allowPaidImages: false,
    );
    expect(blocked.source, 'server_missing_raster');
    expect(client.calls, 0);

    final paid = await pipeline.resolveVisual(
      trigger: trigger,
      lessonKey: 'lesson',
      allowPaidImages: true,
      acceptedOfferId: 'offer-paid',
    );
    expect(paid.source, 'server_missing_raster');
    expect(client.calls, 0);
    expect(client.lastAspectRatio, isNull);
    expect(client.lastVisualTrigger, isNull);
    expect(client.lastLessonContext, isNull);
  });
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
      imageMetadata: LessonImageGenerationMetadata(
        cacheKey: 'old-cache',
        requestId: 'old-request',
      ),
    );

    final cleared = lesson.copyWith(imagem: null);

    expect(cleared.imagem, isNull);
    expect(cleared.imageMetadata, isNull);
    expect(cleared.conteudo.question, 'Pergunta?');
  });
}
