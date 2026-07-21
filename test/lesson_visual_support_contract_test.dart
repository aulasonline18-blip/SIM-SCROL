import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
import 'package:sim_mobile/sim/media/lesson_image_api_contract.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';

void main() {
  group('Apoio Visual Pedagogico Vivo contract', () {
    test('inventaria os tipos constitucionais de apoio visual', () {
      expect(
        LessonVisualSupportType.values.map((type) => type.wireName),
        containsAll(const [
          'pedagogical_image',
          'diagram',
          'chart',
          'table',
          'visual_step_by_step',
          'visual_comparison',
          'timeline',
          'concept_map',
          'future_micro_animation',
          'future_micro_simulation',
          'none',
        ]),
      );
    });

    test('visual decorativo e rejeitado antes de chegar ao N3', () {
      const trigger = LessonVisualTrigger(
        needsImage: true,
        kind: 'decorativo',
        description: 'Imagem bonita de fundo para enfeitar a aula.',
        reason: 'decoracao',
      );

      const authority = LessonVisualSupportAuthority();
      final decision = authority.evaluate(_candidateFrom(trigger));
      const router = VisualRouterN2();
      final route = router.classify(trigger);

      expect(decision.decorative, isTrue);
      expect(decision.useful, isFalse);
      expect(decision.accepted, isFalse);
      expect(decision.reason, 'apoio_visual_sem_funcao_pedagogica');
      expect(route.kind, VisualRouteN2Kind.noImage);
      expect(route.reason, 'apoio_visual_sem_funcao_pedagogica');
    });

    test('visual util, seguro, leve e acessivel e aceito', () {
      const trigger = LessonVisualTrigger(
        needsImage: true,
        kind: 'diagram',
        description:
            'Diagrama que mostra a relacao entre forca, massa e aceleracao.',
        reason: 'reduz carga cognitiva da explicacao',
      );

      const authority = LessonVisualSupportAuthority();
      final decision = authority.evaluate(_candidateFrom(trigger));

      expect(decision.needsVisual, isTrue);
      expect(decision.type, LessonVisualSupportType.diagram);
      expect(decision.useful, isTrue);
      expect(decision.safe, isTrue);
      expect(decision.light, isTrue);
      expect(decision.accessible, isTrue);
      expect(decision.canShowWithoutBlockingLesson, isTrue);
      expect(decision.accepted, isTrue);
      expect(
        decision.accessibilityDescription,
        contains('Diagrama que mostra'),
      );
    });

    test('visual inseguro ou pesado falha sem bloquear aula', () {
      const unsafe = LessonVisualTrigger(
        needsImage: true,
        kind: 'diagram',
        description: 'Diagrama do conceito.',
        svg: '<svg><script>alert(1)</script></svg>',
      );
      const heavy = LessonVisualTrigger(
        needsImage: true,
        kind: 'pedagogical_image',
        description: 'Imagem pedagogica grande demais.',
        raw: {'dataUrl': 'data:image/png;base64,AAA'},
      );

      const authority = LessonVisualSupportAuthority();
      final unsafeDecision = authority.evaluate(_candidateFrom(unsafe));
      final heavyDecision = authority.evaluate(_candidateFrom(heavy));

      expect(unsafeDecision.safe, isFalse);
      expect(unsafeDecision.accepted, isFalse);
      expect(unsafeDecision.canShowWithoutBlockingLesson, isTrue);
      expect(heavyDecision.light, isFalse);
      expect(heavyDecision.accepted, isFalse);
      expect(heavyDecision.canShowWithoutBlockingLesson, isTrue);
    });

    test('autoridade visual nao toca estado oficial do aluno', () {
      final source = File(
        'lib/sim/media/lesson_image_api_contract.dart',
      ).readAsStringSync();
      final start = source.indexOf('class LessonVisualSupportAuthority');
      final end = source.indexOf('const lessonVisualSupportAuthority');
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final authorityBlock = source.substring(start, end);

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
        expect(authorityBlock, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('falha visual e no_image preservam contrato N3 protegido', () {
      const trigger = LessonVisualTrigger(
        needsImage: true,
        kind: 'decorative',
        description: 'Stock bonito sem funcao de aprendizagem.',
      );

      const router = VisualRouterN2();
      final route = router.classify(trigger);

      expect(route.kind, VisualRouteN2Kind.noImage);
      expect(simVisualRoutePath, '/api/visual-route');
    });

    test('imagem pedagogica da aula respeita 3:4 e nao usa BoxFit.cover', () {
      expect(lessonImageStudyAspectRatio, 3 / 4);

      final aulaWidgets = File(
        'lib/features/classroom/aula_widgets.dart',
      ).readAsStringSync();
      final chatWidgets = File(
        'lib/features/classroom/chat_aula_widgets.dart',
      ).readAsStringSync();
      final chatMediaWidgets = File(
        'lib/features/classroom/widgets/media_widget.dart',
      ).readAsStringSync();

      expect(aulaWidgets, contains('lessonImageStudyAspectRatio'));
      expect(aulaWidgets, contains('class LessonVisualBoard'));
      expect(chatWidgets, contains("part 'widgets/media_widget.dart'"));
      expect(chatMediaWidgets, contains('LessonVisualBoard'));
      expect(aulaWidgets, isNot(contains('AspectRatio(aspectRatio: 16 / 10')));
      expect(chatWidgets, isNot(contains('AspectRatio(aspectRatio: 16 / 10')));
      expect(
        chatMediaWidgets,
        isNot(contains('AspectRatio(aspectRatio: 16 / 10')),
      );
      expect(aulaWidgets, isNot(contains('BoxFit.cover')));
      expect(chatWidgets, isNot(contains('BoxFit.cover')));
      expect(chatMediaWidgets, isNot(contains('BoxFit.cover')));
    });
  });
}

LessonVisualSupportCandidate _candidateFrom(LessonVisualTrigger trigger) {
  return LessonVisualSupportCandidate(
    needsVisual: trigger.needsImage,
    typeHint: trigger.kind ?? trigger.raw['visual_type'] ?? trigger.raw['type'],
    description: trigger.description,
    reason: trigger.reason,
    svg: trigger.svg,
    hasLocalTemplate: trigger.mathTemplate != null,
    raw: trigger.raw,
  );
}
