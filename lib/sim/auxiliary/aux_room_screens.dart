import 'aux_room_models.dart';
import '../ui/sim_i18n.dart';

class DoubtInputSheetModel {
  const DoubtInputSheetModel({
    required this.title,
    required this.description,
    required this.placeholder,
    required this.submitLabel,
    required this.busyLabel,
    required this.cameraLabel,
    required this.galleryLabel,
    required this.removeLabel,
  });

  final String title;
  final String description;
  final String placeholder;
  final String submitLabel;
  final String busyLabel;
  final String cameraLabel;
  final String galleryLabel;
  final String removeLabel;
}

DoubtInputSheetModel get doubtInputSheetModel => DoubtInputSheetModel(
  title: t('aula_doubt'),
  description: t('aula_doubt_about_question'),
  placeholder: t('doubt_placeholder'),
  submitLabel: t('aula_doubt'),
  busyLabel: t('aula_registering'),
  cameraLabel: t('attach_camera'),
  galleryLabel: t('attach_image'),
  removeLabel: t('remove'),
);

class AuxRoomScreenState {
  const AuxRoomScreenState({this.review, this.recovery});

  final ReviewRoomView? review;
  final RecoveryRoomView? recovery;

  bool get showingReview => review != null;
  bool get showingRecovery => recovery != null;
}
