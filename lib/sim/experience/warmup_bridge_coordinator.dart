class WarmupBridgeCoordinator {
  bool officialLessonReady = false;
  bool warmupExpected = false;
  bool warmupUnavailableAfterExpected = false;
  bool continueRequested = false;
  bool aulaNavigationStarted = false;

  void reset({required bool warmupExpected}) {
    officialLessonReady = false;
    this.warmupExpected = warmupExpected;
    warmupUnavailableAfterExpected = false;
    continueRequested = false;
    aulaNavigationStarted = false;
  }

  void markWarmupUnavailable() {
    warmupUnavailableAfterExpected = warmupExpected;
    warmupExpected = false;
  }

  void markOfficialReady() {
    officialLessonReady = true;
  }

  bool requestContinue() {
    continueRequested = true;
    return !officialLessonReady;
  }

  bool shouldOpenOfficialAula({
    required String route,
    required bool hasLocalOfficialAulaState,
  }) {
    if (aulaNavigationStarted) return false;
    if (!officialLessonReady) {
      return !warmupExpected && hasLocalOfficialAulaState;
    }
    return true;
  }

  void markAulaNavigationStarted() {
    aulaNavigationStarted = true;
  }
}
