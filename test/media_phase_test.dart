import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  test('production/session audio wiring keeps PlatformAudioAdapter live', () {
    final labSession = File(
      'lib/features/session/lab_session.dart',
    ).readAsStringSync();
    final organism = File(
      'lib/sim/organism/sim_organism.dart',
    ).readAsStringSync();

    expect(labSession, contains('PlatformAudioAdapter()'));
    expect(labSession, contains('_runningUnderFlutterTest'));
    expect(labSession, contains('NoopAudioPlaybackAdapter()'));
    expect(organism, contains('playback ?? PlatformAudioAdapter()'));
  });

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
    expect(core.available(), true);
  });

  test('audio core availability follows preference and adapter capability', () {
    final disabledPreference = AudioPreference()..setAudioEnabled(false);
    expect(
      AudioCore(
        preference: disabledPreference,
        playback: CountingPlaybackAdapter(),
      ).available(),
      false,
    );
    expect(
      AudioCore(
        preference: AudioPreference(),
        playback: NoopAudioPlaybackAdapter(),
      ).available(),
      false,
    );
    expect(
      AudioCore(
        preference: AudioPreference(),
        playback: NoopAudioPlaybackAdapter(),
        availabilityProbe: () => true,
      ).available(),
      true,
    );
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
      expect(states['l1']!.audio.error, startsWith('SIM_MEDIA_ERROR_'));
      expect(states['l1']!.audio.error, isNot(contains('audio_playback_unavailable')));
      expect(
        states['l1']!.events.map((event) => event.type),
        contains('AUDIO_FAILED'),
      );
      expect(
        states['l1']!.events.map((event) => event.type),
        isNot(contains('AUDIO_STARTED')),
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

  test(
    'LabSession keeps visual trigger passive until server image arrives',
    () {
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
          ),
          imagem: null,
          itemMarker: 'M1',
          itemText: 'Coracao humano',
        );

      expect(session.imageStatus, 'idle');
      expect(session.imageError, isNull);
    },
  );

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

  test('lesson image media events use safe hashes item and layer', () {
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
    expect(state.events[0].payload['cacheKey'], isNull);
    expect(state.events[0].payload['cacheKeyHash'], isA<String>());
    expect(state.events[0].payload['itemMarker'], 'M1');
    expect(state.events[0].payload['layer'], 2);
    expect(state.events[1].payload['imageUrlHead'], isNull);
    expect(state.events[1].payload['hasImageUrl'], true);
    expect(state.events[2].payload['errorMessage'], isNull);
    expect(state.events[2].payload['errorCode'], startsWith('SIM_MEDIA_ERROR_'));
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
  test('api contracts preserve limits and constants without secrets', () {
    expect(
      () => GenerateLessonAudioRequest(
        text: 'a' * 5000,
        lessonKey: 'lesson',
        lang: 'pt-BR',
      ).normalized(),
      throwsFormatException,
    );
    expect(
      () => GenerateLessonAudioRequest(
        text: 'audio',
        lessonKey: 'l' * 200,
        lang: 'pt-BR',
      ).normalized(),
      throwsFormatException,
    );
    final audio = GenerateLessonAudioRequest(
      text: 'audio curto',
      lessonKey: 'lesson',
      lang: 'pt-BR',
    ).normalized();
    expect(audio.text, 'audio curto');
    expect(audio.lessonKey, 'lesson');
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
