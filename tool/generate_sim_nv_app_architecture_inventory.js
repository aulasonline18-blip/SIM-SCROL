const fs = require('fs');
const path = require('path');

const root = process.cwd();
const libRoot = path.join(root, 'lib');

const layers = [
  'UI',
  'Assistente local',
  'Motores pedagogicos',
  'Motores de conteudo',
  'Persistencia/cache/sync',
  'Ponte com servidor',
];

const pedagogicalEngines = [
  { id: 'learning-decision-engine', name: 'LearningDecisionEngine' },
  { id: 'mastery-truth-engine', name: 'MasteryTruthEngine' },
  { id: 'error-classifier', name: 'ErrorClassifier' },
  { id: 'advance-engine', name: 'AdvanceEngine' },
  { id: 'domain-rules', name: 'DomainRules' },
];

const contentEngines = [
  { id: 't00', name: 'T00' },
  { id: 't02', name: 'T02' },
  { id: 'warmup-amparo', name: 'warmup/amparo' },
  { id: 'doubt', name: 'doubt' },
  { id: 'review', name: 'review' },
  { id: 'recovery', name: 'recovery' },
];

const contracts = [
  'T00/curriculo/mapa',
  'T02/microaula/questao',
  'estado forte do aluno',
  'sessao/aula',
  'item/camada/questao',
  'avanco/advance-gate',
  'revisao/recuperacao/duvida',
  'visual/imagem',
  'audio',
  'cache/sync',
  'erro/falha',
];

const contractAreas = [
  'auth',
  'billing',
  'cloud',
  'config',
  'content-bridge',
  'curriculum',
  'lesson',
  'media',
  'onboarding',
  'placement',
  'portal',
  'session',
  'state',
  'support-ui',
  'runtime-shape',
];

const stateMachines = [
  'sessao/aula',
  'item',
  'camada',
  'questao',
  'visual',
  'audio',
  'avanco',
  'revisao',
  'recuperacao',
  'duvida',
  'curriculo',
  'cache/sync',
  'falha/retry',
];

const officialPaths = [
  'objetivo do aluno ate T00',
  'curriculo',
  'aula/pergunta',
  'resposta do aluno',
  'proxima camada ou proximo item',
  'revisao/recuperacao/duvida',
  'audio',
  'imagem',
  'curriculo grande',
];

const routeWhitelist = [
  '/api/bootstrap-t00',
  '/api/complete-lesson',
  '/api/visual-route',
  '/api/generate-lesson-image',
  '/api/generate-lesson-audio',
  '/api/process-attachment',
  '/api/student-state/*',
  '/api/credits/*',
  '/api/payments/*',
  '/api/play-billing/*',
  '/api/account/*',
  '/api/health',
];

const forbiddenRuntimeRoutes = [
  '/api/warmup',
  '/api/doubt',
  '/api/review',
  '/api/recovery',
  '/api/advance-gate',
  '/api/server-classroom',
];

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(full);
    return full.endsWith('.dart') ? [full] : [];
  });
}

function ownerFor(file) {
  const parts = file.split('/');
  if (file === 'lib/main.dart') return 'app-bootstrap';
  if (parts[1] === 'features') return `feature-${parts[2]}`;
  if (parts[1] === 'session') return 'session';
  if (parts[1] === 'shared') return 'shared-ui';
  if (parts[1] === 'core') return 'core';
  if (parts[1] === 'sim') return `sim-${parts[2]}`;
  return 'unclassified-owner';
}

