import '../../../session/auth_session.dart';
import '../../../session/lesson_ui_state.dart';
import '../../../session/navigation_state.dart';
import '../../../sim/billing/account_deletion.dart';
import '../../../sim/ui/sim_i18n.dart';

class RequestAccountDeletionUseCase {
  const RequestAccountDeletionUseCase({
    required this.lessonUiState,
    required this.authSession,
    required this.navigationState,
    required this.gatewayFactory,
  });

  final LessonUiState lessonUiState;
  final AuthSession authSession;
  final NavigationState navigationState;
  final AccountDeletionGateway Function() gatewayFactory;

  Future<void> execute() async {
    if (lessonUiState.accountDeletionLoading) return;
    final confirmation = lessonUiState.deleteConfirmation.trim();
    if (confirmation != 'DELETAR') {
      lessonUiState.failAccountDeletionRequest(
        'Digite DELETAR para confirmar a solicitação.',
      );
      return;
    }
    final id = (authSession.userId ?? '').trim();
    if (!authSession.authed || id.isEmpty) {
      lessonUiState.failAccountDeletionRequest(
        'Entre na sua conta para solicitar exclusão.',
      );
      return;
    }
    lessonUiState.beginAccountDeletionRequest();
    try {
      await gatewayFactory().requestAccountDeletion(
        AccountDeletionRequest(
          userId: id,
          confirmation: confirmation,
          emailSnapshot: authSession.userEmail,
        ),
      );
      lessonUiState.completeAccountDeletionRequest();
      await authSession.signOutReal();
      navigationState.openRoute('/');
    } catch (error) {
      lessonUiState.failAccountDeletionRequest(
        t('account_delete_failed', {'error': error}),
      );
    }
  }
}
