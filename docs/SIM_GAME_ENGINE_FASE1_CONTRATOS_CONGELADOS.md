# SIM Game Engine - Fase 1 - Contratos Congelados

Status: registro documental preparatorio.
Escopo: congelar contratos vigentes antes de qualquer migracao para Game Engine.
Autoridade: este documento nao cria autoridade superior nova, nao revoga contrato vigente e nao autoriza alteracao de prompts, adendos, T00, T02, N3, custo, credito, rate limit, gate financeiro, tela de aula ou runtime atual.

Legenda obrigatoria:

- CONTRATO VIGENTE: regra ja sustentada por fonte local lida nesta auditoria.
- PROPOSTA FUTURA: direcao desejada para Game Engine, ainda nao implementada como contrato de runtime neste documento.
- RISCO/PENDENCIA: ponto que precisa de decisao, implementacao ou prova futura.

## 1. Autoridades normativas vigentes

1. Constituicao dos Contratos SIM.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:3-7`.
   Fonte espelhada do servidor: `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md:3-7`.
   Regra congelada: e a autoridade maxima sobre contratos, leis, prompts, rotas, orgaos, cache, midia, estado, custo, IA e UI.

2. Hierarquia unica.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:17-25`.
   Regra congelada: seguranca, custo, privacidade e protecao anti-loop ficam acima de aula textual, estado, T00/T02, midia, cache e UI.

3. Lei de Protecao das Travas Anti-Loop do SIM NV.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:1-14`.
   Fonte espelhada do servidor: `/root/sim-work/sim-api/docs/migracao-sim-nv/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:1-14`.
   Regra congelada: as travas anti-loop sao seguranca operacional, custo, privacidade, estabilidade e continuidade pedagogica, tao protegidas quanto prompts, T00, T02 e contrato N3.

4. Planta-Mae do SIM Ideal.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:32-54`.
   Regra congelada: SIM nao e chatbot, nao e quiz, IA gera conteudo, software governa fluxo, aluno responde, sistema valida, Pai supervisiona, aluno so avanca com evidencia real, primeira aula chega rapido e texto nao espera imagem/audio/cache pesado.

5. Evento A - Concordancia com a Planta-Mae.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:15-30`.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:151-176`.
   Regra congelada: o app atual precisa preservar idioma, objetivo, curriculo, texto pronto, resposta A/B/C, sinal 1/2/3, tentativa, validacao, estado, feedback, revisao, recuperacao e preparacao de proximo material.

6. Evento A - Fases Executivas.
   Fonte: `docs/EVENTO-A-FASES-EXECUTIVAS-PARA-VERDADE.md:21-63`.
   Regra congelada: fase parcial nao pode declarar o todo verdadeiro sem implementacao, testes, evidencia e sem quebrar outro motor.

7. Inventario dos Guardas Antigasto do servidor.
   Fonte: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md:1-4`.
   Regra congelada: o inventario registra mecanismos reais de protecao contra gasto indevido e nao autoriza alteracao de prompt/adendo/N3.

## 2. Hierarquia de autoridade

Status: CONTRATO VIGENTE.

1. Em conflito entre contratos, vence o contrato da camada mais alta; na mesma camada, vence o contrato mais novo marcado como VIGENTE; em empate, a execucao deve falhar com erro de governanca.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:9-15`.
   Fonte espelhada do servidor: `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md:9-15`.

2. A hierarquia vigente e: seguranca/custo/privacidade/protecao anti-loop; aula textual; estado/progresso/dominio/avanco; T00/T02 e contratos de IA textual; imagem/audio/midia/anexos; cache/janela/fila/pre-carregamento; UI/layout/experiencia visual.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:17-25`.
   Fonte espelhada do servidor: `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md:17-25`.

3. Servidor e autoridade para IA, custo, rate limit, idempotencia, single-flight, validacao de T00/T02/N3 e midia; app e executor de aula textual, audio, imagem, estado local, resposta do aluno e fluidez.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`.
   Fonte espelhada do servidor: `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`.

## 3. Fluxos pedagogicos atuais que o Game Engine precisa preservar

Status: CONTRATO VIGENTE.

