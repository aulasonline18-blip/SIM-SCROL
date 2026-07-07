import '../ui/sim_i18n.dart';

class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.userId,
    required this.confirmation,
    this.emailSnapshot,
    this.reason = 'user_requested_account_deletion',
  });

  final String userId;
  final String confirmation;
  final String? emailSnapshot;
  final String reason;
}

abstract interface class AccountDeletionGateway {
  Future<void> requestAccountDeletion(AccountDeletionRequest request);
}

class AccountDeletionController {
  AccountDeletionController({required this.gateway});

  final AccountDeletionGateway gateway;
  bool loading = false;
  bool done = false;
  String? error;

  bool canSubmit(String confirm) => confirm == 'DELETAR' && !loading && !done;

  Future<void> submit({
    required String confirm,
    required String userId,
    String? email,
  }) async {
    if (!canSubmit(confirm)) return;
    loading = true;
    error = null;
    try {
      await gateway.requestAccountDeletion(
        AccountDeletionRequest(
          userId: userId,
          confirmation: confirm,
          emailSnapshot: email,
        ),
      );
      done = true;
    } catch (err) {
      error = err is Error
          ? err.toString()
          : t('account_delete_register_failed');
    } finally {
      loading = false;
    }
  }
}

class DeleteAccountTexts {
  const DeleteAccountTexts();

  String get title => 'Solicitar exclusao da conta';
  String get description =>
      'Esta solicitacao e irreversivel. Seus dados pessoais serao apagados em ate 30 dias conforme a LGPD. Historico financeiro sera mantido pelo prazo legal obrigatorio.';
  String get confirmLabel => 'Digite DELETAR para confirmar';
  String get loadingLabel => 'Registrando...';
  String get submitLabel => 'Solicitar exclusao da conta';
  String get doneMessage =>
      'Solicitacao registrada. Ela sera analisada e processada conforme a politica de privacidade.';
}
