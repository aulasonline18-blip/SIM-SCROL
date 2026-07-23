# SIM Game Engine — Planta Final De Conclusão

## 1. Status E Autoridade

Regra: este documento é decisão documental de conclusão do SIM Game e não supera a Constituição SIM. Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:7`.

Regra: em conflito, vale esta ordem: Constituição SIM; leis/travas anti-loop e anti-gasto; contratos vigentes de prompts/T00/T02/N3; Planta-Mãe e Evento A quando não conflitarem com segurança/custo; Fase 1 contratos congelados; classificação documental; esta Planta Final como decisão de conclusão; código vigente; documentos históricos somente como referência subordinada. Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:9-25`; Fonte local: `docs/SIM_GAME_ENGINE_CLASSIFICACAO_DOCUMENTAL.md:7-24`; Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: documento histórico, matriz Web/App, SIM NV antigo ou paridade Web nunca governa o SIM Game contra essa hierarquia. Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:14-15`; Fonte local: `docs/SIM_GAME_ENGINE_CLASSIFICACAO_DOCUMENTAL.md:164-198`.

## 2. Regra Suprema

Regra: o servidor fabrica conteúdo e governa IA, custo, rate limit, idempotência, single-flight, contrato de saída, T00/T02/N3 e mídia. Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-124`.

Regra: o app joga cartas prontas, executa estado local, recebe A/B/C e 1/2/3, mostra feedback local quando a carta já trouxe feedback e não cria custo. Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:126-130`; Fonte local: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:338-363`; Fonte local: `lib/sim/game/local_game_runtime.dart:42-85`.

Regra: clique A/B/C é local; clique 1/2/3 é local; clique não chama IA; clique não cobra; clique não decide custo. Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:197-210`; Fonte local: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:338-363`.

## 3. Proibições Definitivas

Regra: é proibido tocar prompts, adendos, T00, T02, N3, texto de imagem, AiCostProtectionGate, crédito, ledger, rate limit, Retry-After, single-flight e proteções anti-loop sem autorização explícita, escopo próprio e teste novo. Fonte local: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:12-21`; Fonte local: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:92-141`.

Regra: é proibido criar caminho paralelo pago fora do gate financeiro oficial. Fonte local: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:106-111`.

Regra: é proibido tratar UI, histórico, cache, fallback ou elogio da IA como autoridade de domínio. Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:31-37`; Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:258-265`; Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:530-549`.

## 4. O Que O Servidor É

Regra: o servidor é juiz final de IA, custo, rate limit, idempotência, single-flight, contratos T00/T02/N3, geração/validação de mídia, privacidade de logs e erros públicos. Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-124`.

Regra: o servidor pode gerar resultado caro, guardar cópia técnica temporária até ACK e manter auditoria leve. Fonte local: `/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js:390-440`; Fonte local: `/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js:590-620`.

Regra: desde a Fase 11, qualquer endpoint de microdeck já deve preservar idempotência, single-flight, Retry-After, rate limit, ACK e travas anti-gasto existentes. Fonte local: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:37-48`; Fonte local: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md:7-12`; Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

## 5. O Que O Servidor Não É

Regra: o servidor não é biblioteca pedagógica do SIM Game, não é autoridade para reuso pedagógico entre alunos e não é banco permanente de cartas. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: o servidor não autoriza cache pedagógico permanente, acervo de questões, busca semântica para reaproveitar questão ou produto de reuso pedagógico global. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: o servidor não pode exigir que o cliente confie cegamente na IA. Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:1474-1479`.

## 6. O Que O App É

Regra: o app é executor local: mostra aula textual, renderiza imagem, toca áudio honestamente, preserva estado local, permite resposta do aluno e funciona com internet ruim quando há material pronto. Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:126-130`; Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:584-598`.

