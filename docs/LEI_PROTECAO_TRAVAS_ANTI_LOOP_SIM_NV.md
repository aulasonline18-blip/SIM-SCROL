# Lei de Protecao das Travas Anti-Loop do SIM NV

Codigo: LPTAL-1
Versao: 1.0
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

## Arquivos protegidos

As travas acima vivem principalmente nestes arquivos:

- `lib/sim/lesson/dopamine_ready_window_engine.dart`
- `lib/sim/media/student_lesson_media_service.dart`
- `test/first_lesson_ready_window_test.dart`
- `/root/sim-work/sim-api/src/media/audio-controller.js`
- `/root/sim-work/sim-api/src/app/router.js`
- `/root/sim-work/sim-api/test/media_visual_n3_contract.test.js`
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

## Excecao permitida

Uma alteracao nesses pontos so pode acontecer se todas as condicoes abaixo forem
verdadeiras:

1. O usuario autorizou explicitamente a mudanca nas travas anti-loop.
2. A autorizacao nomeia o grupo protegido `anti-loop-protection`.
3. A implementacao explica antes da edicao o que sera alterado e por que a trava
   continua equivalente ou mais forte.
4. Os testes de contrato anti-loop sao mantidos ou reforcados.
5. `flutter analyze`, `flutter test`, `node test/media_visual_n3_contract.test.js`,
   `node test/protected_files_gate.test.js`, `node test/server_size_budget_contract.test.js`
   e `npm test` passam quando aplicavel.

## Regra para janelas futuras

Se uma janela futura receber tarefa que toque midia, audio, imagem, cache, janela
dopaminica, prefetch, retry, rate limit, roteador do servidor ou auditoria de IA,
ela deve primeiro ler esta lei.

Se a tarefa exigir mexer nas travas protegidas, a janela deve parar, explicar o
impacto e pedir autorizacao explicita. Sem essa autorizacao, a janela deve escolher
outro caminho que preserve integralmente as travas.

## Criterio de aceite

O SIM so esta conforme esta lei quando:

- as travas continuam no codigo;
- os testes continuam provando as travas;
- o manifesto protegido do servidor reconhece `anti-loop-protection`;
- nenhuma mudanca em arquivo protegido passa sem autorizacao rastreavel;
- o aluno nunca paga o custo de loop tecnico com espera, erro repetido, gasto
  duplicado, uso indevido de IA ou travamento da aula.