function classify(file) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  const out = {
    path: file,
    layer: 'Assistente local',
    category: 'assistente-local',
    owner: ownerFor(file),
    logicalOwner: ownerFor(file),
    inputs: [],
    outputs: [],
    tests: [],
    decision: 'manter',
    engines: [],
    contentEngines: [],
    contracts: [],
    stateMachines: [],
    officialPaths: [],
  };

  const set = (key, values) => {
    for (const value of values) if (!out[key].includes(value)) out[key].push(value);
  };

  if (file === 'lib/main.dart') {
    out.layer = 'Assistente local';
    out.category = 'app-bootstrap';
    set('contracts', ['sessao/aula', 'cache/sync', 'erro/falha']);
    set('stateMachines', ['sessao/aula', 'falha/retry']);
    set('officialPaths', ['objetivo do aluno ate T00']);
    set('inputs', ['configuracao de ambiente', 'sessao local']);
    set('outputs', ['organismo inicializado', 'rota inicial']);
    out.tests.push('test/widget_test.dart');
  } else if (file.startsWith('lib/features/') || file.startsWith('lib/shared/') || file.startsWith('lib/sim/ui/')) {
    out.layer = 'UI';
    out.category = file.includes('/classroom/') ? 'ui-aula' : file.includes('/onboarding/') ? 'ui-entrada' : 'ui';
    set('contracts', ['sessao/aula', 'erro/falha']);
    set('stateMachines', ['sessao/aula', 'falha/retry']);
    set('inputs', ['view model', 'estado exposto por facade']);
    set('outputs', ['comandos para facade local', 'renderizacao']);
  } else if (file.startsWith('lib/sim/state/')) {
    out.layer = 'Motores pedagogicos';
    out.category = 'motor-pedagogico-estado';
    set('contracts', ['estado forte do aluno', 'avanco/advance-gate', 'item/camada/questao']);
    set('stateMachines', ['item', 'camada', 'questao', 'avanco']);
    set('officialPaths', ['resposta do aluno', 'proxima camada ou proximo item']);
    set('inputs', ['evidencia local', 'estado local']);
    set('outputs', ['estado forte', 'eventos canonicos']);
  } else if (file.startsWith('lib/sim/classroom/')) {
    out.layer = 'Motores pedagogicos';
    out.category = 'motor-aula-local';
    set('contracts', ['sessao/aula', 'item/camada/questao', 'avanco/advance-gate', 'erro/falha']);
    set('stateMachines', ['sessao/aula', 'item', 'camada', 'questao', 'avanco', 'falha/retry']);
    set('officialPaths', ['aula/pergunta', 'resposta do aluno', 'proxima camada ou proximo item']);
    set('inputs', ['estado local', 'material de aula', 'A/B/C+sinal']);
    set('outputs', ['feedback', 'proxima acao local', 'evento']);
  } else if (file.startsWith('lib/sim/lesson/')) {
    out.layer = 'Assistente local';
    out.category = 'orquestracao-aula-cache';
    set('contracts', ['T02/microaula/questao', 'cache/sync', 'visual/imagem', 'audio']);
    set('stateMachines', ['cache/sync', 'visual', 'audio', 'falha/retry']);
    set('officialPaths', ['aula/pergunta', 'audio', 'imagem', 'curriculo grande']);
    set('inputs', ['estado local', 'cache', 'ponte T02']);
    set('outputs', ['material pronto', 'janela viva']);
  } else if (file.startsWith('lib/sim/experience/')) {
    out.layer = 'Motores de conteudo';
    out.category = 'entrada-curriculo';
    set('contentEngines', ['t00', 't02']);
    set('contracts', ['T00/curriculo/mapa', 'T02/microaula/questao']);
    set('stateMachines', ['curriculo', 'sessao/aula', 'cache/sync']);
    set('officialPaths', ['objetivo do aluno ate T00', 'curriculo', 'curriculo grande', 'aula/pergunta']);
    set('inputs', ['objetivo', 'perfil', 'anexos processados']);
    set('outputs', ['perfil', 'curriculo', 'primeira aula']);
  } else if (file.startsWith('lib/sim/auxiliary/')) {
    out.layer = 'Motores de conteudo';
    out.category = 'fluxos-apoio-local';
    set('contentEngines', ['doubt', 'review', 'recovery', 'warmup-amparo']);
    set('contracts', ['revisao/recuperacao/duvida', 'T02/microaula/questao']);
    set('stateMachines', ['duvida', 'revisao', 'recuperacao', 'falha/retry']);
    set('officialPaths', ['revisao/recuperacao/duvida']);
    set('inputs', ['estado local', 'pergunta do aluno', 'fila local']);
    set('outputs', ['resposta auxiliar', 'evento local']);
  } else if (file.startsWith('lib/sim/media/')) {
    out.layer = 'Motores de conteudo';
    out.category = 'midia';
    set('contracts', ['visual/imagem', 'audio', 'erro/falha']);
    set('stateMachines', ['visual', 'audio', 'falha/retry']);
    set('officialPaths', ['audio', 'imagem']);
    set('inputs', ['material de aula', 'preferencias']);
    set('outputs', ['estado visual', 'estado de audio']);
  } else if (file.startsWith('lib/sim/cloud/')) {
    out.layer = 'Persistencia/cache/sync';
    out.category = 'sync-cloud';
    set('contracts', ['cache/sync', 'estado forte do aluno']);
    set('stateMachines', ['cache/sync', 'falha/retry']);
    set('inputs', ['estado local', 'sessao autenticada']);
    set('outputs', ['fila offline', 'cofre remoto']);
  } else if (file.startsWith('lib/sim/external_ai/')) {
    out.layer = 'Ponte com servidor';
    out.category = 'ponte-servidor';
    set('contracts', ['T00/curriculo/mapa', 'T02/microaula/questao', 'audio', 'visual/imagem', 'erro/falha']);
    set('stateMachines', ['falha/retry']);
    set('officialPaths', ['objetivo do aluno ate T00', 'aula/pergunta', 'audio', 'imagem']);
    set('inputs', ['DTO publico', 'sessao/token quando houver']);
    set('outputs', ['DTO validado do servidor']);
  } else if (file.startsWith('lib/sim/billing/')) {
    out.layer = 'Ponte com servidor';
    out.category = 'billing';
    set('contracts', ['erro/falha']);
    set('stateMachines', ['falha/retry']);
    set('inputs', ['sessao', 'pacote de creditos']);
    set('outputs', ['saldo', 'checkout', 'deleção de conta']);
  } else if (file.startsWith('lib/sim/placement/')) {
    out.layer = 'Motores pedagogicos';
    out.category = 'placement';
    set('contracts', ['estado forte do aluno', 'item/camada/questao']);
    set('stateMachines', ['sessao/aula', 'questao', 'falha/retry']);
    set('officialPaths', ['objetivo do aluno ate T00', 'curriculo']);
    set('inputs', ['curriculo', 'respostas de diagnostico']);
    set('outputs', ['posicionamento local']);
  } else if (file.startsWith('lib/session/')) {
    out.layer = 'Assistente local';
    out.category = 'session-state';
    set('contracts', ['sessao/aula', 'estado forte do aluno', 'erro/falha']);
    set('stateMachines', ['sessao/aula', 'falha/retry']);
    set('officialPaths', ['objetivo do aluno ate T00']);
    set('inputs', ['UI', 'storage local']);
    set('outputs', ['estado de sessao', 'comandos locais']);
  } else if (file.startsWith('lib/sim/organism/')) {
    out.layer = 'Assistente local';
    out.category = 'organismo';
    set('contracts', ['sessao/aula', 'cache/sync', 'erro/falha']);
    set('stateMachines', ['sessao/aula', 'cache/sync', 'falha/retry']);
    set('officialPaths', officialPaths);
    set('inputs', ['configuracao', 'storage', 'clientes oficiais']);
    set('outputs', ['organismo integrado']);
  } else if (file.startsWith('lib/sim/core/')) {
    out.layer = 'Motores pedagogicos';
    out.category = 'regras-de-dominio';
    set('contracts', ['avanco/advance-gate', 'item/camada/questao']);
    set('stateMachines', ['avanco', 'questao']);
    set('officialPaths', ['resposta do aluno', 'proxima camada ou proximo item']);
    set('inputs', ['resposta', 'sinal']);
    set('outputs', ['evidencia normalizada']);
  } else if (file.startsWith('lib/sim/config/') || file.startsWith('lib/core/')) {
    out.layer = 'Assistente local';
    out.category = 'config-core';
    set('contracts', ['erro/falha']);
    set('inputs', ['dart-define']);
    set('outputs', ['configuracao segura']);
  } else if (file.startsWith('lib/sim/localization/')) {
    out.layer = 'Assistente local';
    out.category = 'localization';
    set('contracts', ['sessao/aula']);
    set('stateMachines', ['sessao/aula']);
    set('inputs', ['idioma']);
    set('outputs', ['locale normalizado']);
  } else if (file.startsWith('lib/sim/modules/')) {
    out.layer = 'Assistente local';
    out.category = 'contratos-modulares';
    set('contracts', contracts);
    set('stateMachines', stateMachines);
    set('officialPaths', officialPaths);
    set('inputs', ['contratos de orgaos']);
    set('outputs', ['interfaces canônicas']);
  }

  if (file.includes('learning_decision_engine')) set('engines', ['learning-decision-engine', 'advance-engine', 'domain-rules']);
  if (file.includes('mastery_truth_engine')) set('engines', ['mastery-truth-engine']);
  if (file.includes('lesson_answer_feedback')) set('engines', ['error-classifier']);
  if (file.includes('lesson_answer_progress_controller')) set('engines', ['advance-engine', 'mastery-truth-engine', 'domain-rules']);
  if (file.includes('student_learning_state')) set('engines', ['domain-rules']);
  if (file.includes('student_lesson_executor')) set('engines', ['learning-decision-engine']);
  if (file.includes('student_experience_t00') || file.includes('bootstrap')) set('contentEngines', ['t00']);
  if (file.includes('student_experience_t02') || file.includes('lesson_orchestrator') || file.includes('complete_lesson')) set('contentEngines', ['t02']);
  if (file.includes('doubt')) set('contentEngines', ['doubt']);
  if (file.includes('review')) set('contentEngines', ['review']);
  if (file.includes('recovery')) set('contentEngines', ['recovery']);
  if (file.includes('amparo')) set('contentEngines', ['warmup-amparo']);

  const directTests = {
    'lib/sim/state/learning_decision_engine.dart': ['test/sim_state_engines_test.dart', 'test/classroom_phase_test.dart'],
    'lib/sim/state/mastery_truth_engine.dart': ['test/state_store_truth_engine_test.dart', 'test/m5_mastery_evidence_contract_test.dart'],
    'lib/sim/classroom/lesson_answer_progress_controller.dart': ['test/m1_answer_signal_contract_test.dart', 'test/classroom_phase_test.dart'],
    'lib/sim/lesson/student_lesson_material_service.dart': ['test/first_lesson_ready_window_test.dart', 'test/classroom_phase_test.dart'],
    'lib/sim/lesson/lesson_material_cache.dart': ['test/m12_offline_cache_sync_contract_test.dart'],
    'lib/sim/cloud/cloud_queue.dart': ['test/m12_offline_cache_sync_contract_test.dart'],
    'lib/sim/external_ai/sim_server_ai_clients.dart': ['test/external_ai_clients_test.dart'],
    'lib/features/classroom/chat_aula_screen.dart': ['test/normal_lesson_full_completion_flow_test.dart', 'test/classroom_phase_test.dart'],
  };
  out.tests.push(...(directTests[file] || ['test/sim_app_architecture_shape_test.dart']));
  if (text.includes('/api/')) set('officialPaths', ['objetivo do aluno ate T00', 'aula/pergunta']);
  return out;
}