Regra: o app joga `PedagogicalCard` válida com `contentHash`, `serverSignature`, explicação, pergunta, A/B/C, gabarito, feedback, qualificadores 1/2/3 e mídia opcional. Fonte local: `lib/sim/game/pedagogical_card.dart:42-86`; Fonte local: `lib/sim/game/pedagogical_card.dart:93-121`.

Regra: avanço local só existe quando há próxima carta válida no microdeck; sem próxima carta, o estado vira `needsMicrodeck`. Fonte local: `lib/sim/game/game_state_store.dart:138-187`.

## 7. O Que O App Não É

Regra: o app não chama IA, não cobra, não decide custo, não guarda segredo de assinatura e não cria contrato de IA. Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`; Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:187-194`.

Regra: o app não inventa progresso, não trata cache como verdade final e não mantém rota oficial divergente do servidor. Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:126-130`.

Regra: se não houver carta válida, o app não mostra A/B/C, não mostra botão falso e não fabrica material. Fonte local: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:389-391`; Fonte local: `lib/sim/game/game_state_store.dart:23-27`.

## 8. O Que A UI É

Regra: a UI mostra telas, recebe cliques, recebe A/B/C e 1/2/3, exibe aula, feedback, revisão, amparo e estado simples de progresso. Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:217-233`.

Regra: `GameCardView` renderiza carta pronta por `GameRuntimeController`, mostra explicação, pergunta, A/B/C, qualificadores após resposta, feedback local e mídia leve opcional. Fonte local: `lib/sim/game/ui/game_card_view.dart:31-207`.

Regra: mídia é opcional e não bloqueia texto, pergunta, resposta, feedback ou progresso local quando a carta textual é válida. Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:393-423`; Fonte local: `lib/sim/game/ui/game_card_view.dart:97-102`.

## 9. O Que A UI Não É

Regra: a UI não decide aprendizagem final, domínio, custo, IA, servidor, retry ou assinatura. Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:231-233`; Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:31-37`.

Regra: a UI não chama servidor no toque, não chama sync no toque, não simula avanço e não mascara falta de carta com botão falso. Fonte local: `lib/sim/game/ui/game_card_view.dart:210-238`; Fonte local: `lib/sim/game/game_state_store.dart:146-149`.

Regra: feedback visual não é domínio final. Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:211-223`; Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:929-940`.

## 10. ACK Técnico De Entrega

Regra: ACK técnico é permitido porque evita custo duplicado da mesma operação recente. Fonte local: `/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js:312-318`; Fonte local: `/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js:525-530`.

Regra: ACK significa: servidor gerou resultado caro; servidor guardou cópia técnica temporária; app confirmou recebimento; servidor apaga corpo pesado; servidor mantém auditoria leve conforme contrato técnico. Fonte local: `/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js:424-440`; Fonte local: `/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js:602-620`.

Regra: ACK não significa reuso pedagógico, banco de cartas, biblioteca, acervo, cache global, busca, recomendação, reaproveitamento entre alunos ou reaproveitamento entre contextos pedagógicos. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: mesma operação recente pode ser reentregue tecnicamente até ACK; conteúdo pedagógico não pode ser reutilizado entre alunos/contextos como produto do SIM Game. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

## 11. Microdeck Pequeno

Regra: microdeck é pequeno, limitado, auditável e protegido contra gasto. Fonte local: `lib/sim/game/microdeck.dart:12-24`; Fonte local: `lib/sim/game/microdeck.dart:80-89`.

Regra: microdeck não é janela 15, não é prefetch pago amplo, não é deck gigante, não é acervo, não é banco e não autoriza geração antecipada ilimitada. Fonte local: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:25-27`; Fonte local: `docs/SIM_GAME_ENGINE_CLASSIFICACAO_DOCUMENTAL.md:218-225`; Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: microdeck existe para fluidez local imediata; o tamanho exato deve seguir a fase executiva vigente e seus testes. Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:1020-1031`; Fonte local: `lib/sim/game/microdeck.dart:22`.

