import 'dart:async';
import 'dart:io';

import 'student_experience_types.dart';

String _humanErrorMessage(Object? error) {
  final raw = error?.toString() ?? '';
  final lower = raw.toLowerCase();
  if (lower.contains('timeout')) {
    return 'A conexao demorou demais. Tente novamente em instantes.';
  }
  if (lower.contains('socket') || lower.contains('network')) {
    return 'A conexao parece instavel. Salvamos seu ponto e vamos tentar novamente.';
  }
  if (raw.contains('{') || raw.contains('}') || lower.contains('exception')) {
    return 'Nao consegui concluir isso agora. Tente novamente em instantes.';
  }
  return raw.trim().isEmpty
      ? 'Nao consegui concluir isso agora. Tente novamente em instantes.'
      : raw.trim();
}

StudentExperienceErrorInfo classifyStudentExperienceError(Object error) {
  final message = error.toString();
  final lower = message.toLowerCase();
  if (message.contains('HTTP 402') ||
      lower.contains('credit') ||
      lower.contains('credito') ||
      lower.contains('saldo') ||
      lower.contains('insufficient_credits')) {
    return const StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.credits,
      message:
          'Seus creditos acabaram. Compre creditos para continuar estudando.',
    );
  }
  if (lower.contains('http 401') ||
      lower.contains('http 403') ||
      lower.contains('missing bearer') ||
      lower.contains('invalid token') ||
      lower.contains('auth') ||
      lower.contains('unauthorized') ||
      lower.contains('forbidden')) {
    return StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.auth,
      message:
          'Sua sessao precisa ser renovada. Entre novamente para continuar.',
    );
  }
  if (error is TimeoutException ||
      lower.contains('timeout') ||
      lower.contains('timeoutexception') ||
      lower.contains('tempo') ||
      lower.contains('abort') ||
      lower.contains('t02 nao devolveu') ||
      lower.contains('aula minima')) {
    return const StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.timeout,
      message: 'A preparacao demorou demais. Toque para tentar novamente.',
    );
  }
  if (error is SocketException ||
      lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('network is unreachable') ||
      lower.contains('failed host lookup') ||
      lower.contains('os error') ||
      lower.contains('cleartext') ||
      lower.contains('http 5')) {
    return StudentExperienceErrorInfo(
      kind: StudentExperienceErrorKind.generic,
      message: _humanErrorMessage(error),
    );
  }
  return const StudentExperienceErrorInfo(
    kind: StudentExperienceErrorKind.generic,
    message:
        'Nao consegui preparar a entrada da aula agora. Toque para tentar novamente.',
  );
}