1. Fluxo minimo constitucional: abrir app, ler/restaurar estado, pedir idioma/objetivo quando faltar, interpretar objetivo, confirmar plano, preparar curriculo inicial pequeno, preparar primeira aula, mostrar texto assim que pronto, mostrar imagem opcional, receber A/B/C, receber sinal 1/2/3, registrar tentativa, validar acerto/confianca, decidir proximo passo, salvar estado, mostrar feedback, agendar revisao/recuperacao e preparar proximo material.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:151-176`.

2. Microitem pedagogico com identidade, marker/itemId, texto, camada, pergunta, alternativas, gabarito, historico, dominio e relacao com revisao/recuperacao.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:180-196`.

3. Resposta sempre em duas dimensoes: alternativa A/B/C e sinal 1/2/3.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:197-210`.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:488-507`.

4. Feedback e decisao pedagogica precisam diferenciar acerto seguro, acerto com duvida, acerto inseguro, erro com certeza, erro com duvida, erro inseguro, erro repetido, acerto apos erro e falsa maestria.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:211-223`.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:1311-1319`.

5. Advance Gate depende de evidencia, nao de elogio da IA, fim de tela, clique rapido ou acerto unico.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:227-265`.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:1281-1308`.

6. Revisao e recuperacao sao obrigatorias quando ha risco pedagogico.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:293-328`.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:1323-1337`.

7. Duvida e sala auxiliar, preserva item, camada, pergunta, resposta escolhida, contexto, progresso principal e nao apaga tentativa nem avanca item.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:332-346`.

8. Timeline/conversa preserva explicacao, imagem, enunciado, alternativas, escolha, sinais, feedback, duvida, avancar, erro/retry, loading e historico morto.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:349-370`.

9. Imagem continua pedagogica, associada ao item/camada correto, sem bloquear texto e preservada no historico.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:393-408`.

10. Audio continua opcional e nao bloqueia aula, progresso, texto, pergunta ou resposta.
    Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:411-423`.

11. Estado do aluno preserva perfil, idioma, objetivo, curriculo, item/camada, progresso, tentativas, historico, pendencias, revisoes, recuperacoes, eventos, snapshots e materiais preparados.
    Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:444-469`.

12. Cache e subordinado: nao e fonte da verdade, nao apaga progresso, nao substitui estado, nao ressuscita material antigo, nao gera aula duplicada e nao cresce sem limite.
    Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:530-549`.

## 4. Travas anti-gasto existentes no app

Status: CONTRATO VIGENTE.

1. Janela dopaminica viva limitada a 15 slots reais, com corte/auditoria `DOPAMINE_WINDOW_REQUEST_CAPPED`.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:23-31`.
   Fonte de teste: `test/anti_loop_protection_contract_test.dart:72-81`.

2. Midia de slot deduplicada por identidade forte incluindo `lessonLocalId`, `marker`, `itemIdx`, `layer` e `mediaType`; item `queued` ou `running` nao pode ser enfileirado de novo.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:28-31`.
   Fonte de teste: `test/anti_loop_protection_contract_test.dart:77-82`.

3. Idempotency key de T02 enviada pelo app ao servidor.
   Fonte de teste: `test/guardas_antigasto_sentinel_test.dart:97-105`.
   Fonte de teste: `test/anti_loop_protection_contract_test.dart:83-86`.

4. Respeito a `Retry-After` no cliente.
   Fonte de teste: `test/guardas_antigasto_sentinel_test.dart:107-112`.
   Fonte de teste: `test/anti_loop_protection_contract_test.dart:83-90`.

5. Worker da janela pronta com tentativas finitas: `readyWindowWorkerMaxAttempts = 3` e `readyWindowWorkerMaxJobsPerDrain = 15`; `max_attempts: null` e retries ilimitados sao proibidos.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:55-64`.
   Fonte de teste: `test/anti_loop_protection_contract_test.dart:87-94`.

6. Job com falha permanente permanece deduplicado e nao se auto-recria.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:58-59`.
   Fonte de teste: `test/anti_loop_protection_contract_test.dart:91-94`.

7. Timers/workers de aula anterior sao cancelados ao trocar aula, encerrar sessao ou descartar organismo.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:60-62`.
   Fonte de teste: `test/anti_loop_protection_contract_test.dart:101-103`.

8. Cache de material e `LessonReadinessResolver` existem como execucao/subordinacao, sem virar autoridade final.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:31-37`.
   Fonte de teste: `test/guardas_antigasto_sentinel_test.dart:114-128`.