Regra: qualquer preparo acima do pequeno exige justificativa, idempotência, single-flight, Retry-After, ACK, teto de custo e teste. Fonte local: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:37-48`; Fonte local: `/root/sim-work/sim-api/docs/LEI_GUARDAS_ANTIGASTO_SIM.md:23-37`; Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

## 12. Assinatura E Hash

Regra: carta válida precisa de `contentHash` e `serverSignature`. Fonte local: `lib/sim/game/pedagogical_card.dart:57-60`; Fonte local: `lib/sim/game/pedagogical_card.dart:114-115`.

Regra: `serverSignature` pertence ao contrato de integridade da carta; segredo de assinatura nunca fica no app; app só pode validar com chave pública, assinatura verificável ou contrato equivalente seguro. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: assinatura/hash não autorizam cobrança no app e não transformam cache em autoridade pedagógica. Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`; Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:530-549`.

Regra: se assinatura/hash forem inválidos, o app não deve mostrar A/B/C. Status: DECISÃO APROVADA NESTE MARCO, implementação técnica nas Fases 11 e 12.

## 13. Histórico, Cache E Domínio

Regra: histórico é replay, não autoridade; histórico antigo permanece visível, morto e intocável. Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:349-370`.

Regra: cache é subordinado, não fonte da verdade; cache não apaga progresso, não substitui estado, não ressuscita material antigo, não gera aula duplicada e não cresce sem limite. Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:530-549`; Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:2050-2052`.

Regra: domínio exige evidência estruturada; acerto único não é domínio; domínio final segue política vigente e evidência válida. Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:227-265`; Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:1281-1308`.

Regra: reconciliação registra evidência; reconciliação não chama IA; reconciliação não cobra; reconciliação não abre T02; reconciliação não cria carta; reconciliação não decide domínio definitivo sem regra normativa vigente. Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:472-509`; Fonte local: `lib/sim/game/game_sync_client.dart:204-328`; Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: a palavra reforço pode existir como linguagem pedagógica subordinada, mas não cria órgão, sala, rota, store ou política nova; os destinos normativos permitidos permanecem revisão, dúvida, recuperação, amparo, domínio e histórico. Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:174-183`; Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:247-256`; Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

## 14. Modo Sombra E Rollback

Regra: modo sombra é obrigatório antes da integração real do SIM Game como fluxo principal. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: rollback é obrigatório antes da integração real do SIM Game como fluxo principal. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: modo sombra e rollback não autorizam tocar prompts, adendos, T00, T02, N3, custo, gate, ledger, rate limit, Retry-After ou single-flight. Fonte local: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:143-152`.

## 15. Performance Obrigatória

Regra: performance real deve ser medida antes de o SIM Game virar fluxo principal. Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:49-51`; Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:1046-1049`; Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: primeira aula, texto atual e validação de resposta têm prioridade sobre imagem, áudio, currículo maior, sincronização pesada, relatórios e cache pesado. Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:373-390`; Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:1906-1944`.

Regra: é proibido prometer performance sem medição em aparelho fraco e internet ruim. Fonte local: `PLANTA-MAE DO SIM IDEAL.txt:1931-1944`; Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

## 16. Fases Restantes Aprovadas

