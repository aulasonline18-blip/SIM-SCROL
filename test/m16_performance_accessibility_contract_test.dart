import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/aula_widgets.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_widgets.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_design_system.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';
import 'package:sim_mobile/sim/ui/responsive/sim_responsive.dart';

void main() {
  setUp(() => setSimActiveLanguage('pt'));

  testWidgets('M16 aula pequena com fonte grande mostra texto e erro de mídia', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: ChatAulaTimeline(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              messages: const [
                ChatLessonMessage(
                  id: 'exp',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.explanation,
                  text: 'Texto essencial da aula aparece primeiro.',
                ),
                ChatLessonMessage(
                  id: 'image-failed',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.image,
                  text: 'Imagem indisponível agora.',
                  imageStatus: 'failed',
                ),
                ChatLessonMessage(
                  id: 'question',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.question,
                  text: 'Qual alternativa preserva o sentido?',
                ),
                ChatLessonMessage(
                  id: 'options',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.options,
                  options: [
                    ChatLessonOption(
                      letter: AnswerLetter.A,
                      text: 'Resposta curta A',
                      selected: false,
                      enabled: true,
                    ),
                    ChatLessonOption(
                      letter: AnswerLetter.B,
                      text:
                          'Resposta B com texto maior que precisa quebrar linha',
                      selected: false,
                      enabled: true,
                    ),
                    ChatLessonOption(
                      letter: AnswerLetter.C,
                      text: 'Resposta curta C',
                      selected: true,
                      enabled: true,
                    ),
                  ],
                  signals: [
                    ChatLessonSignal(
                      value: 1,
                      labelKey: 'aula_sig_certeza',
                      enabled: true,
                    ),
                    ChatLessonSignal(
                      value: 2,
                      labelKey: 'aula_sig_duvida',
                      enabled: true,
                    ),
                    ChatLessonSignal(
                      value: 3,
                      labelKey: 'aula_sig_chute',
                      enabled: true,
                    ),
                  ],
                ),
              ],
              onChooseAnswer: (_) {},
              onSignal: (_) {},
              onRetry: () {},
              onNext: () {},
              onOpenDoubt: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Texto essencial da aula'), findsOneWidget);
    expect(find.textContaining('Imagem indisponível'), findsOneWidget);
  });

  testWidgets('M16 resposta e sinal continuam tocáveis em tela pequena', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);

    AnswerLetter? chosen;
    int? signal;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: ChatAulaTimeline(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              messages: const [
                ChatLessonMessage(
                  id: 'question',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.question,
                  text: 'Qual alternativa preserva o sentido?',
                ),
                ChatLessonMessage(
                  id: 'options',
                  role: ChatLessonMessageRole.sim,
                  kind: ChatLessonMessageKind.options,
                  options: [
                    ChatLessonOption(
                      letter: AnswerLetter.A,
                      text: 'Resposta curta A',
                      selected: true,
                      enabled: true,
                    ),
                    ChatLessonOption(
                      letter: AnswerLetter.B,
                      text:
                          'Resposta B com texto maior que precisa quebrar linha',
                      selected: false,
                      enabled: true,
                    ),
                    ChatLessonOption(
                      letter: AnswerLetter.C,
                      text: 'Resposta curta C',
                      selected: false,
                      enabled: true,
                    ),
                  ],
                  signals: [
                    ChatLessonSignal(
                      value: 1,
                      labelKey: 'aula_sig_certeza',
                      enabled: true,
                    ),
                    ChatLessonSignal(
                      value: 2,
                      labelKey: 'aula_sig_duvida',
                      enabled: true,
                    ),
                    ChatLessonSignal(
                      value: 3,
                      labelKey: 'aula_sig_chute',
                      enabled: true,
                    ),
                  ],
                ),
              ],
              onChooseAnswer: (letter) => chosen = letter,
              onSignal: (value) => signal = value,
              onRetry: () {},
              onNext: () {},
              onOpenDoubt: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Qual alternativa'), findsOneWidget);
    expect(find.text('Resposta curta A'), findsOneWidget);
    await tester.tap(find.text('Resposta curta A'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('signal-button-1')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('signal-button-1'))).height,
      greaterThanOrEqualTo(SimTouch.min),
    );

    await tester.ensureVisible(find.byKey(const Key('signal-button-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('signal-button-1')));
    await tester.pump();

    expect(chosen, AnswerLetter.A);
    expect(signal, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M16 imagem raster inválida falha com estado humano controlado', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonMediaImageView(
            data: 'data:image/png;base64,base64-invalido',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(LessonImageErrorView), findsOneWidget);
    expect(find.text(t('aula_image_unavailable_short')), findsOneWidget);
  });

  test('M16 contratos responsivos mantêm limites para celular fraco', () {
    expect(SimResponsive.widthClassFor(320), SimWindowClass.compact);
    expect(SimResponsive.heightClassFor(568), SimWindowClass.medium);
    expect(SimResponsive.buttonMinimumSizeFor(320).height, SimTouch.min);
    expect(SimResponsive.buttonMinimumSizeFor(320).width, SimTouch.min);
    expect(
      SimResponsive.visibleSizeFor(
        const MediaQueryData(
          size: Size(320, 568),
          padding: EdgeInsets.only(top: 24, bottom: 16),
          viewInsets: EdgeInsets.only(bottom: 240),
        ),
      ).height,
      304,
    );
  });
}
