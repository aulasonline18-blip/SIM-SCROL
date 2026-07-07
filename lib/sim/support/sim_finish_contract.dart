import '../ui/sim_i18n.dart';

enum SimFinishArea {
  visualFaithfulness,
  buttons,
  texts,
  menus,
  audioPlaybackState,
  imagePresentationState,
  feedbacks,
  realLoading,
  errorStates,
  testableApk,
  androidPhoneTabletAdjustments,
}

class SimFinishRequirement {
  const SimFinishRequirement({
    required this.area,
    required this.labelKey,
    required this.sourceOfTruth,
  });

  final SimFinishArea area;
  final String labelKey;
  final String sourceOfTruth;

  String get label => t(labelKey);
}

const simFinishRequirements = <SimFinishRequirement>[
  SimFinishRequirement(
    area: SimFinishArea.visualFaithfulness,
    labelKey: 'finish_visual_faithfulness',
    sourceOfTruth:
        'Portal, Login, Idioma, Objetivo, Curriculo, Placement, Aula',
  ),
  SimFinishRequirement(
    area: SimFinishArea.buttons,
    labelKey: 'finish_buttons',
    sourceOfTruth: 'Start, Google, anexos, continuar, A/B/C, duvida, audio',
  ),
  SimFinishRequirement(
    area: SimFinishArea.texts,
    labelKey: 'finish_texts',
    sourceOfTruth: 'Textos vivos do fluxo traduzido',
  ),
  SimFinishRequirement(
    area: SimFinishArea.menus,
    labelKey: 'finish_menus',
    sourceOfTruth: 'Drawer/menu vivo do SIM',
  ),
  SimFinishRequirement(
    area: SimFinishArea.audioPlaybackState,
    labelKey: 'finish_audio_state',
    sourceOfTruth: 'useLessonAudioController/audio preference',
  ),
  SimFinishRequirement(
    area: SimFinishArea.imagePresentationState,
    labelKey: 'finish_image_state',
    sourceOfTruth: 'LessonVisualPipeline/generate lesson image',
  ),
  SimFinishRequirement(
    area: SimFinishArea.feedbacks,
    labelKey: 'finish_feedbacks',
    sourceOfTruth: 'lessonAnswerFeedback/LearningDecisionEngine',
  ),
  SimFinishRequirement(
    area: SimFinishArea.realLoading,
    labelKey: 'finish_real_loading',
    sourceOfTruth: 'Auth, anexos, preparo, imagem e audio',
  ),
  SimFinishRequirement(
    area: SimFinishArea.errorStates,
    labelKey: 'finish_error_states',
    sourceOfTruth: 'Auth, objetivo, anexos, audio, imagem, pagamento',
  ),
  SimFinishRequirement(
    area: SimFinishArea.testableApk,
    labelKey: 'finish_testable_apk',
    sourceOfTruth: 'flutter build apk --debug',
  ),
  SimFinishRequirement(
    area: SimFinishArea.androidPhoneTabletAdjustments,
    labelKey: 'finish_android_adjustments',
    sourceOfTruth: 'SafeArea, scroll, max width, deep link e permissoes',
  ),
];

bool simFinishIsComplete() {
  final covered = simFinishRequirements.map((r) => r.area).toSet();
  return covered.length == SimFinishArea.values.length;
}
