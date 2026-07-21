# Lei de Protecao das Travas Anti-Loop do SIM NV

Codigo: LPTAL-1
Versao: 1.1
Status: Normativo constitucional

## Finalidade

Esta lei protege as travas que impedem o SIM NV de entrar em loops de IA, midia,
audio, imagem, janela dopaminica, prefetch, retry ou reprocessamento de slot.

Essas travas sao tao protegidas quanto prompts, T00, T02 e contrato N3. Elas nao
sao otimizacao. Elas sao seguranca operacional, custo, privacidade, estabilidade
e continuidade pedagogica.

## Regra superior

Nenhuma janela, fase, agente, refatoracao, migracao, polimento visual, melhoria
de performance, correcao de bug ou ajuste de arquitetura pode remover, enfraquecer,
contornar ou tornar opcional uma trava anti-loop sem autorizacao explicita do
usuario.

## Travas constitucionalmente protegidas

1. A janela dopaminica textual deve ser limitada aos 15 slots reais.
2. Pedido acima do limite deve ser cortado e auditado com
   `DOPAMINE_WINDOW_REQUEST_CAPPED`.
3. Midia de aula deve usar identidade forte por aula/slot, incluindo
   `lessonLocalId`, `marker`, `itemIdx`, `layer` e `mediaType`.
4. Midia ja `queued` ou `running` nao pode ser enfileirada de novo para o mesmo
   slot vivo.
5. Audio ja em geracao no servidor deve responder `AUDIO_ALREADY_RUNNING` e nao
   chamar IA novamente.
6. Auditoria diaria de chamadas reais de IA/midia deve continuar existindo em
   `.data/ai-usage-daily.json`, sem prompt, aula, chave, payload sensivel ou
   conteudo do aluno.
7. Rate limit de rotas `ai`, `image` e `audio` deve continuar sendo aplicado
   antes do despacho da rota.
8. O `AiCostProtectionGate` e o portao financeiro autoritativo antes de chamada
   paga de IA. Ele deve continuar existindo com idempotencia, single-flight,
   cache de resultado, orcamento por minuto/hora, teto global, circuit breaker
   por 429 e respeito a `Retry-After`.
9. `/api/complete-lesson` deve passar pelo `AiCostProtectionGate` antes de
   chamar T02. Pedido repetido do mesmo slot nao pode executar IA novamente.
10. `429` de provedor ou servidor nao pode disparar retry imediato. Retry
    permitido precisa usar backoff exponencial com jitter ou `Retry-After`.
11. O servidor e o portao financeiro. O app pode colaborar com idempotency key,
    fila e espera, mas o custo nunca pode depender apenas do app.
12. A entrada da primeira aula pode solicitar a abertura remota uma unica vez
    por operacao viva. E proibido polling remoto por timer para tentar acelerar
    a percepcao de espera do aluno.
13. Chamadas concorrentes para abrir a mesma aula devem compartilhar uma unica
    operacao em andamento. E proibido criar uma segunda chamada T02 enquanto a
    primeira ainda estiver viva.
14. O worker da janela pronta deve ter `readyWindowWorkerMaxAttempts = 3` e
    `readyWindowWorkerMaxJobsPerDrain = 15`. `max_attempts: null`, `while (true)`
    e qualquer retry ilimitado sao constitucionalmente proibidos.
15. Job que atingiu falha permanente deve permanecer deduplicado pela mesma
    chave de idempotencia. Ele nao pode ser recriado automaticamente.
16. Somente o worker da aula ativa pode continuar agendando preparo. Troca de
    aula, encerramento da sessao ou descarte do organismo deve cancelar timers,
    limpar drains pendentes e impedir novos retries.
17. Retry so pode existir para erro explicitamente retryable, dentro do limite
    finito, respeitando `Retry-After` e o teto de espera ja protegido.

## Arquivos protegidos

As travas acima vivem principalmente nestes arquivos:

- `lib/sim/lesson/dopamine_ready_window_engine.dart`
- `lib/features/session/lab_session.dart`
- `lib/features/session/lab_session_entry_flows.dart`
- `lib/features/session/lab_session_flows.dart`
- `lib/sim/lesson/ready_window_worker.dart`
- `lib/sim/lesson/student_lesson_material_service.dart`
- `lib/sim/organism/sim_organism_provider.dart`
- `lib/sim/media/student_lesson_media_service.dart`
- `test/first_lesson_ready_window_test.dart`
- `/root/sim-work/sim-api/src/media/audio-controller.js`
- `/root/sim-work/sim-api/src/app/router.js`
- `/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js`
- `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js`
- `/root/sim-work/sim-api/src/config/env.js`
- `/root/sim-work/sim-api/src/app/media-cache.js`
- `/root/sim-work/sim-api/test/media_visual_n3_contract.test.js`
- `/root/sim-work/sim-api/test/ai_cost_protection_mandatory_law.test.js`
- `/root/sim-work/sim-api/test/t02_aula_auxiliares_contract.test.js`
- `/root/sim-work/sim-api/docs/migracao-sim-nv/protected-files.manifest.json`
- `/root/sim-work/sim-api/scripts/check-protected-files.js`
- `/root/sim-work/sim-api/test/protected_files_gate.test.js`

