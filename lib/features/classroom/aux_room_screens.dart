import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/widgets/shared_widgets.dart';
import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/widgets/sim_preparation_experience.dart';
import '../session/lab_session.dart';

class LessonDoneScreen extends StatelessWidget {
  const LessonDoneScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SimPreparationExperience(
        stage: 'done',
        ready: true,
        onContinue: () => unawaited(session.continueAfterLessonDone()),
      ),
    ),
  );
}

class AuxRoomCard extends StatelessWidget {
  const AuxRoomCard({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => SimCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(body),
      ],
    ),
  );
}

class ReviewRoomScreen extends StatelessWidget {
  const ReviewRoomScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final review = session.reviewRoom;
    if (review == null) return const SizedBox.shrink();
    if (review.status == ReviewRoomStatus.choose) {
      return _CountPicker(
        title: t('aux_review_ask_count'),
        onClose: session.closeReviewRoom,
        onPick: (count) => unawaited(session.startReviewRoom(count)),
      );
    }
    if (review.status == ReviewRoomStatus.preparing) {
      return _Preparing(stage: 'review', onClose: session.closeReviewRoom);
    }
    if (review.status == ReviewRoomStatus.intro) {
      return _LiveIntro(
        title: t('aux_review_button'),
        body:
            'Vamos revisitar um ponto importante com calma. A aula principal continua preservada enquanto preparo a pergunta.',
        statusText: '${review.idx + 1}/${review.count}',
        onClose: session.closeReviewRoom,
      );
    }
    return _AuxQuestionScaffold(
      title: t('aux_review_button'),
      statusText: '${review.idx + 1}/${review.count}',
      content: review.conteudo,
      selected: review.letra,
      result: review.resultMsg ?? review.errMsg,
      done: review.status == ReviewRoomStatus.done,
      failed: review.status == ReviewRoomStatus.failed,
      onClose: session.closeReviewRoom,
      onAnswer: session.reviewSelecionar,
      onContinue: review.status == ReviewRoomStatus.result
          ? () => unawaited(session.reviewNext())
          : session.reviewContinue,
      onSignal: (signal) => unawaited(session.reviewSignal(signal)),
    );
  }
}

class RecoveryRoomScreen extends StatelessWidget {
  const RecoveryRoomScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final recovery = session.recoveryRoom;
    if (recovery == null) return const SizedBox.shrink();
    if (recovery.status == RecoveryRoomStatus.intro) {
      return _LiveIntro(
        title: t('aux_recovery_intro_msg'),
        body:
            'Vamos recuperar este ponto antes de concluir. A pendencia continua guardada e sua aula principal nao foi alterada.',
        statusText: recovery.queue.isEmpty
            ? 'Recuperacao'
            : '${recovery.idx + 1}/${recovery.queue.length}',
        onClose: session.closeRecoveryRoom,
      );
    }
    if (recovery.status == RecoveryRoomStatus.preparing) {
      return _Preparing(stage: 'recovery', onClose: session.closeRecoveryRoom);
    }
    return _AuxQuestionScaffold(
      title: t('aux_recovery_intro_msg'),
      statusText: '${recovery.idx + 1}/${recovery.queue.length}',
      content: recovery.conteudo,
      selected: recovery.letra,
      result: recovery.resultMsg ?? recovery.errMsg,
      done: recovery.status == RecoveryRoomStatus.done,
      failed: recovery.status == RecoveryRoomStatus.failed,
      onClose: session.closeRecoveryRoom,
      onAnswer: session.recoverySelecionar,
      onContinue: recovery.status == RecoveryRoomStatus.result
          ? () => unawaited(session.recoveryNext())
          : session.recoveryContinue,
      onSignal: (signal) => unawaited(session.recoverySignal(signal)),
    );
  }
}

