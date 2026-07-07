import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/classroom/chat_aula_messages.dart';
import 'package:sim_mobile/features/classroom/chat_aula_timeline_builder.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/ui/sim_i18n.dart';

void main() {
  test('builds chat messages for explanation, image, question and options', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.reading(),
          imagem: 'data:image/png;base64,AAAA',
        ),
        showImagePanel: true,
      ),
    );

    expect(
      messages.map((message) => message.kind),
      containsAllInOrder([
        ChatLessonMessageKind.explanation,
        ChatLessonMessageKind.image,
        ChatLessonMessageKind.question,
        ChatLessonMessageKind.options,
      ]),
    );
    final options = messages.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.options,
    );
    expect(options.options.map((option) => option.letter), [
      AnswerLetter.A,
      AnswerLetter.B,
      AnswerLetter.C,
    ]);
    expect(options.options.every((option) => option.enabled), isTrue);
  });

  test('expanded phase opens signal choices under the selected option', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(phase: ClassroomPhase.expanded(AnswerLetter.B)),
      ),
    );

    expect(
      messages.map((message) => message.kind),
      containsAllInOrder([ChatLessonMessageKind.options]),
    );
    expect(
      messages.where(
        (message) => message.kind == ChatLessonMessageKind.signals,
      ),
      isEmpty,
    );
    expect(
      messages.where(
        (message) => message.kind == ChatLessonMessageKind.studentAnswer,
      ),
      isEmpty,
    );
    final options = messages.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.options,
    );
    expect(options.selectedAnswer, AnswerLetter.B);
    expect(
      options.options.singleWhere((option) => option.selected).letter,
      AnswerLetter.B,
    );
    expect(options.signals.map((signal) => signal.value), [1, 2, 3]);
  });

  test('completed phase adds feedback without student signal echo', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.completed(
            message: 'aula_fb_correct',
            wasCorrect: true,
            signal: DecisionSignal.one,
          ),
        ),
      ),
    );

    expect(
      messages.map((message) => message.kind),
      contains(ChatLessonMessageKind.feedback),
    );
    expect(
      messages.where(
        (message) => message.kind == ChatLessonMessageKind.studentSignal,
      ),
      isEmpty,
    );
    expect(
      messages.where(
        (message) => message.kind == ChatLessonMessageKind.doubtAction,
      ),
      isEmpty,
    );
    final feedback = messages.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.feedback,
    );
    expect(feedback.isCorrect, isTrue);
    expect(feedback.actionKey, 'aula_next');
  });

  test('processing phase does not add student signal echo', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.processing(
            AnswerLetter.B,
            DecisionSignal.two,
          ),
        ),
      ),
    );

    expect(
      messages.where(
        (message) => message.kind == ChatLessonMessageKind.studentSignal,
      ),
      isEmpty,
    );
    expect(
      messages.map((message) => message.kind),
      contains(ChatLessonMessageKind.processing),
    );
  });

  test('history is represented as old sim and student messages', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.reading(),
          history: const [
            QuestionHistoryEntry(
              id: 'h1',
              text: 'Pergunta antiga?',
              options: [
                QuestionOptionEntry(id: AnswerLetter.A, text: 'Alpha'),
                QuestionOptionEntry(id: AnswerLetter.B, text: 'Beta'),
                QuestionOptionEntry(id: AnswerLetter.C, text: 'Gamma'),
              ],
              chosenOptionId: AnswerLetter.C,
              correct: false,
              imageUrl: 'data:image/png;base64,AAAA',
              answeredAt: 1767344700000,
            ),
          ],
        ),
      ),
    );

    expect(messages.first.kind, ChatLessonMessageKind.historyQuestion);
    expect(messages.first.imageData, isNotNull);
    expect(messages.first.options, hasLength(3));
    expect(
      messages.first.options.singleWhere((option) => option.selected).letter,
      AnswerLetter.C,
    );
    expect(messages.first.options.every((option) => option.enabled), isFalse);
    expect(messages.first.timestampLabel, '09:05');
    expect(messages[1].kind, ChatLessonMessageKind.historyAnswer);
    expect(messages[1].selectedAnswer, AnswerLetter.C);
    expect(messages[1].isCorrect, isFalse);
    expect(messages[1].timestampLabel, '09:05');
  });

  test('active messages use distinct ids across layers in the same item', () {
    final firstLayer = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.reading(),
          headerLabel: 'aula_item_of:1/5:aula_layer_1',
          explanation: 'Explicacao da primeira camada.',
          question: 'Pergunta da primeira camada?',
        ),
      ),
    );
    final secondLayer = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.reading(),
          headerLabel: 'aula_item_of:1/5:aula_layer_2',
          explanation: 'Explicacao da segunda camada.',
          question: 'Pergunta da segunda camada?',
        ),
      ),
    );

    final firstQuestion = firstLayer.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.question,
    );
    final secondQuestion = secondLayer.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.question,
    );

    expect(firstQuestion.id, isNot(secondQuestion.id));
    expect(firstQuestion.id, contains('aula-layer-1'));
    expect(secondQuestion.id, contains('aula-layer-2'));
  });

  test('loading and engine errors stay system messages with retry action', () {
    final loading = buildChatLessonMessages(
      const ChatLessonTimelineInput(snapshot: null, runtimeLoading: true),
    );
    expect(loading.single.kind, ChatLessonMessageKind.loading);
    expect(loading.single.actionKey, 'retry');
    expect(loading.single.deliveryStatus, ChatLessonDeliveryStatus.processing);

    final error = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.engineError('T02 indisponivel'),
        ),
      ),
    );
    expect(error.last.kind, ChatLessonMessageKind.error);
    expect(error.last.text, 'T02 indisponivel');
    expect(error.last.actionKey, 'retry');
    expect(error.last.deliveryStatus, ChatLessonDeliveryStatus.failed);
  });

  test('chat messages carry universal conversational delivery states', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.completed(
            message: 'aula_fb_correct',
            wasCorrect: true,
            signal: DecisionSignal.one,
          ),
          history: const [
            QuestionHistoryEntry(
              id: 'h1',
              text: 'Pergunta antiga?',
              options: [
                QuestionOptionEntry(id: AnswerLetter.A, text: 'Alpha'),
                QuestionOptionEntry(id: AnswerLetter.B, text: 'Beta'),
                QuestionOptionEntry(id: AnswerLetter.C, text: 'Gamma'),
              ],
              chosenOptionId: AnswerLetter.A,
              correct: true,
            ),
          ],
        ),
      ),
    );

    expect(
      messages
          .singleWhere(
            (message) => message.kind == ChatLessonMessageKind.historyQuestion,
          )
          .deliveryStatus,
      ChatLessonDeliveryStatus.read,
    );
    expect(
      messages.where(
        (message) => message.kind == ChatLessonMessageKind.doubtAction,
      ),
      isEmpty,
    );
    expect(
      messages
          .singleWhere(
            (message) => message.kind == ChatLessonMessageKind.feedback,
          )
          .deliveryStatus,
      ChatLessonDeliveryStatus.delivered,
    );
    expect(
      messages.map((message) => message.sequenceIndex).toList(),
      List<int>.generate(messages.length, (index) => index),
    );
  });

  test('image states stay non blocking before question and options', () {
    for (final state in const [
      ('ready', 'data:image/png;base64,AAAA', null, false),
      ('loading', null, null, false),
      ('error', null, 'Imagem falhou sem bloquear.', false),
      ('offer', null, null, true),
    ]) {
      final messages = buildChatLessonMessages(
        ChatLessonTimelineInput(
          snapshot: _snapshot(
            phase: const ClassroomPhase.reading(),
            imagem: state.$2,
          ),
          showImagePanel: true,
          imageStatus: state.$1,
          imageError: state.$3,
          hasPaidImageOffer: state.$4,
        ),
      );
      final kinds = messages.map((message) => message.kind).toList();
      final imageIndex = kinds.indexOf(ChatLessonMessageKind.image);
      final questionIndex = kinds.indexOf(ChatLessonMessageKind.question);
      final optionsIndex = kinds.indexOf(ChatLessonMessageKind.options);
      expect(imageIndex, greaterThanOrEqualTo(0));
      expect(questionIndex, greaterThan(imageIndex));
      expect(optionsIndex, greaterThan(questionIndex));

      final image = messages[imageIndex];
      expect(image.imageStatus, state.$1);
      expect(image.imageData, state.$2);
      expect(image.text, state.$3);
      expect(image.hasPaidImageOffer, state.$4);
    }
  });

  test('doubt processing response and error are represented in timeline', () {
    final processing = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(phase: const ClassroomPhase.reading()),
        doubtProcessing: true,
        doubtProgress: 45,
      ),
    );
    final processingMessage = processing.singleWhere(
      (message) => message.id == 'doubt-processing',
    );
    expect(processingMessage.kind, ChatLessonMessageKind.loading);
    expect(processingMessage.progress, 45);

    final response = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(phase: const ClassroomPhase.reading()),
        doubtResponse: 'Explicacao da duvida.',
      ),
    );
    expect(
      response.singleWhere((message) => message.id == 'doubt-response').text,
      'Explicacao da duvida.',
    );

    final error = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(phase: const ClassroomPhase.reading()),
        doubtError: 'Dúvida indisponível.',
      ),
    );
    expect(
      error.singleWhere((message) => message.id == 'doubt-error').text,
      'Dúvida indisponível.',
    );
  });

  test('system chat messages follow the active app language', () {
    addTearDown(() => setSimActiveLanguage('en'));
    setSimActiveLanguage('fr');

    final processing = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(phase: const ClassroomPhase.reading()),
        doubtProcessing: true,
        doubtProgress: 45,
      ),
    );
    expect(
      processing
          .singleWhere((message) => message.id == 'doubt-processing')
          .text,
      'Analyse de votre question...',
    );

    final completed = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.completed(
            message: 'aula_fb_correct',
            wasCorrect: true,
            signal: DecisionSignal.one,
          ),
        ),
      ),
    );
    expect(completed.where((message) => message.id == 'doubt-action'), isEmpty);
    expect(
      completed
          .singleWhere(
            (message) => message.kind == ChatLessonMessageKind.feedback,
          )
          .text,
      '✅ Exact. Vous maîtrisez ce point.',
    );
  });
}

