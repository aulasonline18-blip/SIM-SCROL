import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_addendums.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/doubt_input_sheet.dart';
import 'package:sim_mobile/sim/auxiliary/doubt_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/lesson_doubt_controller.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_rooms.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('Funcao Duvida constitucional', () {
    test('adendo de duvida e literal e igual ao arquivo oficial', () {
      final reference = File(
        '/root/SIM-REFERENCIA/prompts/adendo_doubt.txt',
      ).readAsStringSync().replaceFirst('\uFEFF', '').trimRight();

      expect(doubtRoomAddendum.trimRight(), reference);
      expect(getAuxRoomAddon(AuxRoomMode.doubt), doubtRoomAddendum);
      expect(
        getAuxRoomAddon(AuxRoomMode.doubt),
        isNot('ADENDO_DOUBT_SERVER_SIDE'),
      );
    });

    test(
      'chama T02 real com mode doubt, adendo, ficha e contexto completo',
      () async {
        final client = _RecordingT02();
        final caller = DoubtT02Caller(client: client);
        const image = DoubtImagePayload(
          name: 'foto.png',
          type: 'image/png',
          size: 32,
          dataUrl: 'data:image/png;base64,AAAA',
        );

        final response = await caller.call(
          lessonLocalId: 'L1',
          profile: const AuxRoomProfile(
            stableLang: 'pt-BR',
            academicLevel: 'medio',
            preferredName: 'Ana',
            notes: 'aprende melhor com exemplos',
            extra: {'student_profile_internal': 'perfil real'},
          ),
          itemText: 'Frações equivalentes',
          currentContent: 'Explicacao atual',
          currentQuestion: 'Qual fracao e equivalente a 1/2?',
          currentOptions: const {
            AnswerLetter.A: '2/4',
            AnswerLetter.B: '3/4',
            AnswerLetter.C: '4/4',
          },
          layer: LessonLayer.l2,
          itemIdx: 3,
          marker: 'M4',
          studentDoubt: 'Nao entendi por que 2/4 vale 1/2.',
          doubtImage: image,
        );

        final request = client.doubtRequests.single;
        final profile = request.profile;
        expect(request.mode, 'doubt');
        expect(request.addendum, doubtRoomAddendum);
        expect(request.marker, 'M4');
        expect(request.itemIdx, 3);
        expect(request.layer, LessonLayer.l2);
        expect(profile['aux_mode'], 'doubt');
        expect(profile['student_profile_internal'], 'perfil real');
        expect(profile['preferredName'], 'Ana');
        expect(profile['current_explanation'], 'Explicacao atual');
        expect(profile['current_question'], 'Qual fracao e equivalente a 1/2?');
        expect((profile['current_options'] as Map)['A'], '2/4');
        expect(
          (profile['current_content'] as Map)['question'],
          contains('fracao'),
        );
        expect(profile['student_doubt'], contains('2/4'));
        expect(
          (profile['doubt_image'] as Map)['dataUrl'],
          startsWith('data:image/'),
        );
        expect(response.explanation, 'Explicacao cirurgica da duvida.');
        expect(response.visualTrigger['needs_image'], isFalse);
        expect(response.visualTrigger['render_strategy'], 'software');
      },
    );

    test('entrada vazia, arquivo invalido e imagem grande sao rejeitados', () {
      expect(const DoubtInputDraft().validate(), emptyDoubtMessage);
      expect(
        const DoubtInputDraft(
          image: DoubtImagePayload(
            name: 'audio.mp3',
            type: 'audio/mpeg',
            size: 20,
            dataUrl: 'data:audio/mpeg;base64,AAAA',
          ),
        ).validate(),
        imageOnlyMessage,
      );
      expect(
        DoubtInputDraft(
          image: DoubtImagePayload(
            name: 'foto.png',
            type: 'image/png',
            size: doubtImageMaxDataUrlLength + 1,
            dataUrl:
                'data:image/png;base64,${'A' * doubtImageMaxDataUrlLength}',
          ),
        ).validate(),
        imageTooLargeMessage,
      );
    });

    test('resposta reduzida nao exige pergunta, opcoes ou correta', () async {
      final caller = DoubtT02Caller(client: _RecordingT02());

      final response = await caller.call(
        lessonLocalId: 'L1',
        profile: const AuxRoomProfile(stableLang: 'pt-BR'),
        itemText: 'Item',
        currentContent: 'Explicacao',
        layer: LessonLayer.l1,
        itemIdx: 0,
        studentDoubt: 'Minha duvida',
      );

      expect(response.explanation, isNotEmpty);
      expect(response.visualTrigger, containsPair('needs_image', false));
    });

    test(
      'eventos auxiliares nao alteram current, progress, attempts ou mastery',
      () {
        final before = _state();
        final after = recordDoubtAuxiliaryEvent(
          before,
          type: 'DOUBT_ANSWER_READY',
          payload: _payload(),
        );
        final event = after.events.single;
        final history =
            (((ensureAuxRooms(after)['doubt'] as Map)['history'] as List)
                .cast<Map>());

        expect(after.current, before.current);
        expect(after.progress, before.progress);
        expect(after.attempts, before.attempts);
        expect(after.truth.toJson(), before.truth.toJson());
        expect(event.payload['authoritative'], isFalse);
        expect(event.payload['writesProgress'], isFalse);
        expect(event.payload['writesTruth'], isFalse);
        expect(event.payload['writesMastery'], isFalse);
        expect(event.payload['requiresServerDecision'], isFalse);
        expect(event.payload['decisionSource'], 'sim_app_local_aux_evidence');
        expect(event.payload['auxiliary'], isTrue);
        expect(history.single['eventType'], 'DOUBT_ANSWER_READY');
        expect(history.single['nextAction'], 'return_to_lesson');
      },
    );

    test('envio duplicado em processamento e ignorado', () async {
      final client = _DelayedT02();
      final controller = LessonDoubtController(
        caller: DoubtT02Caller(client: client),
      );

      final first = controller.submitDoubt(
        lessonLocalId: 'L1',
        profile: const AuxRoomProfile(stableLang: 'pt-BR'),
        itemText: 'Item',
        currentContent: 'Explicacao',
        layer: LessonLayer.l1,
        itemIdx: 0,
        input: const DoubtInputDraft(text: 'Primeira duvida'),
      );
      await Future<void>.delayed(Duration.zero);
      await controller.submitDoubt(
        lessonLocalId: 'L1',
        profile: const AuxRoomProfile(stableLang: 'pt-BR'),
        itemText: 'Item',
        currentContent: 'Explicacao',
        layer: LessonLayer.l1,
        itemIdx: 0,
        input: const DoubtInputDraft(text: 'Segunda duvida'),
      );
      client.complete();
      await first;

      expect(client.calls, 1);
      expect(controller.state.status, DoubtStatus.explaining);
    });

    test('resposta atrasada de item antigo nao aparece no item novo', () async {
      final client = _DelayedT02();
      var currentKey = 'L1|M1|0|1';
      final controller = LessonDoubtController(
        caller: DoubtT02Caller(client: client),
      );
      var staleIgnored = false;

      final pending = controller.submitDoubt(
        lessonLocalId: 'L1',
        profile: const AuxRoomProfile(stableLang: 'pt-BR'),
        itemText: 'Item',
        currentContent: 'Explicacao',
        layer: LessonLayer.l1,
        itemIdx: 0,
        marker: 'M1',
        input: const DoubtInputDraft(text: 'Duvida'),
        isScopeStillCurrent: (scope) => scope.key == currentKey,
        onStaleIgnored: (_) => staleIgnored = true,
      );
      await Future<void>.delayed(Duration.zero);
      currentKey = 'L1|M2|1|1';
      client.complete();
      await pending;

      expect(controller.state.status, DoubtStatus.processing);
      expect(controller.state.response, isNull);
      expect(staleIgnored, isTrue);
    });

    test('falha T02 nao cria resposta fake', () async {
      final controller = LessonDoubtController(
        caller: DoubtT02Caller(client: _FailingT02()),
      );

      await controller.submitDoubt(
        lessonLocalId: 'L1',
        profile: const AuxRoomProfile(stableLang: 'pt-BR'),
        itemText: 'Item',
        currentContent: 'Explicacao',
        layer: LessonLayer.l1,
        itemIdx: 0,
        input: const DoubtInputDraft(text: 'Duvida'),
      );

      expect(controller.state.status, DoubtStatus.error);
      expect(controller.state.response, isNull);
      expect(controller.state.error, defaultDoubtError);
    });

    test('runtime nao usa rota legada e UI nao chama T02 diretamente', () {
      final runtime = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      final ui = Directory('lib/features/classroom')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(runtime, isNot(contains('/api/doubt')));
      expect(ui, isNot(contains('T02LessonClient')));
      expect(ui, isNot(contains('DoubtT02Caller(')));
      expect(ui, isNot(contains('.doubt(')));
    });
  });
}