class AmparoRoomScreen extends StatelessWidget {
  const AmparoRoomScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final amparo = session.amparoRoom;
    if (amparo == null) return const SizedBox.shrink();
    if (amparo.status == AmparoRoomStatus.intro) {
      return _LiveIntro(
        title: 'Amparo',
        body:
            'Vamos retomar juntos. Primeiro eu organizo o ponto de travamento; depois seguimos com uma pergunta curta.',
        statusText: amparo.stations.isEmpty
            ? 'Amparo'
            : '${amparo.idx + 1}/${amparo.stations.length} - nivel ${amparo.amparoLvl}',
        onClose: session.closeAmparoRoom,
      );
    }
    if (amparo.status == AmparoRoomStatus.preparing) {
      return _Preparing(stage: 'amparo', onClose: session.closeAmparoRoom);
    }
    final total = amparo.stations.length;
    final station = amparo.idx < total ? amparo.stations[amparo.idx] : null;
    return _AuxQuestionScaffold(
      title: station?.title ?? 'Amparo',
      statusText: total == 0
          ? 'Amparo'
          : '${amparo.idx + 1}/$total - nivel ${amparo.amparoLvl}',
      content: amparo.conteudo,
      selected: amparo.letra,
      result: amparo.resultMsg ?? amparo.errMsg,
      done: amparo.status == AmparoRoomStatus.done,
      failed: amparo.status == AmparoRoomStatus.failed,
      onClose: session.closeAmparoRoom,
      onAnswer: session.amparoSelecionar,
      onContinue: amparo.status == AmparoRoomStatus.result
          ? () => unawaited(session.amparoNext())
          : session.finishAmparo,
      onSignal: (signal) => unawaited(session.amparoSignal(signal)),
    );
  }
}

class _LiveIntro extends StatelessWidget {
  const _LiveIntro({
    required this.title,
    required this.body,
    required this.statusText,
    required this.onClose,
  });

  final String title;
  final String body;
  final String statusText;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: BackButton(onPressed: onClose),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(statusText),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AuxRoomCard(title: title, body: body),
        const SizedBox(height: 14),
        const LinearProgressIndicator(),
      ],
    ),
  );
}

class _Preparing extends StatelessWidget {
  const _Preparing({required this.stage, required this.onClose});

  final String stage;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: BackButton(onPressed: onClose)),
    body: Center(
      child: SimPreparationExperience(
        stage: stage,
        ready: false,
        onContinue: onClose,
      ),
    ),
  );
}

class _CountPicker extends StatelessWidget {
  const _CountPicker({
    required this.title,
    required this.onClose,
    required this.onPick,
  });

  final String title;
  final VoidCallback onClose;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: BackButton(onPressed: onClose)),
    body: Center(
      child: SimCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  onPressed: () => onPick(5),
                  child: const Text('5'),
                ),
                FilledButton(
                  onPressed: () => onPick(10),
                  child: const Text('10'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _AuxQuestionScaffold extends StatelessWidget {
  const _AuxQuestionScaffold({
    required this.title,
    required this.statusText,
    required this.content,
    required this.selected,
    required this.result,
    required this.done,
    required this.failed,
    required this.onClose,
    required this.onAnswer,
    required this.onContinue,
    required this.onSignal,
  });

  final String title;
  final String statusText;
  final AuxRoomContent? content;
  final AnswerLetter? selected;
  final String? result;
  final bool done;
  final bool failed;
  final VoidCallback onClose;
  final ValueChanged<AnswerLetter> onAnswer;
  final VoidCallback onContinue;
  final ValueChanged<DecisionSignal> onSignal;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: BackButton(onPressed: onClose),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(statusText),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (failed) SimChatErrorLike(text: result ?? t('aula_gen_fail')),
        if (done) ...[
          SimPreparationExperience(
            stage: 'done',
            ready: true,
            onContinue: onClose,
          ),
        ] else if (content == null) ...[
          const Center(child: CircularProgressIndicator()),
        ] else ...[
          if (content!.explanation.trim().isNotEmpty) ...[
            AuxRoomCard(title: 'Explicacao', body: content!.explanation),
            const SizedBox(height: 14),
          ],
          Text(
            content!.question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          for (final entry in content!.options.entries)
            AnswerButton(
              letter: entry.key.name,
              text: entry.value,
              selected: selected == entry.key,
              enabled: true,
              onTap: () => onAnswer(entry.key),
            ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            _Signals(onSignal: onSignal),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            AuxRoomCard(title: t('feedback'), body: result!),
            const SizedBox(height: 12),
            PrimaryWideButton(label: t('continue'), onTap: onContinue),
          ],
        ],
      ],
    ),
  );
}

class _Signals extends StatelessWidget {
  const _Signals({required this.onSignal});

  final ValueChanged<DecisionSignal> onSignal;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    children: [
      for (final signal in DecisionSignal.values)
        FilterChip(
          label: Text('${signal.value}'),
          selected: false,
          onSelected: (_) => onSignal(signal),
        ),
    ],
  );
}

class SimChatErrorLike extends StatelessWidget {
  const SimChatErrorLike({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
  );
}
