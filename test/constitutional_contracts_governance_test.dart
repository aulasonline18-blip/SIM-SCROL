import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<String> conflictRows(String text) {
  return text
      .split(RegExp(r'\r?\n'))
      .where((line) => RegExp(r'^\| [0-9]+ \|').hasMatch(line))
      .toList();
}

void assertConstitution(String text) {
  expect(text, contains('Codigo: CCSIM-1'));
  expect(text, contains('Status: VIGENTE'));
  expect(
    text,
    contains(
      'autoridade maxima sobre contratos, leis, prompts, rotas, orgaos, cache, midia, estado, custo, IA e UI',
    ),
  );
  expect(
    text,
    contains('Se dois contratos conflitarem, vence o contrato da camada mais alta.'),
  );
  expect(text, contains('execucao deve falhar com erro de governanca'));

  for (final authority in [
    'Seguranca, custo, privacidade e protecao anti-loop.',
    'Aula textual do aluno.',
    'Estado, progresso, dominio e avanco.',
    'T00/T02 e contratos de IA textual.',
    'Imagem, audio, midia e anexos.',
    'Cache, janela viva, fila e pre-carregamento.',
    'UI, layout e experiencia visual.',
    'Rotas oficiais',
    'Custo/rate limit',
    'Aula pronta',
    'Navegacao inicial',
    'Visual/imagem',
    'Audio',
    'Estado/dominio',
  ]) {
    expect(text, contains(authority));
  }

  expect(conflictRows(text), hasLength(50));

  for (final requiredResolution in [
    '| 1 | Rotas oficiais do app contra inventario mais amplo | Servidor e Constituicao | Inventario | Inventario e historico | constitutional governance |',
    '| 11 | Rate limit geral contra AiCostProtectionGate | AiCostProtectionGate | Rate limit generico como juiz | Generico vira protecao local | ai cost gate |',
    '| 19 | Aula pronta no resolver contra service aplicando material | LessonReadinessResolver | Service como juiz | Service executa, nao decide | app governance |',
    '| 38 | Warmup coordenador contra logica em LabSession | Coordenador unico | LabSession decisor | LabSession executa UI | entry governance |',
    '| 44 | Autoridade visual no app/N2/N3 servidor | S12/N3 servidor | App como juiz final | App renderiza | visual governance |',
    '| 50 | Relatorios antigos dizem fechado com risco APK/manual | Marco final/uso real | "Fechado" historico | Fechado nao equivale a APK real | final governance |',
  ]) {
    expect(text, contains(requiredResolution));
  }

  for (final status in ['VIGENTE', 'SUBORDINADO', 'HISTORICO', 'REMOVIDO']) {
    expect(text, contains(status));
  }

  for (final reference in [
    'OWASP API4:2023',
    'RFC 6585',
    'RFC 9110',
    'Flutter Testing',
    'Node.js runtime',
  ]) {
    expect(text, contains(reference));
  }
}

void main() {
  test('Constituicao dos contratos existe no app e no servidor', () {
    final appConstitution =
        File('docs/CONSTITUICAO_CONTRATOS_SIM.md').readAsStringSync();
    final serverConstitution = File(
      '/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md',
    ).readAsStringSync();

    assertConstitution(appConstitution);
    assertConstitution(serverConstitution);

    expect(
      appConstitution,
      contains('/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md'),
    );
    expect(
      serverConstitution,
      contains('/root/SIM-SCROL/docs/CONSTITUICAO_CONTRATOS_SIM.md'),
    );
  });
}