JsonMap _payload() => {
  'lessonLocalId': 'L1',
  'marker': 'M1',
  'itemIdx': 0,
  'layer': 1,
  'hasText': true,
  'hasImage': false,
  'imageType': null,
  'imageSize': null,
  'requestId': 'req-1',
  'idempotencyKey': 'req-1',
};

StudentLearningState _state() =>
    StudentLearningState.empty(lessonLocalId: 'L1').copyWith(
      current: const LessonCurrent(
        marker: 'M1',
        itemIdx: 0,
        layer: LessonLayer.l1,
        amparoLvl: 0,
      ),
      progress: const LessonProgress(
        itemIdx: 0,
        layer: LessonLayer.l1,
        erros: 0,
        amparoLvl: 0,
        historia: [],
        mainAdvances: 0,
        concluidos: [],
        pendentesMarkers: [],
        totalItems: 1,
        pctAvanco: 0,
      ),
    );

class _RecordingT02 implements T02LessonClient {
  final doubtRequests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) async {
    doubtRequests.add(request);
    return _material();
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) async =>
      _unsupported();

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async =>
      _unsupported();

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) async =>
      _unsupported();
}

class _DelayedT02 extends _RecordingT02 {
  final _completer = Completer<T02LessonMaterial>();
  int calls = 0;

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) {
    calls += 1;
    doubtRequests.add(request);
    return _completer.future;
  }

  void complete() => _completer.complete(_material());
}

class _FailingT02 extends _RecordingT02 {
  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) async {
    throw StateError('T02 offline');
  }
}

Never _unsupported() => throw UnsupportedError('Only doubt is expected.');

T02LessonMaterial _material() => T02LessonMaterial(
  explanation: 'Explicacao cirurgica da duvida.',
  question: '',
  options: const {AnswerLetter.A: '', AnswerLetter.B: '', AnswerLetter.C: ''},
  correctAnswer: AnswerLetter.A,
  whyCorrect: '',
  whyWrong: '',
  generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
  source: 'fake-t02',
  visualTrigger: const {
    'needs_image': false,
    'pedagogical_need': 'none',
    'render_strategy': 'software',
    'svg_payload': '',
    'topic': '',
    'visual_type': 'none',
    'key_elements': [],
    'color_legend': [],
    'highlight_focus': '',
    'complexity': 'simple',
    'image_prompt': '',
  },
);
