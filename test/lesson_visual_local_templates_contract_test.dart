import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
import 'package:sim_mobile/sim/external_ai/sim_ai_server_config.dart';
import 'package:sim_mobile/sim/media/lesson_image_api_contract.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

void main() {
  group('Fase 3 renderizadores locais de apoio visual', () {
    test('comparison simples gera template local', () {
      final result = _resolve(
        kind: 'comparison',
        explanation: 'Compare forma incorreta versus forma correta.',
        question: 'Qual forma deve ser usada?',
        options: const ['Forma incorreta', 'Forma correta'],
      );

      expect(result.status, 'ready');
      expect(result.n2Reason, 'comparacao_local_duas_colunas');
      expect(result.imageData, contains('<svg'));
      expect(result.shouldCallN3, isFalse);
    });

    test('table simples gera template local', () {
      final result = _resolve(
        kind: 'table',
        explanation: 'Organize os pares em uma tabela simples.',
        question: 'Qual linha resume melhor?',
        options: const ['Termo: energia', 'Exemplo: movimento', 'Uso: fisica'],
      );

      expect(result.status, 'ready');
      expect(result.n2Reason, 'tabela_local_simples');
      expect(result.imageData, contains('<svg'));
    });

    test('step_by_step simples gera template local', () {
      final result = _resolve(
        kind: 'step_by_step',
        explanation:
            'Primeiro identifique os dados. Depois aplique a formula. Por fim confira a unidade.',
        question: 'Qual e a sequencia correta?',
      );

      expect(result.status, 'ready');
      expect(result.n2Reason, 'sequencia_local_simples');
      expect(result.imageData, contains('<svg'));
    });

    test('concept_map simples gera template local', () {
      final result = _resolve(
        kind: 'concept_map',
        subject: 'Ecossistema',
        explanation: 'Relacione energia, seres vivos e ambiente.',
        question: 'Qual relacao entre os conceitos esta correta?',
        options: const ['Energia', 'Seres vivos', 'Ambiente'],
      );

      expect(result.status, 'ready');
      expect(result.n2Reason, 'mapa_conceitual_local_simples');
      expect(result.imageData, contains('<svg'));
    });

    test('diagram complexo nao forca template local e deixa seguir para N3', () {
      final result = _resolve(
        kind: 'diagram',
        explanation:
            'Anatomia detalhada de um orgao especifico com precisao anatomica.',
        question: 'Qual parte esta correta?',
        withN3: true,
      );

      expect(result.status, 'processing');
      expect(result.shouldCallN3, isTrue);
      expect(result.imageData, isNull);
    });

    test('no_visual nao chama template nem N3', () {
      final result = _resolve(
        explanation: 'Justica e uma ideia normativa discutida na filosofia.',
        question: 'Qual definicao abstrata de justica esta correta?',
        withN3: true,
      );

      expect(result.status, 'no_image');
      expect(result.n2Reason, 'visual_type_sem_ganho_visual_claro');
      expect(result.shouldCallN3, isFalse);
      expect(result.imageData, isNull);
    });

    test('template local nao altera estado oficial', () {
      final source = File(
        'lib/sim/media/lesson_image_api_contract.dart',
      ).readAsStringSync();
      final start = source.indexOf('class LessonVisualLocalTemplates');
      final end = source.indexOf('const lessonVisualLocalTemplates');
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final block = source.substring(start, end);

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
        expect(block, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('SVG local e seguro e nao contem recursos proibidos', () {
      final result = _resolve(
        kind: 'comparison',
        explanation: 'Antes versus depois.',
        question: 'Qual estado representa o depois?',
        options: const ['Antes', 'Depois'],
      );
      final svg = result.imageData!;

      for (final forbidden in const [
        '<script',
        'foreignObject',
        '<image',
        'WebView',
        'href=',
        'http://',
        'https://',
        'javascript:',
      ]) {
        expect(svg, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('template local carrega titulo descricao acessivel e 3:4', () {
      final selection = const LessonVisualTypeSelection(
        type: LessonVisualSupportType.visualComparison,
        intention: 'comparacao entre portugues e Kiribati',
        reason: 'test',
      );
      final local = const LessonVisualLocalTemplates().render(
        selection,
        const LessonVisualSupportCandidate(
          needsVisual: true,
          subject: 'Idiomas',
          explanation: 'Portugues versus Kiribati.',
          options: ['Portugues', 'Kiribati'],
        ),
      );

      expect(local.status, 'local_template');
      expect(local.title, isNotEmpty);
      expect(local.accessibilityDescription, contains('comparacao'));
      expect(local.svg, contains('viewBox="0 0 600 800"'));
      expect(600 / 800, lessonImageStudyAspectRatio);
    });

    test('falha de template local nao bloqueia aula', () {
      final result = _resolve(
        kind: 'comparison',
        explanation: 'Compare.',
        question: 'Qual?',
        withN3: true,
      );

      expect(result.status, 'processing');
      expect(result.shouldCallN3, isTrue);
    });
  });
}

S12VisualResult _resolve({
  String? kind,
  String? subject,
  String? explanation,
  String? question,
  List<String> options = const [],
  bool withN3 = false,
}) {
  final pipeline = S12VisualPipeline(
    n3Client: withN3
        ? VisualRouterN3Client(
            config: const SimAiServerConfig(baseUrl: 'https://sim.example'),
          )
        : null,
  );
  return pipeline.resolveLocal(
    S12VisualRequest(
      trigger: LessonVisualTrigger(
        needsImage: true,
        kind: kind,
        description: kind == null ? null : '$kind pedagogico',
      ),
      lessonLocalId: 'l1',
      marker: 'M1',
      itemIdx: 0,
      layer: LessonLayer.l1,
      idioma: 'pt-BR',
      subject: subject,
      explanation: explanation,
      question: question,
      options: options,
    ),
  );
}
