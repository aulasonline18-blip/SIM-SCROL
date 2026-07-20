import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/external_ai/sim_http_transport.dart';
import 'package:sim_mobile/sim/media/lesson_image_api_contract.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('Fase 2 seletor pedagogico de tipo visual', () {
    const selector = LessonVisualTypeSelector();

    test('conteudo de processo vira step_by_step ou diagram', () {
      final selection = selector.select(
        _candidate(
          explanation:
              'A fotossintese e um processo com etapas: luz, transformacao e producao de glicose.',
          question: 'Como ocorre essa sequencia dentro da planta?',
        ),
      );

      expect(
        selection.type,
        anyOf(
          LessonVisualSupportType.visualStepByStep,
          LessonVisualSupportType.diagram,
        ),
      );
      expect(selection.intention, isNotEmpty);
    });

    test('conteudo de comparacao vira comparison ou table', () {
      final selection = selector.select(
        _candidate(
          explanation:
              'Compare mitose e meiose, destacando diferencas e semelhancas.',
          question: 'Qual alternativa compara corretamente os dois processos?',
        ),
      );

      expect(
        selection.type,
        anyOf(
          LessonVisualSupportType.visualComparison,
          LessonVisualSupportType.table,
        ),
      );
      expect(selection.visualType, anyOf('comparison', 'table'));
    });

    test('conteudo numerico vira chart', () {
      final selection = selector.select(
        _candidate(
          explanation:
              'A tabela de dados mostra crescimento percentual, taxa media e tendencia de queda.',
          question: 'Qual grafico representa melhor esses valores?',
        ),
      );

      expect(selection.type, LessonVisualSupportType.chart);
      expect(selection.visualType, 'chart');
    });

    test('conteudo historico vira timeline', () {
      final selection = selector.select(
        _candidate(
          subject: 'Revolucao Francesa',
          explanation:
              'Ordene datas, antes e depois, em uma cronologia do periodo.',
          question: 'Qual evento aconteceu primeiro na linha do tempo?',
        ),
      );

      expect(selection.type, LessonVisualSupportType.timeline);
      expect(selection.visualType, 'timeline');
    });

    test('conteudo conceitual vira concept_map', () {
      final selection = selector.select(
        _candidate(
          explanation:
              'Relacione conceitos de causa, efeito, conexao e dependencia entre ideias.',
          question: 'Qual relacao entre os conceitos esta correta?',
        ),
      );

      expect(selection.type, LessonVisualSupportType.conceptMap);
      expect(selection.visualType, 'concept_map');
    });

    test('conteudo puramente abstrato sem ganho visual vira no_visual', () {
      final selection = selector.select(
        _candidate(
          explanation: 'Justica e uma ideia normativa discutida na filosofia.',
          question: 'Qual definicao abstrata de justica esta correta?',
        ),
      );

      expect(selection.type, LessonVisualSupportType.none);
      expect(selection.visualType, 'no_visual');
      expect(selection.intention, contains('sem visual'));
    });

    test('no_visual nao chama N3 mesmo com cliente disponivel', () {
      final pipeline = S12VisualPipeline(
        n3Client: VisualRouterN3Client(
          config: const SimAiServerConfig(baseUrl: 'https://sim.example'),
        ),
      );

      final result = pipeline.resolveLocal(
        const S12VisualRequest(
          trigger: LessonVisualTrigger(needsImage: true),
          lessonLocalId: 'l1',
          marker: 'M1',
          itemIdx: 0,
          layer: LessonLayer.l1,
          idioma: 'pt-BR',
          explanation: 'Justica e uma ideia normativa discutida na filosofia.',
          question: 'Qual definicao abstrata de justica esta correta?',
          options: ['Definicao A', 'Definicao B', 'Definicao C'],
        ),
      );

      expect(result.status, 'no_image');
      expect(result.shouldCallN3, isFalse);
      expect(result.n2Reason, 'visual_type_sem_ganho_visual_claro');
    });

    test('pipeline continua nao bloqueante quando visual segue para N3', () {
      final pipeline = S12VisualPipeline(
        n3Client: VisualRouterN3Client(
          config: const SimAiServerConfig(baseUrl: 'https://sim.example'),
        ),
      );

      final result = pipeline.resolveLocal(
        const S12VisualRequest(
          trigger: LessonVisualTrigger(needsImage: true),
          lessonLocalId: 'l1',
          marker: 'M1',
          itemIdx: 0,
          layer: LessonLayer.l1,
          idioma: 'pt-BR',
          explanation:
              'Os dados mostram crescimento percentual, taxa media e tendencia.',
          question: 'Qual grafico representa os valores?',
        ),
      );

      expect(result.status, 'processing');
      expect(result.shouldCallN3, isTrue);
      expect(result.requestId, startsWith('sim-n3-'));
    });

    test('seletor nao altera estado oficial do aluno', () {
      final source = File(
        'lib/sim/media/lesson_image_api_contract.dart',
      ).readAsStringSync();
      final start = source.indexOf('class LessonVisualTypeSelector');
      final end = source.indexOf('const lessonVisualTypeSelector');
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final selectorBlock = source.substring(start, end);

      for (final forbidden in const [
        'StudentStateStore',
        'LessonAnswerProgressController',
        'current',
        'progress',
        'attempts',
        'truth',
        'mastery',
        'advance',
      ]) {
        expect(selectorBlock, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('N3 protegido nao foi alterado', () {
      expect(simVisualRoutePath, '/api/visual-route');
    });

    test('Fase 5 envia identidade forte sem chave API no Flutter', () async {
      final transport = _CapturingTransport();
      final client = VisualRouterN3Client(
        config: const SimAiServerConfig(baseUrl: 'https://sim.example'),
        transport: transport,
      );

      final result = await client.route(
        const VisualRouterN3Request(
          visualTrigger: {
            'needs_image': true,
            'visual_type': 'diagram',
            'image_prompt': 'Diagrama simples de fotossintese.',
          },
          lessonLocalId: 'lesson-1',
          itemMarker: 'M1',
          itemIdx: 0,
          layer: LessonLayer.l1,
          requestId: 'sim-n3-test',
          idioma: 'pt-BR',
          contentHash: 'conteudo123',
          idempotencyKey: 'visual-idem-123',
          visualType: 'diagram',
          topic: 'Fotossintese',
          explanation: 'A planta transforma luz em energia.',
          question: 'O que entra no processo?',
          options: ['Luz', 'Som', 'Areia'],
        ),
      );

      expect(result.status, 'processing');
      expect(transport.body?['idempotencyKey'], 'visual-idem-123');
      expect(transport.body?['contentHash'], 'conteudo123');
      expect(transport.body?['aspectRatio'], '3:4');
      expect(transport.body?['visualType'], 'diagram');
      expect(transport.body.toString().toLowerCase(), isNot(contains('api')));
      expect(
        Directory('lib').listSync(recursive: true).whereType<File>().every((
          file,
        ) {
          if (!file.path.endsWith('.dart')) return true;
          final source = file.readAsStringSync();
          return !source.contains('GEMINI_API_KEY') &&
              !source.contains('OPENAI_API_KEY') &&
              !source.contains('AIza');
        }),
        isTrue,
      );
    });
  });
}

class _CapturingTransport implements SimHttpTransport {
  Map<String, dynamic>? body;

  @override
  Future<SimHttpResponse> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    this.body = Map<String, dynamic>.from(body! as Map);
    return const SimHttpResponse(
      statusCode: 200,
      body:
          '{"status":"processing","reason":"VISUAL_ROUTE_ALREADY_RUNNING","requestId":"sim-n3-test"}',
    );
  }

  @override
  Stream<String> postEventStream(
    Uri uri, {
    required Map<String, String> headers,
    required Object? body,
    Duration timeout = const Duration(seconds: 140),
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SimHttpResponse> postMultipart(
    Uri uri, {
    required Map<String, String> headers,
    required String fieldName,
    required String filename,
    required String contentType,
    required List<int> bytes,
    Duration timeout = const Duration(seconds: 60),
  }) {
    throw UnimplementedError();
  }
}

LessonVisualSupportCandidate _candidate({
  String? subject,
  String? explanation,
  String? question,
}) {
  return LessonVisualSupportCandidate(
    needsVisual: true,
    subject: subject,
    explanation: explanation,
    question: question,
  );
}
