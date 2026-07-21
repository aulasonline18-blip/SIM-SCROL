part of '../onboarding_screens.dart';

class ObjectiveEntryViewModel {
  ObjectiveEntryViewModel({required this.session, required this.reception});

  final LabSession session;
  final PedagogicalReceptionController reception;

  List<PedagogicalReceptionStep> get visibleSteps =>
      reception.steps.take(reception.activeIndex + 1).toList(growable: false);

  String? validateActiveStep() {
    final current = reception.steps[reception.activeIndex];
    return reception.validateStep(current.id);
  }

  bool get hasProcessingAttachment => session.attachments.any(
    (attachment) => attachment.status == 'processing',
  );

  bool submitObjectiveEntry() => session.saveObjectiveEntry();

  void advance() => reception.advance();

  void edit(String stepId) => reception.edit(stepId);

  String summaryFor(String stepId) => reception.summaryFor(stepId);

  List<String> finalSummaryLines() => reception.finalSummaryLines();
}
