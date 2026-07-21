import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/features/session/use_cases/request_account_deletion_use_case.dart';
import 'package:sim_mobile/session/auth_session.dart';
import 'package:sim_mobile/session/lesson_ui_state.dart';
import 'package:sim_mobile/session/navigation_state.dart';
import 'package:sim_mobile/sim/billing/account_deletion.dart';

void main() {
  test('RequestAccountDeletionUseCase exige confirmacao literal', () async {
    final lessonUiState = LessonUiState()..setDeleteConfirmation('deletar');
    final navigationState = NavigationState();
    final authSession = AuthSession(navigation: navigationState)
      ..authed = true
      ..userId = 'student-1';
    final gateway = _FakeAccountDeletionGateway();

    await RequestAccountDeletionUseCase(
      lessonUiState: lessonUiState,
      authSession: authSession,
      navigationState: navigationState,
      gatewayFactory: () => gateway,
    ).execute();

    expect(gateway.requests, isEmpty);
    expect(
      lessonUiState.accountDeletionMessage,
      'Digite DELETAR para confirmar a solicitação.',
    );
  });

  test('RequestAccountDeletionUseCase registra e sai da conta', () async {
    final lessonUiState = LessonUiState()..setDeleteConfirmation('DELETAR');
    final navigationState = NavigationState()..route = '/account-deletion';
    final authSession = AuthSession(navigation: navigationState)
      ..authed = true
      ..userId = 'student-2'
      ..userEmail = 'student@example.com';
    final gateway = _FakeAccountDeletionGateway();

    await RequestAccountDeletionUseCase(
      lessonUiState: lessonUiState,
      authSession: authSession,
      navigationState: navigationState,
      gatewayFactory: () => gateway,
    ).execute();

    expect(gateway.requests.single.userId, 'student-2');
    expect(gateway.requests.single.confirmation, 'DELETAR');
    expect(gateway.requests.single.emailSnapshot, 'student@example.com');
    expect(authSession.authed, isFalse);
    expect(navigationState.route, '/');
    expect(lessonUiState.accountDeletionLoading, isFalse);
  });
}

class _FakeAccountDeletionGateway implements AccountDeletionGateway {
  final requests = <AccountDeletionRequest>[];

  @override
  Future<void> requestAccountDeletion(AccountDeletionRequest request) async {
    requests.add(request);
  }
}