9. Fila offline transacional e storage Drift preservam dedupe/sync sem retornar a SharedPreferences como autoridade.
   Fonte: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md:27-28`.
   Fonte de teste: `test/guardas_antigasto_sentinel_test.dart:129-152`.

10. Arquivos protegidos do app incluem `LabSession`, fluxos de sessao, worker, material service, provider, midia e testes.
    Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:66-90`.

## 5. Travas anti-gasto existentes no servidor

Status: CONTRATO VIGENTE.

1. `AiCostProtectionGate` e gate financeiro autoritativo antes de chamada paga de IA, com idempotencia, single-flight, cache de resultado, orcamento por minuto/hora, teto global, circuit breaker por 429 e respeito a `Retry-After`.
   Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:39-48`.
   Fonte: `/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js:128-318`.

2. Gate distribuido em producao usa Redis/controle atomico para evitar duplo processamento entre instancias.
   Fonte: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md:8-11`.
   Fonte: `/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js:320-424`.

3. Rate limit das rotas `ai`, `image` e `audio` aplicado antes do despacho da rota.
   Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:37-38`.
   Fonte de teste: `/root/sim-work/sim-api/test/server_distributed_rate_limit_contract.test.js:9-24`.

4. `/api/complete-lesson` passa pelo `AiCostProtectionGate` antes de chamar T02; 429 nao dispara retry imediato.
   Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:43-46`.
   Fonte: `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js:223-230`.
   Fonte: `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js:244-258`.

5. Router oficial do servidor e fachada sobre `composition_root`, preservando `__protectedRoutes`, `__budgetRoutes` e grupos canonicos.
   Fonte: `/root/sim-work/sim-api/src/app/router.js:1-10`.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:27-37`.

6. Ledger de creditos em producao e transacional/Postgres; store local e apenas desenvolvimento/teste.
   Fonte: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md:14-17`.
   Fonte: `/root/sim-work/sim-api/src/credits/credits-store.js:8-20`.
   Fonte: `/root/sim-work/sim-api/src/credits/postgres-credits-ledger.js:39-77`.

7. Reserva, captura, release/refund e compra de credito sao idempotentes.
   Fonte: `/root/sim-work/sim-api/src/credits/credits-store.js:42-86`.
   Fonte: `/root/sim-work/sim-api/src/credits/postgres-credits-ledger.js:92-189`.
   Fonte de teste: `/root/sim-work/sim-api/test/credits_concurrency_contract.test.js:11-42`.

8. Imagem usa validacao de payload, offer/idempotency key, rate limit, cache, registro de operacao, reserva/captura/release de credito e replay sem nova cobranca.
   Fonte: `/root/sim-work/sim-api/src/media/image-controller.js:39-100`.
   Fonte: `/root/sim-work/sim-api/src/media/image-controller.js:133-302`.

9. Audio usa rate limit, cache, idempotencia, `AUDIO_ALREADY_RUNNING`, custo configuravel, reserva/captura/release quando houver custo e nao cobra replay.
   Fonte: `/root/sim-work/sim-api/src/media/audio-controller.js:57-120`.
   Fonte: `/root/sim-work/sim-api/src/media/audio-controller.js:121-181`.

10. Logs de custo e auditoria diaria nao podem vazar prompt, aula, chave, payload sensivel ou conteudo do aluno.
    Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:34-36`.
    Fonte: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md:20`.

## 6. Lista explicita de intocaveis

Status: CONTRATO VIGENTE para os itens com fonte local. Quando a fonte for a ordem desta Fase 1, o item fica limitado a esta fase documental e nao vira lei superior.

1. Prompts, adendos, T00, T02 e contrato N3 sao intocaveis.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:12-14`.
   Fonte de teste: `test/guardas_antigasto_sentinel_test.dart:156-177`.
   Fonte de teste servidor: `/root/sim-work/sim-api/test/guardas-antigasto-sentinel.test.js:109-117`.

2. Nenhuma fase pode remover, enfraquecer, contornar ou tornar opcional trava anti-loop sem autorizacao explicita do usuario.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:16-21`.

