part of '../onboarding_screens.dart';

class LanguageSelectionViewModel {
  const LanguageSelectionViewModel({required this.session});

  final LabSession session;

  String? get selectedLanguageCode => session.selectedLanguageCode;

  String get otherLanguage => session.otherLanguage;

  bool get canContinueWithOther => session.otherLanguage.trim().isNotEmpty;

  void setOtherLanguage(String value) => session.setOtherLanguage(value);

  void chooseSupported(SupportedLang language) {
    session.chooseLanguage(language.code, language.name);
  }

  void chooseOther() {
    session.chooseLanguage('other', session.otherLanguage);
  }
}