LessonRuntimeSnapshot _snapshot({
  required ClassroomPhase phase,
  String? imagem,
  List<QuestionHistoryEntry> history = const [],
  String headerLabel = 'aula_item_of:1/5:aula_layer_1',
  String explanation = 'Explicacao curta.',
  String question = 'Qual alternativa representa o conceito?',
}) {
  return LessonRuntimeSnapshot(
    authReady: true,
    authed: true,
    hasCurriculum: true,
    isDone: false,
    viewModel: LessonMainViewModel(
      progress: 20,
      headerLabel: headerLabel,
      options: const [],
      locked:
          phase.type == ClassroomPhaseType.processando ||
          phase.type == ClassroomPhaseType.concluido ||
          phase.type == ClassroomPhaseType.carregando,
      nextLabel: phase.type == ClassroomPhaseType.concluido ? 'aula_next' : '',
    ),
    phase: phase,
    history: history,
    conteudo: LessonContent(
      explanation: explanation,
      question: question,
      options: const {
        AnswerLetter.A: 'Primeira alternativa',
        AnswerLetter.B: 'Segunda alternativa',
        AnswerLetter.C: 'Terceira alternativa',
      },
      correctAnswer: AnswerLetter.A,
    ),
    imagem: imagem,
    itemMarker: 'M1',
    itemText: 'Item 1',
  );
}
