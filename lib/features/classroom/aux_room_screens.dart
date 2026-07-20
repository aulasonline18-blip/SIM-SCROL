import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/widgets/shared_widgets.dart';
import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/ui/sim_components.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';
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
  const AuxRoomCard({
    required this.title,
    required this.body,
    this.tone = SimSurfaceTone.normal,
    this.icon,
    super.key,
  });

  final String title;
  final String body;
  final SimSurfaceTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return SimLearningSurface(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, color: _foregroundFor(palette, tone), size: 20),
                const SizedBox(width: SimSpacing.xs),
              ],
              Expanded(
                child: Text(
                  title,
                  style: SimTypography.label.copyWith(color: palette.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: SimTypography.body.copyWith(color: palette.text)),
        ],
      ),
    );
  }
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
        room: _AuxRoomVisual.review,
        onClose: session.closeReviewRoom,
        onPick: (count) => unawaited(session.startReviewRoom(count)),
      );
    }
    if (review.status == ReviewRoomStatus.preparing) {
      return _Preparing(
        room: _AuxRoomVisual.review,
        stage: 'review',
        onClose: session.closeReviewRoom,
      );
    }
    if (review.status == ReviewRoomStatus.intro) {
      return _LiveIntro(
        room: _AuxRoomVisual.review,
        title: t('aux_review_button'),
        body:
            'Vamos manter este ponto vivo com uma revisao curta. A aula principal fica preservada enquanto preparo a pergunta.',
        statusText: '${review.idx + 1}/${review.count}',
        onClose: session.closeReviewRoom,
      );
    }
    return _AuxQuestionScaffold(
      room: _AuxRoomVisual.review,
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
        room: _AuxRoomVisual.recovery,
        title: t('aux_recovery_title'),
        body:
            'Vamos reconstruir o minimo necessario deste ponto antes de concluir. Sua aula principal continua preservada.',
        statusText: recovery.queue.isEmpty
            ? 'Recuperação'
            : '${recovery.idx + 1}/${recovery.queue.length}',
        onClose: session.closeRecoveryRoom,
      );
    }
    if (recovery.status == RecoveryRoomStatus.preparing) {
      return _Preparing(
        room: _AuxRoomVisual.recovery,
        stage: 'recovery',
        onClose: session.closeRecoveryRoom,
      );
    }
    return _AuxQuestionScaffold(
      room: _AuxRoomVisual.recovery,
      title: t('aux_recovery_title'),
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
        room: _AuxRoomVisual.amparo,
        title: 'Amparo',
        body:
            'Vamos retomar juntos, sem pressa. Primeiro organizo o ponto de travamento; depois seguimos com uma pergunta curta.',
        statusText: amparo.stations.isEmpty
            ? 'Amparo'
            : '${amparo.idx + 1}/${amparo.stations.length} - nivel ${amparo.amparoLvl}',
        onClose: session.closeAmparoRoom,
      );
    }
    if (amparo.status == AmparoRoomStatus.preparing) {
      return _Preparing(
        room: _AuxRoomVisual.amparo,
        stage: 'amparo',
        onClose: session.closeAmparoRoom,
      );
    }
    final total = amparo.stations.length;
    final station = amparo.idx < total ? amparo.stations[amparo.idx] : null;
    return _AuxQuestionScaffold(
      room: _AuxRoomVisual.amparo,
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
    required this.room,
    required this.title,
    required this.body,
    required this.statusText,
    required this.onClose,
  });

  final _AuxRoomVisual room;
  final String title;
  final String body;
  final String statusText;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => _AuxRoomFrame(
    room: room,
    title: title,
    statusText: statusText,
    onClose: onClose,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuxRoomCard(
          title: title,
          body: body,
          tone: room.surfaceTone,
          icon: room.icon,
        ),
        const SizedBox(height: SimSpacing.md),
        SimStatusSurface(
          tone: room.surfaceTone,
          icon: Icons.auto_awesome_outlined,
          child: Text(room.preparingText),
        ),
        const SizedBox(height: SimSpacing.md),
        SimProgressRail(value: 0.35, semanticLabel: room.preparingText),
      ],
    ),
  );
}

class _Preparing extends StatelessWidget {
  const _Preparing({
    required this.room,
    required this.stage,
    required this.onClose,
  });

  final _AuxRoomVisual room;
  final String stage;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => _AuxRoomFrame(
    room: room,
    title: room.title,
    statusText: room.statusLabel,
    onClose: onClose,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SimStatusSurface(
          tone: room.surfaceTone,
          icon: Icons.hourglass_top_rounded,
          child: Text(room.preparingText),
        ),
        const SizedBox(height: SimSpacing.md),
        SimPreparationExperience(
          stage: stage,
          ready: false,
          onContinue: onClose,
        ),
      ],
    ),
  );
}

class _CountPicker extends StatelessWidget {
  const _CountPicker({
    required this.title,
    required this.room,
    required this.onClose,
    required this.onPick,
  });

