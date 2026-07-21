import 'package:flutter/material.dart';

import '../../features/session/lab_session.dart';
import '../../session/entry_form_state.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../sim/reception/pedagogical_reception_controller.dart';
import '../../sim/ui/sim_design_system.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/sim_theme.dart';

part 'view_models/objective_entry_view_model.dart';
part 'view_models/language_selection_view_model.dart';
part 'screens/objective_entry_screen.dart';
part 'screens/language_selection_screen.dart';
part 'screens/onboarding_reception_widgets.dart';
part 'screens/onboarding_chat_widgets.dart';
part 'screens/onboarding_attachment_widgets.dart';

class ConversationalEntryScreen extends StatelessWidget {
  const ConversationalEntryScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final routePath = Uri.tryParse(session.route)?.path ?? session.route;
    if (routePath == '/cyber/idioma') {
      return _LanguageScreen(session: session);
    }
    return _EntryScreen(session: session);
  }
}

class ObjetoScreen extends StatelessWidget {
  const ObjetoScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) => _EntryScreen(session: session);
}