Regra: a ordem aprovada é: 1. Marco 0 — Planta Constitucional Final; 2. Fase 11 — Microdeck Endpoint com Hash/Assinatura Contratual; 3. Fase 12 — Validação Local de Assinatura/Hash; 4. Fase 13 — App Microdeck Client; 5. Fase 14 — Adapter do Conteúdo Atual; 6. Fase 15 — Reconciliação de Eventos; 7. Fase 16 — Modo Sombra; 8. Fase 17 — UI Polida com Dado Real; 9. Fase 18 — Integração com Flag/Rollback; 10. Fase 19 — Backpressure/Escala; 11. Fase 20 — Performance Aparelho Fraco; 12. Fase 21 — Limpeza Legado; 13. Fase 22 — Release. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: Fase 19 não é a primeira fase de backpressure; ela aprofunda backpressure e escala. Fonte local: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:37-48`; Fonte local: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md:7-12`; Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: Fase 11 já deve preservar idempotência, single-flight, Retry-After, rate limit, ACK e travas anti-gasto existentes. Fonte local: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:37-48`; Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: Fase 21 só pode acontecer depois de modo sombra, integração, rollback e performance passarem. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: Fase 22 é a única fase de APK/AAB/Play Store. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

## 17. Termos Mortos E Proibidos

Regra: são proibidos como arquitetura de runtime do SIM Game: card-store pedagógico global; reuse-policy pedagógica; banco de questões; banco de cartas; acervo pedagógico; biblioteca de cartas; catálogo de questões; embedding para reuso pedagógico; busca semântica para reuso pedagógico; similaridade para reaproveitar questão; reuso entre alunos; cache pedagógico global; cache permanente de experiências pedagógicas; servidor como biblioteca pedagógica. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: esses termos só podem aparecer em testes proibitivos, auditorias, documentos históricos ou explicações de proibição. Eles não podem aparecer como implementação, fase futura, rota, serviço, store, política ou runtime do SIM Game. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

Regra: ACK técnico, microdeck, cache técnico, histórico, reconciliação e assinatura/hash não reabilitam os termos mortos desta seção. Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

## 18. Critério Final De Aceite

Regra: o SIM Game só passa quando o aluno toca e a resposta local acontece sobre carta válida, sem IA no clique, sem custo no clique, sem botão falso, sem UI como autoridade e sem histórico/cache como autoridade. Fonte local: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:338-363`; Fonte local: `lib/sim/game/game_state_store.dart:58-187`; Fonte local: `lib/sim/game/domain_policy.dart:54-172`.

Regra: o aceite final exige modo sombra, rollback, medição de performance real, servidor limpo de loop de gasto e preservação de todas as travas anti-gasto. Fonte local: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:154-169`; Status: DECISÃO APROVADA NESTE MARCO, subordinada à Constituição e às travas anti-gasto.

## 19. Fontes

Fonte local: `docs/CONSTITUICAO_CONTRATOS_SIM.md`.

Fonte local: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md`.

Fonte local: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md`.

Fonte local: `docs/SIM_GAME_ENGINE_CLASSIFICACAO_DOCUMENTAL.md`.

Fonte local: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md`.

Fonte local: `PLANTA-MAE DO SIM IDEAL.txt`.

Fonte local: `lib/sim/game/pedagogical_card.dart`.

Fonte local: `lib/sim/game/microdeck.dart`.

Fonte local: `lib/sim/game/local_game_runtime.dart`.

Fonte local: `lib/sim/game/pedagogical_event.dart`.

Fonte local: `lib/sim/game/pedagogical_event_log.dart`.

Fonte local: `lib/sim/game/game_state_store.dart`.

Fonte local: `lib/sim/game/game_sync_client.dart`.

Fonte local: `lib/sim/game/game_runtime_controller.dart`.

Fonte local: `lib/sim/game/domain_policy.dart`.

Fonte local: `lib/sim/game/ui/game_card_view.dart`.

Fonte local: `lib/sim/game/ui/game_classroom_screen.dart`.

Fonte local: `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md`.

Fonte local: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md`.

Fonte local: `/root/sim-work/sim-api/docs/LEI_GUARDAS_ANTIGASTO_SIM.md`.

Fonte local: `/root/sim-work/sim-api/src/ai/ai-cost-protection-gate.js`.

O SIM Game estará pronto quando o aluno tocar e tudo responder localmente; o servidor apenas preparar, proteger, assinar, limitar custo e reconciliar; e nenhuma falha de retry, timeout, spam, escala ou instabilidade conseguir virar loop de gasto sem teto.