3. E proibido remover/contornar `AiCostProtectionGate`, reduzir limites/TTLs/circuit breaker/idempotencia/single-flight/`Retry-After`, criar caminho paralelo pago fora do gate, permitir provedor pago fora da politica oficial, reintroduzir polling remoto ou retry ilimitado.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:92-120`.

4. `LabSession`, `LessonRuntimeEngine` e tela de aula atual nao devem ser trocados nesta fase.
   Status: regra operacional desta Fase 1, derivada da ordem de escopo recebida; nao altera contrato vigente.
   Fonte de protecao relacionada: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:66-90`.
   Fonte de teste relacionada: `/root/sim-work/sim-api/test/ai_cost_protection_mandatory_law.test.js:37-45`.

5. Servidor continua juiz de IA, custo, rate limit, idempotencia, single-flight, contratos T00/T02/N3 e geracao/validacao de midia.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-124`.

6. App continua executor: mostra aula textual, toca audio, renderiza imagem, preserva estado, permite resposta, mantem fluidez e funciona com internet ruim quando ha material pronto.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:126-130`.

## 7. Contrato minimo futuro da `PedagogicalCard`

Status: PROPOSTA FUTURA, nao contrato vigente de runtime. Deve ser subordinada a Constituicao, Planta-Mae, T00/T02/N3 e travas anti-gasto.

Uma `PedagogicalCard` futura so podera representar conteudo ja fabricado/validado pelo servidor ou material local ja valido. Ela deve conter, no minimo:

1. Identidade: `cardId`, `lessonLocalId`, `itemId` ou `marker`, `itemIdx`, `layer`, versao e hash/contrato de origem.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:180-196`.
   Fonte: `/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js:75-113`.

2. Conteudo pedagogico pronto: explicacao, pergunta, alternativas A/B/C, gabarito A/B/C, justificativas/feedback local, referencias quando necessarias e `visual_trigger`/midia opcional quando existir.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:451-485`.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:1255-1267`.
   Fonte: `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js:45-95`.

3. Evidencia necessaria para runtime local: camada, historico minimo, regras locais de resposta, possiveis decisoes permitidas e eventos a emitir.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:202-210`.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:227-256`.

4. Flags honestas de disponibilidade: texto pronto ou invalido; imagem/audio `not_needed`, `pending`, `ready` ou `failed`; anexos associados quando houver; nenhuma midia bloqueia texto.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:451-465`.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:393-423`.

5. Proibicao: a card nao pode conter prompt bruto, adendo bruto, N3 editavel, segredo, payload sensivel, regra de cobranca ou decisao final de custo.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`.
   Fonte: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md:1-4`.

## 8. Contrato minimo futuro do `Microdeck`

Status: PROPOSTA FUTURA, nao contrato vigente de runtime.

Um `Microdeck` futuro deve ser um conjunto pequeno e valido de `PedagogicalCard`s prontas, sem autoridade de IA/custo. Deve conter:

1. Identidade do deck: `microdeckId`, objetivo/curriculo/item de origem, versao, `generatedAt`, origem servidor/cache e lista ordenada de cards.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:420-448`.

2. Limite e subordinacao: deve respeitar janela viva/cache limitado; nao pode crescer sem limite nem substituir estado.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:25-27`.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:530-549`.

3. Prontidao honesta: deck so e jogavel se houver card valida. Sem carta valida, nao existe botao falso de resposta/avanco.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:1255-1267`.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:31-37`.

4. Midia opcional: imagem/audio/anexos podem acompanhar cards, mas falha de midia nao bloqueia aula textual nem progresso local quando texto/pergunta estao validos.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:393-423`.

5. Proibicao: deck nao chama IA, nao cobra, nao cria ledger, nao substitui router servidor, nao cria endpoint novo e nao decide dominio sem evidencia.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:227-265`.

## 9. Contrato minimo futuro do `LocalGameRuntime`

Status: PROPOSTA FUTURA, nao contrato vigente de runtime.

O `LocalGameRuntime` futuro deve executar cartas prontas de forma local, instantanea e subordinada:

1. Entrada: `PedagogicalCard` valida ou `Microdeck` com card valida; estado local atual; historico/evidencias existentes.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:444-469`.

2. Acoes locais permitidas: renderizar explicacao/pergunta/alternativas, receber A/B/C, receber sinal 1/2/3, calcular acerto contra gabarito pronto, produzir feedback local pronto, registrar tentativa, emitir evento, decidir avanco local quando carta seguinte valida existe.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:151-176`.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:917-940`.

3. Acoes proibidas: chamar IA em clique, cobrar em clique, reservar/capturar credito em clique, alterar prompt/adendo/N3, criar material pedagogico novo como autoridade, tratar cache/historico/UI como fonte de verdade.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:92-120`.

