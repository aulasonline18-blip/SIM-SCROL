import 'lesson_image_api_contract.dart';
import '../lesson/lesson_event_bus.dart';

abstract interface class LessonPaidImageOrchestrator {
  Future<LessonImageGenerationMetadata?> acceptPaidImageOffer(String lessonKey);
  void declinePaidImageOffer(String lessonKey);
}

abstract interface class CreditsGateway {
  Future<int> getMyCredits();
}

class LessonPaidImageOfferController {
  LessonPaidImageOfferController({
    required this.orchestrator,
    required this.creditsGateway,
    this.onNavigate,
  });

  final LessonPaidImageOrchestrator orchestrator;
  final CreditsGateway creditsGateway;
  final void Function(String target)? onNavigate;

  LessonPaidImageOffer? paidOffer;
  String? lessonKey;
  bool offerLoading = false;
  int? creditBalance;
  String? navigationTarget;

  Future<void> refreshBalance() async {
    creditBalance = await creditsGateway.getMyCredits();
  }

  void registerPaidOffer(String key, LessonPaidImageOffer offer) {
    lessonKey = key;
    paidOffer = offer;
  }

  void clearPaidOffer() {
    lessonKey = null;
    paidOffer = null;
  }

  Future<void> acceptPaidImage() async {
    final key = lessonKey;
    if (key == null) return;
    offerLoading = true;
    try {
      await orchestrator.acceptPaidImageOffer(key);
      await refreshBalance();
    } finally {
      offerLoading = false;
    }
  }

  void declinePaidImage() {
    final key = lessonKey;
    if (key == null) return;
    orchestrator.declinePaidImageOffer(key);
    paidOffer = null;
  }

  void handleInsufficientCredits({String? kind}) {
    if (kind == 'image') {
      creditBalance = 0;
      offerLoading = false;
      return;
    }
    buyCredits();
  }

  void buyCredits() {
    navigationTarget = '/creditos?returnTo=/cyber/aula';
    onNavigate?.call(navigationTarget!);
  }
}