## Proibicoes

E proibido:

1. Remover limite de 15 slots.
2. Aumentar limite de janela sem autorizacao explicita.
3. Remover deduplicacao de midia por identidade de slot.
4. Trocar identidade forte por chave parcial.
5. Remover `mediaType` da chave de midia.
6. Permitir duplicata quando job esta `queued` ou `running`.
7. Remover `AUDIO_ALREADY_RUNNING`.
8. Remover ou reduzir a auditoria diaria de uso de IA/midia.
9. Remover testes que provam essas travas.
10. Substituir a trava por comentario, TODO, log, loader ou fallback visual.
11. Remover, contornar, tornar opcional ou enfraquecer `AiCostProtectionGate`.
12. Reduzir limites, TTLs, circuit breaker, idempotencia, single-flight ou
    `Retry-After` sem autorizacao extrema e teste novo.
13. Criar caminho paralelo que chame IA paga sem passar pelo gate financeiro.
14. Permitir OpenAI, Gemini, imagem, audio, anexo ou qualquer provedor pago fora
    da politica oficial do servidor e fora do gate financeiro.
15. Reintroduzir polling remoto, `while (true)`, `max_attempts: null` ou qualquer
    mecanismo sem limite matematico de chamadas e tentativas.
16. Permitir que uma chamada concorrente contorne a operacao em andamento.
17. Recriar automaticamente job marcado como `failed` com a mesma idempotency key.
18. Manter timer de retry ou worker de aula anterior depois de troca, dispose ou
    encerramento da sessao.
19. Aumentar os limites 3 tentativas ou 15 jobs por drain sem decisao formal e
    rastreavel da mesa diretora e novos testes que provem protecao equivalente
    ou superior.

## Excecao permitida

Uma alteracao nesses pontos so pode acontecer se todas as condicoes abaixo forem
verdadeiras:

1. O usuario autorizou explicitamente a mudanca nas travas anti-loop.
2. A autorizacao nomeia o grupo protegido `anti-loop-protection`.
3. A implementacao explica antes da edicao o que sera alterado e por que a trava
   continua equivalente ou mais forte.
4. Os testes de contrato anti-loop sao mantidos ou reforcados.
5. `flutter analyze`, `flutter test`, `node test/ai_cost_protection_mandatory_law.test.js`,
   `node test/media_visual_n3_contract.test.js`,
   `node test/protected_files_gate.test.js`, `node test/server_size_budget_contract.test.js`
   e `npm test` passam quando aplicavel.
6. Para reducao de protecao, a autorizacao deve nomear explicitamente:
   `anti-loop-protection`, `ai-cost-protection-gate`, o arquivo tocado e a razao
   de a mudanca continuar mais forte ou equivalente.
7. Qualquer reducao, remocao ou aumento de limite exige decisao formal,
   discutida e rastreavel da mesa diretora. Autorizacao generica para refatorar,
   otimizar, corrigir ou melhorar performance nao autoriza tocar nestas travas.

## Regra para janelas futuras

Se uma janela futura receber tarefa que toque midia, audio, imagem, cache, janela
dopaminica, prefetch, retry, rate limit, roteador do servidor, auditoria de IA,
provedor de IA, modelo de IA, `AiCostProtectionGate`, idempotencia, single-flight,
orcamento ou circuit breaker, ela deve primeiro ler esta lei.

Se a tarefa exigir mexer nas travas protegidas, a janela deve parar, explicar o
impacto e pedir autorizacao explicita. Sem essa autorizacao, a janela deve escolher
outro caminho que preserve integralmente as travas.

## Criterio de aceite

O SIM so esta conforme esta lei quando:

- as travas continuam no codigo;
- os testes continuam provando as travas;
- `AiCostProtectionGate` continua antes de `/api/complete-lesson`;
- T02 continua sem retry imediato em 429;
- o app continua enviando idempotency key e respeitando `Retry-After`;
- o manifesto protegido do servidor reconhece `anti-loop-protection`;
- primeira aula usa operacao unica, sem polling remoto;
- worker possui no maximo 3 tentativas e 15 jobs por drain;
- falha permanente nao se auto-recria e timers sao cancelados no encerramento;
- nenhuma mudanca em arquivo protegido passa sem autorizacao rastreavel;
- o aluno nunca paga o custo de loop tecnico com espera, erro repetido, gasto
  duplicado, uso indevido de IA ou travamento da aula.