4. Sem carta valida, nao ha botao falso: runtime deve mostrar estado honesto de carregamento, indisponibilidade, retry seguro ou acao de duvida conforme fluxo atual, sem simular material inexistente.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:1247-1253`.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:584-598`.

5. Avanco/dominio: runtime pode produzir evidencia, mas dominio final exige regras do software/Advance Gate e historico; acerto unico nao e dominio.
   Status: PROPOSTA FUTURA, nao contrato vigente.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:227-265`.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:1281-1308`.

## 10. Contrato minimo futuro do `PedagogicalEventLog`

Status: PROPOSTA FUTURA quando ligado ao Game Engine; a obrigacao de event log e CONTRATO VIGENTE.

O `PedagogicalEventLog` futuro deve registrar eventos pedagogicos e tecnicos relevantes sem virar autoridade superior ao estado validado.

1. Eventos minimos: perfil, interpretacao, curriculo, lesson text requested/ready, imagem, audio, resposta, sinal, avanco, dominio, fraqueza, revisao, reforco, sync, cache tecnico e erro.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:472-499`.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:1991-2017`.

2. Schema minimo: id, tipo, payload, timestamp, origem, versao antes e versao depois quando aplicavel.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:501-509`.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:2020-2034`.

3. Eventos de clique devem conter marker, layer, letra, sinal, correct e timestamp.
   Status: CONTRATO VIGENTE quanto ao registro de tentativa; PROPOSTA FUTURA quanto ao nome `PedagogicalEventLog`.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:202-210`.

4. Historico e replay, nao autoridade. Historico antigo permanece visivel, morto e intocavel.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:349-370`.

5. Logs nao podem expor prompts, chaves, payload sensivel ou conteudo indevido do aluno.
   Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:34-36`.
   Fonte: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md:20`.

## 11. Prova de que clique A/B/C e 1/2/3 nunca podem chamar IA nem cobrar

Status: CONTRATO VIGENTE quanto a separacao entre clique/resposta local, validacao por software, servidor como juiz financeiro e proibicao de caminho pago fora do gate. Status: PROPOSTA FUTURA quanto ao desenho exato do Game Engine.

1. Regra: clique A/B/C e sinal 1/2/3 sao eventos/respostas do aluno, nao missao de IA.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:197-210`.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:217-234`.

2. Regra: software valida alternativa, gabarito, sinal, tempo e padrao de erro; Answer Validator produz evidencia, nao chamada de Tutor.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:929-940`.

3. Regra: servidor e juiz final para IA/custo; app nao cria gasto sem servidor e nao decide contrato de IA.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`.

4. Regra: qualquer chamada paga de IA precisa passar pelo `AiCostProtectionGate`; criar caminho paralelo pago fora do gate e proibido.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:39-48`.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:106-111`.

5. Regra: ledger de credito so pode reservar/capturar/liberar em operacao financeira idempotente de servidor; clique pedagogico local nao e operacao financeira.
   Fonte: `/root/sim-work/sim-api/src/credits/credits-store.js:42-86`.
   Fonte: `/root/sim-work/sim-api/src/credits/postgres-credits-ledger.js:92-189`.

6. Conclusao congelada: no Game Engine futuro, A/B/C e 1/2/3 devem ser tratados como computacao local sobre carta pronta. Se uma fase futura precisar chamar IA ou cobrar a partir desses cliques, deve parar e pedir auditoria/autorizacao explicita, pois toca custo/gate financeiro/trava protegida.
   Status: PROPOSTA FUTURA para a forma "carta pronta"; CONTRATO VIGENTE para a obrigacao de nao criar gasto fora do servidor/gate.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:106-111`.

## 12. Criterios para futuras fases nao quebrarem o app

Status: CONTRATO VIGENTE quando sustentado por Constituicao/leis/testes; PROPOSTA FUTURA quando falar especificamente do Game Engine ainda nao implementado.

1. Nenhuma fase futura pode alterar prompts, adendos, T00, T02, N3 ou textos enviados para imagem/N3 sem autorizacao explicita e escopo proprio.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:12-21`.