const files = walk(libRoot)
  .map((full) => path.relative(root, full).replace(/\\/g, '/'))
  .sort()
  .map(classify);

function lineCount(file) {
  const text = fs.readFileSync(path.join(root, file), 'utf8');
  if (text.isEmpty) return 0;
  return text.endsWith('\n') ? text.split(/\r?\n/).length - 1 : text.split(/\r?\n/).length;
}

const counts = {
  files: files.length,
  layers: Object.fromEntries(layers.map((layer) => [layer, files.filter((file) => file.layer === layer).length])),
  dartLines: files.reduce((sum, file) => sum + lineCount(file.path), 0),
};

const inventory = {
  schemaVersion: 1,
  generatedFor: 'SIM NV App Fase 1 de enquadramento na Planta-Mae',
  sourceOfTruth: [
    '/root/sim-work/sim-api/PLANTA-MAE-SERVIDOR.txt',
    '/root/sim-work/sim-api/LEI_CONSTRUTIVA_MIGRACAO_SIM_ATUAL_PARA_SIM_NV_IDEAL.txt',
    '/root/sim-work/sim-api/docs/docs/fase-zero/sim-nv/CONJUNTO_C_ESPECIFICACAO_SIM_NV.md',
    '/root/SIM-SCROL/docs/PLANTA-SIM-FLUTTER-10X-APP-DE-ENSINO.txt',
    '/root/SIM-SCROL/docs/CONTRATO_SYNC_OFFLINE_CACHE.md',
    '/root/SIM-SCROL/docs/SIM_FLUTTER_CONTRATO_FIO.md',
    '/root/SIM-SCROL/docs/SIM_MOTOR_DE_TRAVESSIA_DIRETRIZ_CONSTRUTIVA.md',
  ],
  layers,
  pedagogicalEngines,
  contentEngines,
  formalContracts: contracts,
  contractAreas,
  stateMachines,
  officialPaths,
  routeWhitelist,
  forbiddenRuntimeRoutes,
  files,
  counts,
  phase2Backlog: [
    'Reduzir LabSession/LabSessionFlows para fachada ainda mais fina sem alterar fluxo vivo.',
    'Fundir contratos duplicados entre sim/classroom e sim/lesson onde a fronteira ainda e difusa.',
    'Migrar persistencia sensivel de SharedPreferences para storage local protegido onde aplicavel.',
    'Dividir onboarding/preparacao por componentes menores se voltar a crescer.',
  ],
};

