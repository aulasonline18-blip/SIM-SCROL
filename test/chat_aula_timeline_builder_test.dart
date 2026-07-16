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

  test('typed blocks preserve pedagogical order and metadata', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        lessonLocalId: 'lesson-m9',
        snapshot: _snapshot(
          phase: const ClassroomPhase.reading(),
          imagem: 'data:image/png;base64,AAAA',
        ),
        showImagePanel: true,
      ),
    );
    final blocks = messages.map(AulaConversationBlock.fromMessage).toList();

    expect(
      blocks.map((block) => block.type),
      containsAllInOrder([
        AulaConversationBlockType.explanation,
        AulaConversationBlockType.visual,
        AulaConversationBlockType.question,
        AulaConversationBlockType.answerOptions,
      ]),
    );
    expect(blocks.every((block) => block.id.startsWith('aula-block-')), isTrue);

    final visual = blocks.singleWhere(
      (block) => block.type == AulaConversationBlockType.visual,
    );
    expect(visual.imageData, 'data:image/png;base64,AAAA');
    expect(visual.metadata['lessonLocalId'], 'lesson-m9');
    expect(visual.metadata['marker'], 'M1');
    expect(visual.metadata['itemIdx'], 0);
    expect(visual.metadata['layer'], 1);

    final options = blocks.singleWhere(
      (block) => block.type == AulaConversationBlockType.answerOptions,
    );
    expect(options.active, isTrue);
    expect(options.action, AulaConversationAction.chooseAnswer);
    expect(options.options.map((option) => option.letter), [
      AnswerLetter.A,
      AnswerLetter.B,
      AnswerLetter.C,
    ]);
  });

  test('typed blocks keep historical actions inert', () {
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
              chosenOptionId: AnswerLetter.B,
              correct: true,
            ),
          ],
        ),
      ),
    );

    final historical = AulaConversationBlock.fromMessage(
      messages.singleWhere(
        (message) => message.kind == ChatLessonMessageKind.historyQuestion,
      ),
    );
    final active = AulaConversationBlock.fromMessage(
      messages.singleWhere(
        (message) => message.kind == ChatLessonMessageKind.options,
      ),
    );

    expect(historical.type, AulaConversationBlockType.historyQuestion);
    expect(historical.active, isFalse);
    expect(historical.isHistorical, isTrue);
    expect(historical.action, isNull);
    expect(historical.options.every((option) => !option.enabled), isTrue);
    expect(active.type, AulaConversationBlockType.answerOptions);
    expect(active.active, isTrue);
    expect(active.action, AulaConversationAction.chooseAnswer);
  });

  test('typed blocks expose feedback and recoverable error actions', () {
    const feedback = ChatLessonMessage(
      id: 'feedback',
      role: ChatLessonMessageRole.sim,
      kind: ChatLessonMessageKind.feedback,
      text: 'Muito bem.',
      actionKey: 'aula_next',
      isActionable: true,
    );
    const doubtAnswer = ChatLessonMessage(
      id: 'doubt-answer',
      role: ChatLessonMessageRole.sim,
      kind: ChatLessonMessageKind.feedback,
      text: 'Resposta da dúvida.',
      isActionable: false,
    );
    const error = ChatLessonMessage(
      id: 'error',
      role: ChatLessonMessageRole.system,
      kind: ChatLessonMessageKind.error,
      text: 'Vamos tentar de novo.',
      actionKey: 'retry',
      isActionable: true,
    );

    final feedbackBlock = AulaConversationBlock.fromMessage(feedback);
    final doubtAnswerBlock = AulaConversationBlock.fromMessage(doubtAnswer);
    final errorBlock = AulaConversationBlock.fromMessage(error);

    expect(feedbackBlock.type, AulaConversationBlockType.feedback);
    expect(feedbackBlock.action, AulaConversationAction.advance);
    expect(doubtAnswerBlock.type, AulaConversationBlockType.doubtAnswer);
    expect(doubtAnswerBlock.action, isNull);
    expect(errorBlock.type, AulaConversationBlockType.recoverableError);
    expect(errorBlock.action, AulaConversationAction.retry);
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

  test('completed phase shows immediate next-topic loading feedback', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.completed(
            message: 'aula_fb_correct',
            wasCorrect: true,
            signal: DecisionSignal.one,
          ),
        ),
        runtimeLoading: true,
      ),
    );

    expect(
      messages.map((message) => message.kind),
      containsAllInOrder([
        ChatLessonMessageKind.feedback,
        ChatLessonMessageKind.loading,
      ]),
    );
    final loading = messages.last;
    expect(loading.id, startsWith('runtime-advance-loading-'));
    expect(loading.text, t('preparing_next_lesson'));
    expect(loading.deliveryStatus, ChatLessonDeliveryStatus.processing);
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
        lessonLocalId: 'lesson-m9',
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
    expect(messages.first.lessonLocalId, 'lesson-m9');
    expect(messages.first.marker, 'M1');
    expect(messages.first.itemIdx, 0);
    expect(messages.first.layer, 1);
    expect(messages.first.isHistorical, isTrue);
    expect(messages.first.isActionable, isFalse);
    expect(messages.first.createdAt, 1767344700000);
    expect(messages.first.imageData, isNotNull);
    expect(messages.first.options, hasLength(3));
    expect(
      messages.first.options.singleWhere((option) => option.selected).letter,
      AnswerLetter.C,
    );
    expect(messages.first.options.every((option) => option.enabled), isFalse);
    expect(messages.first.hasInteractiveOptions, isFalse);
    expect(messages.first.timestampLabel, '09:05');
    expect(messages[1].kind, ChatLessonMessageKind.historyAnswer);
    expect(messages[1].isHistorical, isTrue);
    expect(messages[1].isActionable, isFalse);
    expect(messages[1].selectedAnswer, AnswerLetter.C);
    expect(messages[1].isCorrect, isFalse);
    expect(messages[1].timestampLabel, '09:05');
  });

  test('active and historical messages are distinguished by contract', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        lessonLocalId: 'lesson-m9',
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
              answeredAt: 1767344700000,
            ),
          ],
        ),
      ),
    );

    final historical = messages.where((message) => message.isHistorical);
    expect(historical, isNotEmpty);
    expect(historical.every((message) => !message.isActionable), isTrue);
    expect(
      historical.every(
        (message) =>
            message.lessonLocalId == 'lesson-m9' &&
            message.marker == 'M1' &&
            message.itemIdx == 0 &&
            message.layer == 1,
      ),
      isTrue,
    );

    final activeOptions = messages.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.options,
    );
    final activeFeedback = messages.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.feedback,
    );
    expect(activeOptions.isHistorical, isFalse);
    expect(activeOptions.isActionable, isTrue);
    expect(activeOptions.hasInteractiveOptions, isTrue);
    expect(activeFeedback.isHistorical, isFalse);
    expect(activeFeedback.isActionable, isTrue);
    expect(activeFeedback.actionKey, 'aula_next');
  });

  test('message contract serializes identity actionability and status', () {
    const message = ChatLessonMessage(
      id: 'm9-contract',
      role: ChatLessonMessageRole.sim,
      kind: ChatLessonMessageKind.options,
      lessonLocalId: 'lesson-m9',
      marker: 'M1',
      itemIdx: 0,
      layer: 2,
      createdAt: 1767344700000,
      isHistorical: true,
      isActionable: false,
      actionKey: 'old-action',
      deliveryStatus: ChatLessonDeliveryStatus.read,
      options: [
        ChatLessonOption(
          letter: AnswerLetter.A,
          text: 'A',
          selected: true,
          enabled: false,
        ),
      ],
    );

    final restored = ChatLessonMessage.fromJson(message.toJson());
    expect(restored, isNotNull);
    expect(restored!.lessonLocalId, 'lesson-m9');
    expect(restored.marker, 'M1');
    expect(restored.itemIdx, 0);
    expect(restored.layer, 2);
    expect(restored.createdAt, 1767344700000);
    expect(restored.isHistorical, isTrue);
    expect(restored.isActionable, isFalse);
    expect(restored.actionKey, 'old-action');
    expect(restored.deliveryStatus, ChatLessonDeliveryStatus.read);
    expect(restored.hasInteractiveOptions, isFalse);
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
    expect(error.last.text, t('aula_gen_fail'));
    expect(error.last.actionKey, 'retry');
    expect(error.last.deliveryStatus, ChatLessonDeliveryStatus.failed);
  });

  test('technical runtime errors are controlled and do not leak raw keys', () {
    final feedbackKeyError = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.engineError('aula_fb_correct'),
        ),
      ),
    );
    expect(feedbackKeyError.last.text, t('aula_fb_correct'));
    expect(feedbackKeyError.last.text, isNot('aula_fb_correct'));

    final rawHttpError = buildChatLessonMessages(
      ChatLessonTimelineInput(
        snapshot: _snapshot(
          phase: const ClassroomPhase.engineError(
            'HTTP 500: {"error":"complete-lesson failed"}',
          ),
        ),
      ),
    );
    expect(rawHttpError.last.kind, ChatLessonMessageKind.error);
    expect(rawHttpError.last.text, t('aula_gen_fail'));
    expect(rawHttpError.last.text, isNot(contains('HTTP 500')));
    expect(rawHttpError.last.text, isNot(contains('{"error"')));
    expect(rawHttpError.last.actionKey, 'retry');
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
      ('ready', 'data:image/png;base64,AAAA', null),
      ('loading', null, null),
      ('error', null, 'Imagem falhou sem bloquear.'),
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
    }
  });

  test('advancing experience preserves old text and image as dead history', () {
    final messages = buildChatLessonMessages(
      ChatLessonTimelineInput(
        lessonLocalId: 'lesson-m9',
        snapshot: _snapshot(
          phase: const ClassroomPhase.reading(),
          explanation: 'Explicacao nova.',
          question: 'Pergunta nova?',
          imagem: 'data:image/png;base64,NOVA',
          history: const [
            QuestionHistoryEntry(
              id: 'old-m1',
              text: 'Pergunta antiga?',
              options: [
                QuestionOptionEntry(id: AnswerLetter.A, text: 'Alpha antiga'),
                QuestionOptionEntry(id: AnswerLetter.B, text: 'Beta antiga'),
                QuestionOptionEntry(id: AnswerLetter.C, text: 'Gamma antiga'),
              ],
              chosenOptionId: AnswerLetter.B,
              correct: false,
              imageUrl: 'data:image/png;base64,ANTIGA',
              answeredAt: 1767344700000,
            ),
          ],
        ),
        showImagePanel: true,
        imageStatus: 'ready',
      ),
    );

    final oldQuestion = messages.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.historyQuestion,
    );
    final newQuestion = messages.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.question,
    );
    final newImage = messages.singleWhere(
      (message) => message.kind == ChatLessonMessageKind.image,
    );

    expect(oldQuestion.text, 'Pergunta antiga?');
    expect(oldQuestion.imageData, 'data:image/png;base64,ANTIGA');
    expect(oldQuestion.options.map((option) => option.text), [
      'Alpha antiga',
      'Beta antiga',
      'Gamma antiga',
    ]);
    expect(oldQuestion.isHistorical, isTrue);
    expect(oldQuestion.isActionable, isFalse);
    expect(newQuestion.text, 'Pergunta nova?');
    expect(newImage.imageData, 'data:image/png;base64,NOVA');
    expect(newImage.isHistorical, isFalse);
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

  test(
    'doubt messages stay inside the conversation without progress action',
    () {
      final response = buildChatLessonMessages(
        ChatLessonTimelineInput(
          lessonLocalId: 'lesson-m9',
          snapshot: _snapshot(
            phase: const ClassroomPhase.expanded(AnswerLetter.B),
            headerLabel: 'aula_item_of:2/5:aula_layer_2',
          ),
          doubtResponse: 'Resposta auxiliar da dúvida.',
        ),
      );

      final doubt = response.singleWhere(
        (message) => message.id == 'doubt-response',
      );
      final options = response.singleWhere(
        (message) => message.kind == ChatLessonMessageKind.options,
      );
      expect(doubt.kind, ChatLessonMessageKind.feedback);
      expect(doubt.lessonLocalId, 'lesson-m9');
      expect(doubt.itemIdx, 1);
      expect(doubt.layer, 2);
      expect(doubt.isActionable, isFalse);
      expect(doubt.actionKey, isNull);
      expect(options.selectedAnswer, AnswerLetter.B);
      expect(options.isActionable, isTrue);
    },
  );

  test(
    'review and recovery messages have their own conversational identity',
    () {
      const review = ChatLessonMessage(
        id: 'review-m1',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.review,
        text: 'Revisao de M1',
        lessonLocalId: 'lesson-m9',
        marker: 'M1',
        itemIdx: 0,
        layer: 1,
        isActionable: false,
      );
      const recovery = ChatLessonMessage(
        id: 'recovery-m1',
        role: ChatLessonMessageRole.sim,
        kind: ChatLessonMessageKind.recovery,
        text: 'Recuperacao de M1',
        lessonLocalId: 'lesson-m9',
        marker: 'M1',
        itemIdx: 0,
        layer: 1,
        isActionable: false,
      );

      final restoredReview = ChatLessonMessage.fromJson(review.toJson());
      final restoredRecovery = ChatLessonMessage.fromJson(recovery.toJson());
      expect(restoredReview?.kind, ChatLessonMessageKind.review);
      expect(restoredRecovery?.kind, ChatLessonMessageKind.recovery);
      expect(restoredReview?.marker, 'M1');
      expect(restoredRecovery?.marker, 'M1');
      expect(restoredReview?.isActionable, isFalse);
      expect(restoredRecovery?.isActionable, isFalse);
    },
  );

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