2. Nenhuma fase futura pode remover/enfraquecer `AiCostProtectionGate`, idempotencia, single-flight, Retry-After, rate limit, ledger de credito, auditoria ou testes anti-gasto.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:92-120`.

3. Servidor fabrica conteudo e governa custo; app executa carta pronta, joga localmente, preserva estado e nao decide custo.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`.

4. App deve continuar rapido: primeira aula e texto atual tem prioridade sobre imagem, audio, curriculo gigante, cache pesado, sync e relatorios.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:373-390`.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:1906-1944`.

5. Midia continua opcional: anexos, duvida com anexo, imagem e audio continuam existindo, mas midia nao bloqueia aula textual.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:393-423`.

6. Estado/dominio precisa de evidencia estruturada; cache, historico e UI sao subordinados.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:31-37`.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:444-469`.

7. Sem carta valida nao existe botao falso, tentativa falsa, feedback falso ou avanco falso.
   Fonte: `PLANTA-MAE DO SIM IDEAL.txt:1255-1267`.
   Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:258-265`.

8. Qualquer afirmacao futura sem fonte clara deve ser marcada como "Status: proposta para fase futura, nao contrato vigente".
   Fonte: regra anti-alucinacao desta Fase 1 recebida nesta ordem; nao cria autoridade tecnica superior.

## 13. Checklist de testes para toda fase futura

No app Flutter:

1. `flutter analyze --no-pub`
2. `flutter test test/guardas_antigasto_sentinel_test.dart test/anti_loop_protection_contract_test.dart`
3. `git diff --check`
4. `git status --short`

No servidor:

1. `node test/guardas-antigasto-sentinel.test.js`
2. `node test/ai_cost_protection_mandatory_law.test.js`
3. `node test/credits_concurrency_contract.test.js`
4. `node test/server_distributed_rate_limit_contract.test.js`
5. `git status --short`

Se a fase futura tocar area protegida com autorizacao explicita, tambem rodar os testes adicionais citados pela lei anti-loop.
Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:122-141`.

## 14. Congelamento arquitetural para o Game Engine futuro

Status: PROPOSTA FUTURA, nao contrato vigente de runtime. As fontes abaixo sustentam os limites constitucionais usados para esta direcao; nao provam que `PedagogicalCard`, `Microdeck`, `LocalGameRuntime` ou `PedagogicalEventLog` ja existam implementados.

1. Servidor fabrica conteudo.
2. Servidor governa custo.
3. App joga carta pronta.
4. Clique nunca chama IA.
5. Clique nunca cobra.
6. Qualificador 1/2/3 e local e instantaneo.
7. Feedback e local e instantaneo quando ja veio na carta validada.
8. Avanco e local quando ha carta pronta e evidencia suficiente.
9. Sem carta valida, nao existe botao falso.
10. Anexos continuam existindo.
11. Duvida com anexo continua existindo.
12. Imagem e audio continuam existindo.
13. Midia e opcional e nao bloqueia aula.
14. Historico e replay, nao autoridade.
15. Cache e subordinado.
16. Estado/dominio precisa de evidencia.
17. Prompts, adendos, T00, T02 e N3 sao intocaveis sem fase/autorizacao propria.

Fontes centrais: `docs/CONSTITUICAO_CONTRATOS_SIM.md:17-37`, `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`, `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:151-176`, `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:393-423`, `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:530-549`, `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:92-120`.

## 15. Riscos e pendencias marcadas

1. `PedagogicalCard`, `Microdeck`, `LocalGameRuntime` e `PedagogicalEventLog` sao nomes de contrato futuro neste documento, nao entidades de runtime vigente provadas nesta auditoria.
   Status: RISCO/PENDENCIA.
   Fonte: auditoria local por busca textual em `/root/SIM-SCROL` e `/root/sim-work/sim-api` nesta Fase 1; sem arquivo de producao vigente encontrado como autoridade para esses nomes.

2. Este documento nao autoriza fase futura a editar custo, prompt, gate, credito, rate limit, T00, T02, N3, adendos, `LabSession`, tela de aula ou servidor. Se uma fase futura exigir isso, deve parar e pedir autorizacao explicita conforme a lei anti-loop.
   Status: CONTRATO VIGENTE quanto as travas protegidas; regra operacional desta Fase 1 quanto ao escopo de escrita.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:16-21`.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:122-152`.
