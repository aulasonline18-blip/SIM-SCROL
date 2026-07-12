bool containsForbiddenTechnicalErrorText(String message) {
  final lower = message.toLowerCase();
  const forbidden = [
    'exception',
    'stacktrace',
    'socketexception',
    'formatexception',
    'null check operator',
    'typeerror',
    'undefined',
    'null',
    'xmlhttprequest',
    'access_token',
    'bearer',
    'prompt',
    'api key',
    '/root/',
    'lib/',
    '.dart',
    '{',
    '}',
  ];
  if (lower.contains('http 500') || lower.contains('http 401')) return true;
  return forbidden.any(lower.contains);
}

String humanErrorMessage(
  Object? error, {
  String fallback =
      'Nao consegui concluir isso agora. Tente novamente em instantes.',
}) {
  final raw = error?.toString() ?? '';
  final lower = raw.toLowerCase();
  if (lower.contains('401') ||
      lower.contains('403') ||
      lower.contains('unauthorized') ||
      lower.contains('forbidden') ||
      lower.contains('invalid token') ||
      lower.contains('missing bearer')) {
    return 'Sua sessao precisa ser renovada. Entre novamente para continuar.';
  }
  if (lower.contains('timeout') ||
      lower.contains('timeoutexception') ||
      lower.contains('tempo esgotado')) {
    return 'A conexao demorou demais. Tente novamente em instantes.';
  }
  if (lower.contains('socket') ||
      lower.contains('connection') ||
      lower.contains('network') ||
      lower.contains('failed host lookup') ||
      lower.contains('http 5')) {
    return 'A conexao parece instavel. Salvamos seu ponto e vamos tentar novamente.';
  }
  if (containsForbiddenTechnicalErrorText(raw)) return fallback;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return fallback;
  return trimmed;
}