fs.mkdirSync(path.join(root, 'tool'), { recursive: true });
fs.mkdirSync(path.join(root, 'docs'), { recursive: true });
fs.writeFileSync(
  path.join(root, 'tool/sim_nv_app_architecture_inventory.json'),
  `${JSON.stringify(inventory, null, 2)}\n`,
);

const rows = files.map((file) =>
  `| \`${file.path}\` | ${file.layer} | ${file.category} | ${file.logicalOwner} | ${file.contracts.join(', ') || '-'} | ${file.stateMachines.join(', ') || '-'} | ${file.officialPaths.join(', ') || '-'} | ${file.tests.join(', ')} | ${file.decision} |`,
);

const md = [
  '# Inventario Arquitetural Do App SIM NV',
  '',
  'Este inventario classifica todos os arquivos Dart vivos de `lib/` contra a Planta-Mae e o Conjunto C. Ele e acompanhado pelo arquivo machine-readable `tool/sim_nv_app_architecture_inventory.json` e pelo gate `test/sim_app_architecture_shape_test.dart`.',
  '',
  '## Resumo',
  '',
  `- Arquivos Dart classificados: ${counts.files}`,
  `- Linhas Dart em lib: ${counts.dartLines}`,
  ...Object.entries(counts.layers).map(([layer, count]) => `- ${layer}: ${count}`),
  `- Motores pedagogicos declarados: ${pedagogicalEngines.length}`,
  `- Motores de conteudo declarados: ${contentEngines.length}`,
  `- Contratos formais declarados: ${contracts.length}`,
  `- Areas contratuais cobertas: ${contractAreas.length}`,
  `- Maquinas de estado declaradas: ${stateMachines.length}`,
  `- Caminhos oficiais declarados: ${officialPaths.length}`,
  '',
  '## Regras De Classificacao',
  '',
  '- UI renderiza, captura comandos e chama facades locais; nao decide pedagogia.',
  '- Assistente local orquestra sessao, rota, entrada, organismo e comandos internos.',
  '- Motores pedagogicos decidem com evidencias locais, sem IA direta.',
  '- Motores de conteudo chamam T00/T02 e fluxos auxiliares por contratos, sem governar dominio.',
  '- Persistencia/cache/sync guarda estado e filas; nao decide dominio.',
  '- Ponte com servidor contem clientes e DTOs autorizados; nao decide toque simples.',
  '',
  '## Arquivos Classificados',
  '',
  '| Arquivo | Camada | Categoria | Dono logico | Contratos | Maquinas | Caminhos | Teste/prova | Decisao |',
  '| --- | --- | --- | --- | --- | --- | --- | --- | --- |',
  ...rows,
  '',
  '## Backlog Fase 2',
  '',
  ...inventory.phase2Backlog.map((item) => `- ${item}`),
  '',
].join('\n');

fs.writeFileSync(path.join(root, 'docs/sim_nv_app_architecture_inventory.md'), md);
