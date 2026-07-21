part of '../onboarding_screens.dart';

class _LanguageScreen extends StatefulWidget {
  const _LanguageScreen({required this.session});

  final LabSession session;

  @override
  State<_LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<_LanguageScreen> {
  late final TextEditingController otherController;
  late final LanguageSelectionViewModel viewModel;

  LabSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    viewModel = LanguageSelectionViewModel(session: session);
    otherController = TextEditingController(text: session.otherLanguage);
    session.addListener(_syncFromSession);
  }

  void _syncFromSession() {
    if (!mounted) return;
    if (otherController.text != session.otherLanguage) {
      otherController.value = TextEditingValue(
        text: session.otherLanguage,
        selection: TextSelection.collapsed(
          offset: session.otherLanguage.length,
        ),
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    session.removeListener(_syncFromSession);
    otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final palette = SimThemeScope.paletteOf(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: SimBreakpoints.learningMaxWidth(width),
            ),
            child: ListView(
              key: const Key('language-screen'),
              padding: SimBreakpoints.pagePadding(
                width,
              ).copyWith(top: 20, bottom: 28),
              children: [
                StepHeader(
                  title: t('language_title'),
                  subtitle: t('language_subtitle'),
                ),
                const SizedBox(height: 16),
                SimChatBubble(
                  text: t('language_choose_label'),
                  supportingText: t('language_subtitle'),
                ),
                const SizedBox(height: 12),
                SimChatInputCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SimChatChoiceWrap(
                        children: [
                          for (final language in supportedLangs)
                            LanguageButton(
                              language: language,
                              selected:
                                  viewModel.selectedLanguageCode ==
                                  language.code,
                              onTap: () => viewModel.chooseSupported(language),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SimChatFieldLabel(t('language_other_label')),
                      const SizedBox(height: 8),
                      SimInput(
                        key: const Key('language-other-input'),
                        controller: otherController,
                        hint: t('language_other_placeholder'),
                        onChanged: viewModel.setOtherLanguage,
                      ),
                      const SizedBox(height: 12),
                      PrimaryWideButton(
                        label: t('continue'),
                        onPressed: viewModel.canContinueWithOther
                            ? viewModel.chooseOther
                            : null,
                      ),
                    ],
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