  final String title;
  final _AuxRoomVisual room;
  final VoidCallback onClose;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => _AuxRoomFrame(
    room: room,
    title: room.title,
    statusText: room.statusLabel,
    onClose: onClose,
    child: SimLearningSurface(
      tone: room.surfaceTone,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: SimTypography.lessonQuestion.copyWith(
              color: SimThemeScope.paletteOf(context).text,
            ),
          ),
          const SizedBox(height: SimSpacing.md),
          Row(
            children: [
              Expanded(
                child: SimActionButton(
                  label: '5',
                  icon: Icons.refresh_rounded,
                  onPressed: () => onPick(5),
                  tone: SimActionTone.secondary,
                ),
              ),
              const SizedBox(width: SimSpacing.sm),
              Expanded(
                child: SimActionButton(
                  label: '10',
                  icon: Icons.refresh_rounded,
                  onPressed: () => onPick(10),
                  tone: SimActionTone.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _AuxQuestionScaffold extends StatelessWidget {
  const _AuxQuestionScaffold({
    required this.room,
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

  final _AuxRoomVisual room;
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
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return _AuxRoomFrame(
      room: room,
      title: title,
      statusText: statusText,
      onClose: onClose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failed)
            SimChatErrorLike(text: result ?? t('aula_gen_fail'))
          else if (done) ...[
            SimStatusSurface(
              tone: SimSurfaceTone.success,
              icon: Icons.check_circle_outline,
              child: Text(room.doneText),
            ),
            const SizedBox(height: SimSpacing.md),
            SimPreparationExperience(
              stage: 'done',
              ready: true,
              onContinue: onClose,
            ),
          ] else if (content == null) ...[
            SimStatusSurface(
              tone: room.surfaceTone,
              icon: Icons.hourglass_top_rounded,
              child: Text(room.preparingText),
            ),
            const SizedBox(height: SimSpacing.md),
            SimProgressRail(value: 0.45, semanticLabel: room.preparingText),
          ] else ...[
            SimStatusSurface(
              tone: room.surfaceTone,
              icon: room.icon,
              child: Text(room.identityText),
            ),
            const SizedBox(height: SimSpacing.md),
            if (content!.explanation.trim().isNotEmpty) ...[
              AuxRoomCard(
                title: 'Explicação',
                body: content!.explanation,
                tone: SimSurfaceTone.normal,
                icon: Icons.psychology_alt_outlined,
              ),
              const SizedBox(height: SimSpacing.md),
            ],
            SimLearningSurface(
              tone: SimSurfaceTone.elevated,
              child: Text(
                content!.question,
                style: SimTypography.lessonQuestion.copyWith(
                  color: palette.text,
                ),
              ),
            ),
            const SizedBox(height: SimSpacing.md),
            for (final entry in content!.options.entries)
              AnswerButton(
                letter: entry.key.name,
                text: entry.value,
                selected: selected == entry.key,
                enabled: true,
                onTap: () => onAnswer(entry.key),
              ),
            if (selected != null) ...[
              const SizedBox(height: SimSpacing.sm),
              _Signals(onSignal: onSignal),
            ],
            if (result != null) ...[
              const SizedBox(height: SimSpacing.md),
              AuxRoomCard(
                title: t('feedback'),
                body: result!,
                tone: result == null
                    ? SimSurfaceTone.normal
                    : SimSurfaceTone.selected,
                icon: Icons.forum_outlined,
              ),
              const SizedBox(height: SimSpacing.md),
              PrimaryWideButton(label: t('continue'), onTap: onContinue),
            ],
          ],
        ],
      ),
    );
  }
}

class _AuxRoomFrame extends StatelessWidget {
  const _AuxRoomFrame({
    required this.room,
    required this.title,
    required this.statusText,
    required this.onClose,
    required this.child,
  });

  final _AuxRoomVisual room;
  final String title;
  final String statusText;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: SimSpacing.xs),
          child: SimIconAction(
            icon: Icons.arrow_back_rounded,
            semanticLabel: 'Voltar',
            onPressed: onClose,
          ),
        ),
        title: Text(
          title,
          style: SimTypography.label.copyWith(color: palette.text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: SimSpacing.md),
            child: Center(
              child: _AuxStatusPill(label: statusText, tone: room.surfaceTone),
            ),
          ),
        ],
      ),
      body: SimResponsiveContainer(
        includeSafeArea: true,
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            0,
            SimSpacing.sm,
            0,
            SimSpacing.xl,
          ),
          children: [
            SimSectionHeader(
              title: room.title,
              subtitle: room.subtitle,
              trailing: Icon(
                room.icon,
                color: _foregroundFor(palette, room.surfaceTone),
              ),
            ),
            const SizedBox(height: SimSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

class _AuxStatusPill extends StatelessWidget {
  const _AuxStatusPill({required this.label, required this.tone});

  final String label;
  final SimSurfaceTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surfaceFor(palette, tone),
        borderRadius: BorderRadius.circular(SimRadius.pill),
        border: Border.all(color: _foregroundFor(palette, tone)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SimSpacing.sm,
          vertical: SimSpacing.xs,
        ),
        child: Text(
          label,
          style: SimTypography.caption.copyWith(
            color: _foregroundFor(palette, tone),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

enum _AuxRoomKind { review, recovery, amparo }

class _AuxRoomVisual {
  const _AuxRoomVisual._({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.preparingText,
    required this.identityText,
    required this.doneText,
    required this.surfaceTone,
    required this.icon,
  });

  final _AuxRoomKind kind;
  final String title;
  final String subtitle;
  final String statusLabel;
  final String preparingText;
  final String identityText;
  final String doneText;
  final SimSurfaceTone surfaceTone;
  final IconData icon;

  static const review = _AuxRoomVisual._(
    kind: _AuxRoomKind.review,
    title: 'Sala de revisão',
    subtitle: 'Reforço leve para manter a memória ativa.',
    statusLabel: 'Revisão',
    preparingText: 'Estou separando um ponto bom para revisar.',
    identityText: 'Revisão auxiliar: reforço sem mexer na aula principal.',
    doneText: 'Revisão concluída. O ponto ficou mais vivo para continuar.',
    surfaceTone: SimSurfaceTone.selected,
    icon: Icons.refresh_rounded,
  );

  static const recovery = _AuxRoomVisual._(
    kind: _AuxRoomKind.recovery,
    title: 'Sala de recuperação',
    subtitle: 'Reparo curto para reconstruir o necessário com segurança.',
    statusLabel: 'Recuperação',
    preparingText: 'Estou montando um reparo curto para firmar este ponto.',
    identityText: 'Recuperação auxiliar: reparo mínimo antes de seguir.',
    doneText: 'Recuperação concluída. Já existe um caminho seguro para seguir.',
    surfaceTone: SimSurfaceTone.warning,
    icon: Icons.construction_rounded,
  );

  static const amparo = _AuxRoomVisual._(
    kind: _AuxRoomKind.amparo,
    title: 'Sala de amparo',
    subtitle: 'Acolhimento para destravar com calma e voltar ao fluxo.',
    statusLabel: 'Amparo',
    preparingText:
        'Estou organizando um apoio curto para destravar este ponto.',
    identityText: 'Amparo auxiliar: cuidado imediato sem castigo.',
    doneText: 'Amparo concluído. Vamos voltar com mais segurança.',
    surfaceTone: SimSurfaceTone.success,
    icon: Icons.volunteer_activism_outlined,
  );
}

Color _foregroundFor(SimPalette palette, SimSurfaceTone tone) {
  return switch (tone) {
    SimSurfaceTone.selected => palette.primary,
    SimSurfaceTone.success => palette.success,
    SimSurfaceTone.warning => palette.warning,
    SimSurfaceTone.danger => palette.danger,
    _ => palette.text,
  };
}

Color _surfaceFor(SimPalette palette, SimSurfaceTone tone) {
  return switch (tone) {
    SimSurfaceTone.selected => palette.selectedSurface,
    SimSurfaceTone.success => palette.successSurface,
    SimSurfaceTone.warning => palette.warningSurface,
    SimSurfaceTone.danger => palette.dangerSurface,
    SimSurfaceTone.elevated => palette.elevatedSurface,
    SimSurfaceTone.soft => palette.surfaceSoft,
    SimSurfaceTone.normal => palette.surface,
  };
}

class _Signals extends StatelessWidget {
  const _Signals({required this.onSignal});

  final ValueChanged<DecisionSignal> onSignal;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    return SimLearningSurface(
      tone: SimSurfaceTone.soft,
      padding: const EdgeInsets.all(SimSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como ficou agora?',
            style: SimTypography.label.copyWith(color: palette.text),
          ),
          const SizedBox(height: SimSpacing.sm),
          Wrap(
            spacing: SimSpacing.xs,
            runSpacing: SimSpacing.xs,
            children: [
              for (final signal in DecisionSignal.values)
                _SignalButton(signal: signal, onSignal: onSignal),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalButton extends StatelessWidget {
  const _SignalButton({required this.signal, required this.onSignal});

  final DecisionSignal signal;
  final ValueChanged<DecisionSignal> onSignal;

  @override
  Widget build(BuildContext context) {
    final palette = SimThemeScope.paletteOf(context);
    final label = switch (signal) {
      DecisionSignal.one => 'Entendi',
      DecisionSignal.two => 'Preciso revisar',
      DecisionSignal.three => 'Ainda não sei',
    };
    return Semantics(
      button: true,
      label: '$label, sinal ${signal.value}',
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(SimRadius.pill),
        child: InkWell(
          onTap: () => onSignal(signal),
          borderRadius: BorderRadius.circular(SimRadius.pill),
          child: Container(
            constraints: const BoxConstraints(minHeight: SimTouch.min),
            padding: const EdgeInsets.symmetric(
              horizontal: SimSpacing.md,
              vertical: SimSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SimRadius.pill),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: palette.selectedSurface,
                  child: Text(
                    '${signal.value}',
                    style: TextStyle(
                      color: palette.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: SimSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SimTypography.label.copyWith(color: palette.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimChatErrorLike extends StatelessWidget {
  const SimChatErrorLike({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => SimStatusSurface(
    tone: SimSurfaceTone.danger,
    icon: Icons.error_outline,
    child: Text(text),
  );
}
