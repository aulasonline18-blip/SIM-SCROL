import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/media/audio_core.dart';
import 'package:sim_mobile/sim/media/audio_preference.dart';
import 'package:sim_mobile/sim/media/lesson_image_api_contract.dart';
import 'package:sim_mobile/sim/media/slot_media_contract.dart';
import 'package:sim_mobile/sim/media/student_lesson_media_service.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

import 'support/memory_test_stores.dart';

void main() {
  test('M10 aceita imagem e audio somente quando pertencem ao slot', () {
    final imageSlot = SlotMediaContract(
      lessonLocalId: 'lesson-m10',
      marker: 'M1',
      itemIdx: 0,
      layer: LessonLayer.l1,
      mediaType: SlotMediaType.image,
      status: 'ready',
      source: 'server_visual_route',
      createdAt: '2026-07-08T00:00:00.000Z',
      cacheKey: slotMediaCacheKey(
        lessonLocalId: 'lesson-m10',
        marker: 'M1',
        itemIdx: 0,
        layer: LessonLayer.l1,
        mediaType: SlotMediaType.image,
      ),
    );
    final audioSlot = SlotMediaContract.fromJson({
      ...imageSlot.toJson(),
      'mediaType': 'audio',
      'cacheKey': 'slot-media:lesson-m10:M1:I0:L1:audio',
    });

    expect(imageSlot.isReady, isTrue);
    expect(audioSlot.mediaType, SlotMediaType.audio);
    expect(
      imageSlot.matchesSlot(
        lessonLocalId: 'lesson-m10',
        marker: 'M1',
        itemIdx: 0,
        layer: LessonLayer.l1,
        mediaType: SlotMediaType.image,
      ),
      isTrue,
    );
    expect(
      imageSlot.matchesSlot(
        lessonLocalId: 'lesson-m10',
        marker: 'M1',
        itemIdx: 0,
        layer: LessonLayer.l2,
        mediaType: SlotMediaType.image,
      ),
      isFalse,
    );
  });

  test('M10 rejeita midia sem marker layer ou tipo valido', () {
    expect(
      () => SlotMediaContract.fromJson({
        'lessonLocalId': 'lesson-m10',
        'itemIdx': 0,
        'layer': 1,
        'mediaType': 'image',
        'status': 'ready',
        'source': 'server_visual_route',
        'createdAt': '2026-07-08T00:00:00.000Z',
        'cacheKey': 'slot-media:lesson-m10:M1:I0:L1:image',
      }),
      throwsFormatException,
    );
    expect(
      () => SlotMediaContract.fromJson({
        'lessonLocalId': 'lesson-m10',
        'marker': 'M1',
        'itemIdx': 0,
        'layer': 4,
        'mediaType': 'image',
        'status': 'ready',
        'source': 'server_visual_route',
        'createdAt': '2026-07-08T00:00:00.000Z',
        'cacheKey': 'slot-media:lesson-m10:M1:I0:L4:image',
      }),
      throwsFormatException,
    );
    expect(
      () => SlotMediaContract.fromJson({
        'lessonLocalId': 'lesson-m10',
        'marker': 'M1',
        'itemIdx': 0,
        'layer': 1,
        'mediaType': 'video',
        'status': 'ready',
        'source': 'server_visual_route',
        'createdAt': '2026-07-08T00:00:00.000Z',
        'cacheKey': 'slot-media:lesson-m10:M1:I0:L1:video',
      }),
      throwsFormatException,
    );
  });

  test('M10 imagem salva metadata do slot sem virar fonte de progresso', () {
    final metadata =
        const LessonImageGenerationMetadata(
          source: 'server_visual',
          provider: 'sim-api',
        ).withSlot(
          lessonLocalId: 'lesson-m10',
          marker: 'M1',
          itemIdx: 0,
          layer: 1,
          cacheKey: 'lesson-key-m10',
          createdAt: '2026-07-08T00:00:00.000Z',
        );
    final restored = LessonImageGenerationMetadata.fromJson(metadata.toJson());
    final json = metadata.toJson();

    expect(json['cacheKey'], isNull);
    expect(json['cacheKeyHash'], isA<String>());
    expect(json['provider'], isNull);
    expect(json['model'], isNull);
    expect(restored?.lessonLocalId, 'lesson-m10');
    expect(restored?.marker, 'M1');
    expect(restored?.itemIdx, 0);
    expect(restored?.layer, 1);
    expect(restored?.mediaType, 'image');
    expect(restored?.status, 'ready');
  });

  test('M10 audio registra slot e nao altera item camada ou progresso', () {
    var state = StudentLearningState.empty(lessonLocalId: 'lesson-m10', now: 1)
        .copyWith(
          current: const LessonCurrent(
            itemIdx: 0,
            marker: 'M1',
            layer: LessonLayer.l1,
            amparoLvl: 0,
          ),
          progress: const LessonProgress(
            itemIdx: 0,
            layer: LessonLayer.l1,
            erros: 0,
            amparoLvl: 0,
            historia: ['resposta A'],
            mainAdvances: 0,
            concluidos: [],
            pendentesMarkers: [],
            totalItems: 3,
            pctAvanco: 0,
          ),
        );
    final service = StudentLessonMediaService(
      audioCore: AudioCore(
        preference: AudioPreference(storage: MemoryAudioPreferenceStorage()),
        playback: NoopAudioPlaybackAdapter(),
      ),
      readState: (_) => state,
      writeState: (next) => state = next,
    );

    service.markLessonAudioReady(
      const LessonMediaPosition(
        lessonLocalId: 'lesson-m10',
        itemMarker: 'M1',
        itemIdx: 0,
        layer: LessonLayer.l1,
      ),
      lessonKey: 'lesson-key-m10',
      language: 'pt-BR',
      voice: 'Charon',
    );

    expect(state.current?.marker, 'M1');
    expect(state.current?.layer, LessonLayer.l1);
    expect(state.progress?.historia, ['resposta A']);
    expect(state.audio.status, 'ready');
    final event = state.events.last;
    expect(event.type, 'AUDIO_READY');
    final slot = SlotMediaContract.fromJson(event.payload['slotMedia']);
    expect(slot.mediaType, SlotMediaType.audio);
    expect(
      slot.matchesSlot(
        lessonLocalId: 'lesson-m10',
        marker: 'M1',
        itemIdx: 0,
        layer: LessonLayer.l1,
        mediaType: SlotMediaType.audio,
      ),
      isTrue,
    );
  });

  test('M10 erro humano de midia nao expoe HTTP JSON stack ou Exception', () {
    for (final message in [
      mediaHumanError(SlotMediaType.image),
      mediaHumanError(SlotMediaType.audio),
    ]) {
      expect(message, isNot(contains('HTTP')));
      expect(message, isNot(contains('JSON')));
      expect(message, isNot(contains('stack')));
      expect(message, isNot(contains('Exception')));
      expect(message, contains('Não foi possível carregar'));
    }
  });
}
