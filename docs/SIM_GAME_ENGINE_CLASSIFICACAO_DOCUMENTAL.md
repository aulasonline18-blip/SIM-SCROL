# SIM Game Engine - Classificacao Documental

Status: documento de classificacao e protecao documental.
Escopo: Microfase 3.5, somente app Flutter `/root/SIM-SCROL`.
Autoridade: este documento nao cria nova Constituicao, nao revoga norma vigente, nao rebaixa norma vigente e nao autoriza tocar prompts, adendos, T00, T02, N3, custo, credito, rate limit, gate financeiro, servidor runtime, rotas, `LabSession`, `LessonRuntimeEngine` ou tela atual.

## 1. Regra de leitura

Status: CONTRATO VIGENTE quanto a hierarquia constitucional ja existente.

1. A Constituicao vence conflitos documentais.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:3-15`.
   Fonte espelhada: `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md:3-15`.

2. Seguranca, custo, privacidade e protecao anti-loop ficam acima de documentos antigos, paridade, relatorios de fase, cache, UI e pre-carregamento.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:17-25`.
   Fonte: `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md:17-25`.

3. Prompts, adendos, T00, T02, N3 e travas anti-loop sao protegidos. Nenhuma fase documental de SIM Game autoriza alteracao nesses pontos.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:9-21`.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:92-120`.

4. Documento historico nao e fonte de implementacao e teste antigo nao revive contrato rebaixado.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:9-15`.

5. Espelho, legado ou referencia comparativa nao pode voltar ao runtime por import, rota, instancia ou controller oficial.
   Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/CLASSIFICACAO_DE_LEGADOS_E_ESPELHOS.md:5-13`.
   Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/CLASSIFICACAO_DE_LEGADOS_E_ESPELHOS.md:30-39`.

## 2. Status usados neste documento

- CONTRATO VIGENTE: regra ja marcada como vigente por fonte constitucional/normativa local.
- PROPOSTA FUTURA: direcao de SIM Game ainda nao elevada a norma vigente.
- REFERENCIA COMPARATIVA: material util para comparacao/auditoria, sem ordem automatica de implementacao.
- HISTORICO: relatorio, checklist ou registro de fase; prova de contexto, nao autoridade nova.
- LEGADO/REMOVIDO: material ou runtime que nao pode reaparecer como caminho oficial sem nova autorizacao e alinhamento.
- SUBORDINADO: documento util apenas onde nao contradiz Constituicao, leis, contratos vigentes e escopo aprovado.
- RISCO/PENDENCIA: fonte insuficiente, conflito nao resolvido ou risco de uso errado.

## 3. Inventario documental executado

Status: CONTRATO VIGENTE apenas quanto ao fato da varredura local desta microfase.

- App: `rg --files docs > /tmp/sim_scroll_docs.txt` encontrou 141 entradas.
- Servidor: `rg --files docs > /tmp/sim_api_docs.txt` encontrou 71 entradas.
- Observacao: os arquivos foram inventariados, mas este documento classifica explicitamente apenas as autoridades e documentos perigosos lidos nesta microfase. Arquivo inventariado e nao citado individualmente aqui deve ser tratado como RISCO/PENDENCIA para SIM Game ate leitura propria.

## 4. Classificacoes centrais

Documento: `docs/CONSTITUICAO_CONTRATOS_SIM.md`
Classificacao: CONTRATO VIGENTE
Motivo: declara autoridade maxima sobre contratos, leis, prompts, rotas, orgaos, cache, midia, estado, custo, IA e UI.
Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:3-15`.
Risco se usado errado: tentar criar excecao local que escolha contrato inferior silenciosamente.
Pode governar SIM Game? sim
Observacao: nenhuma regra deste documento novo supera a Constituicao.

Documento: `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md`
Classificacao: CONTRATO VIGENTE
Motivo: copia espelhada obrigatoria no servidor, com mesmo escopo app/servidor.
Fonte: `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md:3-15`.
Risco se usado errado: criar divergencia entre app e servidor sobre autoridade.
Pode governar SIM Game? sim
Observacao: deve ser lida quando uma fase tocar contrato app/servidor.

Documento: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md`
Classificacao: CONTRATO VIGENTE
Motivo: protege travas anti-loop como seguranca operacional, custo, privacidade, estabilidade e continuidade pedagogica.
Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:1-21`.
Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:23-64`.
Risco se usado errado: confundir janela/preparo com permissao para gastar mais ou contornar gate.
Pode governar SIM Game? sim
Observacao: janela 15 vigente protege limite e anti-loop; nao autoriza gasto antecipado para SIM Game sem nova prova/autorizacao.

Documento: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md`
Classificacao: SUBORDINADO
Motivo: registra contratos atuais e propostas futuras sem criar autoridade superior nova.
Fonte: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:1-12`.
Fonte: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:416-438`.
Risco se usado errado: transformar desenho futuro (`PedagogicalCard`, `Microdeck`, `LocalGameRuntime`, `PedagogicalEventLog`) em norma vigente acima da Constituicao.
Pode governar SIM Game? parcial
Observacao: vale como congelamento preparatorio; regras especificas de Game Engine nele marcadas como futuras continuam PROPOSTA FUTURA.

Documento: `PLANTA-MAE DO SIM IDEAL.txt`
Classificacao: CONTRATO VIGENTE
Motivo: define principios pedagogicos centrais, software governando fluxo, IA sem dominio do estado e A/B/C + 1/2/3.
Fonte: `PLANTA-MAE DO SIM IDEAL.txt:24-54`.
Fonte: `PLANTA-MAE DO SIM IDEAL.txt:155-166`.
Fonte: `PLANTA-MAE DO SIM IDEAL.txt:170-197`.
Risco se usado errado: tratar SIM Game como quiz, gamificacao visual ou IA dona do progresso.
Pode governar SIM Game? sim
Observacao: subordinada a CCSIM-1 em conflitos operacionais, conforme `docs/CONSTITUICAO_CONTRATOS_SIM.md:39-63`.

Documento: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md`
Classificacao: CONTRATO VIGENTE, SUBORDINADO A CONSTITUICAO
Motivo: define estado-alvo constitucional do app, fluxo minimo e motor pedagogico por microitem.
Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:3-12`.
Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:151-176`.
Fonte: `docs/EVENTO-A-SIM-APP-100-CONCORDANCIA-PLANTA-MAE.md:180-223`.
Risco se usado errado: pular objetivo, curriculo, validacao, tentativa, sinal, estado ou decisao pedagogica.
Pode governar SIM Game? sim
Observacao: nao autoriza trocar UI/runtime atual fora de fase especifica e nunca supera CCSIM-1 em conflito operacional.

Documento: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md`
Classificacao: CONTRATO VIGENTE quanto ao inventario de protecoes; SUBORDINADO quanto a regra pedagogica.
Motivo: registra mecanismos reais que impedem gasto indevido e declara que nao cria regra pedagogica nem autoriza alteracao de prompt/adendo/N3.
Fonte: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md:1-4`.
Fonte: `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md:5-28`.
Risco se usado errado: usar inventario tecnico para autorizar mudanca pedagogica ou mexer em protegido.
Pode governar SIM Game? parcial
Observacao: governa protecao/custo como evidencia documental, nao fluxo pedagogico novo.

Documento: `/root/sim-work/sim-api/docs/migracao-sim-nv/CLASSIFICACAO_DE_LEGADOS_E_ESPELHOS.md`
Classificacao: CONTRATO VIGENTE como documento de classificacao; LEGADO/REMOVIDO quanto aos runtimes classificados.
Motivo: define que espelhos historicos/referencias nao sao caminho principal do servidor e nao podem voltar como runtime.
Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/CLASSIFICACAO_DE_LEGADOS_E_ESPELHOS.md:5-13`.
Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/CLASSIFICACAO_DE_LEGADOS_E_ESPELHOS.md:15-39`.
Risco se usado errado: reativar Web, warmup, doubt, mastery, review, recovery ou student-experience como runtime oficial escondido.
Pode governar SIM Game? sim
Observacao: a classificacao governa a leitura; os legados classificados por ela nao ganham permissao de voltar ao runtime.

## 5. Documentos perigosos obrigatorios

Documento: `/root/sim-work/sim-api/docs/docs/fase-zero/sim-nv/CONJUNTO_C_ESPECIFICACAO_SIM_NV.md`
Classificacao: SUBORDINADO
Motivo: especificacao ampla do SIM NV, com trechos offline-first, experiencia completa e referencia de 15 experiencias; tambem proibe copiar codigo antigo para producao.
Fonte: `/root/sim-work/sim-api/docs/docs/fase-zero/sim-nv/CONJUNTO_C_ESPECIFICACAO_SIM_NV.md:1-11`.
Fonte: `/root/sim-work/sim-api/docs/docs/fase-zero/sim-nv/CONJUNTO_C_ESPECIFICACAO_SIM_NV.md:23-37`.
Fonte: `/root/sim-work/sim-api/docs/docs/fase-zero/sim-nv/CONJUNTO_C_ESPECIFICACAO_SIM_NV.md:66-85`.
Fonte: `/root/sim-work/sim-api/docs/docs/fase-zero/sim-nv/CONJUNTO_C_ESPECIFICACAO_SIM_NV.md:161-186`.
Risco se usado errado: converter SIM Game em offline-first literal, cache de 15 experiencias completas ou copia automatica do Web/App antigo.
Pode governar SIM Game? parcial
Observacao: Conjunto C nao e lixo; e especificacao SIM NV. Para SIM Game, qualquer regra literal conflitante com CCSIM-1, anti-loop, Fase 1 ou escopo atual fica SUBORDINADA. Nao e ordem literal para implementar SIM Game.

Documento: `/root/sim-work/sim-api/MarcoFinalSimNv`
Classificacao: SUBORDINADO
Motivo: documento de desenho ideal de servidor, com rotas, filas e metas; a Constituicao do servidor ja o marca como VIGENTE subordinado a seguranca/custo.
Fonte: `/root/sim-work/sim-api/MarcoFinalSimNv:3-25`.
Fonte: `/root/sim-work/sim-api/MarcoFinalSimNv:87-108`.
Fonte: `/root/sim-work/sim-api/MarcoFinalSimNv:149-165`.
Fonte: `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md:53-63`.
Risco se usado errado: recriar rotas antigas ou filas genericas como caminho escondido fora do router/gate vigente.
Pode governar SIM Game? parcial
Observacao: nao escrever que "SIM Game vence MarcoFinal". Forma correta: qualquer forma antiga do Marco Final so vale subordinada aos contratos vigentes e ao escopo autorizado de SIM Game.

Documento: `/root/sim-work/sim-api/docs/migracao-sim-nv/RELATORIO_FINAL_PROPOSICAO_C.md`
Classificacao: HISTORICO
Motivo: relatorio final de fechamento operacional no escopo auditado da Tarefa 10/10.
Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/RELATORIO_FINAL_PROPOSICAO_C.md:1-18`.
Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/RELATORIO_FINAL_PROPOSICAO_C.md:60-75`.
Risco se usado errado: tratar "fechamento operacional" como autorizacao para alterar runtime protegido, prompts, T00/T02/N3 ou pular validacao atual.
Pode governar SIM Game? nao
Observacao: pode ser evidencia historica e lista de contratos encontrados, mas nao cria autoridade nova.

Documento: `/root/sim-work/sim-api/docs/migracao-sim-nv/CHECKLIST_FINAL_PROPOSICAO_C.md`
Classificacao: HISTORICO
Motivo: checklist de fechamento operacional por tarefas T1-T10, com provas e residuos conhecidos.
Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/CHECKLIST_FINAL_PROPOSICAO_C.md:1-11`.
Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/CHECKLIST_FINAL_PROPOSICAO_C.md:61-65`.
Risco se usado errado: transformar checklist concluido em permissao para reabrir escopo ou editar protegidos.
Pode governar SIM Game? nao
Observacao: usar como historico de auditoria, nao como plano automatico.

Documento: `docs/B-parity-200-differences-final-matrix.md`
Classificacao: REFERENCIA COMPARATIVA
Motivo: matriz final de diferencas SimWeb x SimApp, congelada em auditoria estatica, com categorias de paridade.
Fonte: `docs/B-parity-200-differences-final-matrix.md:1-27`.
Fonte: `docs/B-parity-200-differences-final-matrix.md:73-108`.
Risco se usado errado: transformar paridade Web em ordem de copiar Web, React, hooks, rotas ou server functions.
Pode governar SIM Game? parcial
Observacao: comparacao ajuda a identificar comportamentos, mas nao manda copiar Web.

Documento: `docs/B2-parity-250-additional-differences-final-matrix.md`
Classificacao: REFERENCIA COMPARATIVA
Motivo: matriz adicional de 250 diferencas, com regra explicita de nao transformar Flutter em React e nao copiar doenca do Web.
Fonte: `docs/B2-parity-250-additional-differences-final-matrix.md:1-7`.
Fonte: `docs/B2-parity-250-additional-differences-final-matrix.md:79-82`.
Risco se usado errado: importar strings/rotas/arquitetura Web em vez de preservar tipos e orgaos Dart.
Pode governar SIM Game? parcial
Observacao: serve como auditoria de diferencas; nao e ordem de implementacao literal.

Documento: `docs/sim-scroll-vs-sim-web-100-inferioridades-funcionais.md`
Classificacao: REFERENCIA COMPARATIVA
Motivo: auditoria de 100 pontos onde Web era superior, sem correcao aplicada nessa auditoria.
Fonte: `docs/sim-scroll-vs-sim-web-100-inferioridades-funcionais.md:1-20`.
Fonte: `docs/sim-scroll-vs-sim-web-100-inferioridades-funcionais.md:124-128`.
Risco se usado errado: tratar "Web superior" como ordem para copiar runtime Web ou reativar legado.
Pode governar SIM Game? parcial
Observacao: material comparativo para produto/auditoria; nao governa custo, IA, rotas ou Game Engine.

Documento: `docs/SIMWEB_SIMAPP_500_FUNCIONAMENTOS_CODIGO_MATRIX_2026_07_02.md`
Classificacao: REFERENCIA COMPARATIVA
Motivo: matriz funcional de 500 funcionamentos, comparando comportamento observavel e nao arquitetura.
Fonte: `docs/SIMWEB_SIMAPP_500_FUNCIONAMENTOS_CODIGO_MATRIX_2026_07_02.md:1-14`.
Fonte: `docs/SIMWEB_SIMAPP_500_FUNCIONAMENTOS_CODIGO_MATRIX_2026_07_02.md:145-155`.
Risco se usado errado: converter equivalencia funcional em obrigacao de copiar codigo, rotas ou arquitetura Web.
Pode governar SIM Game? parcial
Observacao: pode informar comportamento observavel; nao substitui Constituicao, anti-loop ou contratos vigentes.

## 6. Regras especificas para fases futuras do SIM Game

1. SIM Game online-first.
   Classificacao: PROPOSTA FUTURA
   Motivo: a ordem desta microfase pediu registrar a direcao, mas a fonte normativa local lida ainda marca o Game Engine como arquitetura futura, nao runtime vigente.
   Fonte: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:416-438`.
   Risco se usado errado: revogar indevidamente offline/cache atual sem autorizacao.
   Pode governar SIM Game? parcial, somente como direcao futura.
   Observacao: esta regra so podera virar vigente apos autorizacao e atualizacao normativa explicita.

2. Microdeck padrao do SIM Game = carta atual + 2 proximas.
   Classificacao: PROPOSTA FUTURA
   Motivo: nao foi encontrada fonte normativa vigente local aprovando exatamente o tamanho 3 como contrato atual.
   Fonte: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:254-281`.
   Risco se usado errado: tratar numero futuro como lei vigente ou mexer na janela atual.
   Pode governar SIM Game? parcial, somente como proposta futura.
   Observacao: para virar contrato, precisa fase propria, testes e decisao explicita.

3. SIM Game nao deve preparar 15 experiencias pagas por padrao.
   Classificacao: PROPOSTA FUTURA
   Motivo: a protecao vigente limita janela/worker e impede loop/gasto; nao ha fonte vigente que transforme o novo padrao SIM Game em regra implementada.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:23-64`.
   Fonte: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:254-281`.
   Risco se usado errado: usar a janela 15 antiga como autorizacao para gasto antecipado ou usar esta proposta para remover trava vigente.
   Pode governar SIM Game? parcial, somente como proposta futura.
   Observacao: janela 15 antiga permanece contrato de protecao do app atual; para SIM Game, qualquer preparo acima de carta atual + 2 deve ser gratuito, cacheado ou autorizado e provado por teste antes de virar vigente.

4. Carta assinada.
   Classificacao: PROPOSTA FUTURA
   Motivo: `PedagogicalCard` e contrato futuro/documental na Fase 1; assinatura de carta nao e autoridade vigente de runtime nesta microfase.
   Fonte: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:222-253`.
   Risco se usado errado: inventar criptografia, custo ou bloqueio sem fonte de runtime aprovada.
   Pode governar SIM Game? parcial, como proposta futura.
   Observacao: fases futuras devem citar fonte propria antes de implementar verificacao criptografica.

5. Servidor fabrica cartas; app joga carta pronta.
   Classificacao: PROPOSTA FUTURA quanto ao desenho "carta"; CONTRATO VIGENTE quanto a servidor governar IA/custo e app nao criar gasto.
   Motivo: a Constituicao ja separa servidor como juiz e app como executor; a forma "carta pronta" ainda e direcao do Game Engine.
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`.
   Fonte: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:416-438`.
   Risco se usado errado: criar endpoint novo de IA ou fazer app fabricar conteudo/custo no clique.
   Pode governar SIM Game? parcial.
   Observacao: app nunca chama IA/custo no clique e servidor continua juiz de IA, custo, rate limit, idempotencia e assinatura quando ela existir em contrato proprio.

## 7. Protecoes congeladas para leitura futura

Status: misto; cada item indica classificacao.

1. Constituicao vence tudo.
   Classificacao: CONTRATO VIGENTE
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:3-15`.

2. Seguranca, custo, privacidade e anti-loop vencem qualquer documento antigo.
   Classificacao: CONTRATO VIGENTE
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:17-25`.

3. Prompts, adendos, T00, T02 e N3 sao intocaveis sem autorizacao propria.
   Classificacao: CONTRATO VIGENTE
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:9-21`.

4. Documento de paridade Web e referencia comparativa, nao ordem de copiar Web.
   Classificacao: REFERENCIA COMPARATIVA
   Fonte: `docs/B2-parity-250-additional-differences-final-matrix.md:1-7`.

5. Conjunto C e especificacao SIM NV, nao ordem literal para SIM Game.
   Classificacao: SUBORDINADO
   Fonte: `/root/sim-work/sim-api/docs/docs/fase-zero/sim-nv/CONJUNTO_C_ESPECIFICACAO_SIM_NV.md:1-11`.

6. MarcoFinalSimNv e subordinado aos contratos vigentes quando falar em forma antiga.
   Classificacao: SUBORDINADO
   Fonte: `/root/sim-work/sim-api/docs/CONSTITUICAO_CONTRATOS_SIM.md:53-63`.

7. Janela 15 antiga nao autoriza gasto antecipado no SIM Game.
   Classificacao: CONTRATO VIGENTE quanto a anti-loop; PROPOSTA FUTURA quanto ao padrao SIM Game.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:23-64`.
   Fonte: `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md:92-120`.

8. App nunca chama IA/custo no clique.
   Classificacao: CONTRATO VIGENTE quanto a nao criar gasto fora do servidor/gate; PROPOSTA FUTURA quanto a execucao por carta.
   Fonte: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:338-363`.

9. Servidor continua juiz de IA, custo, rate limit, idempotencia e single-flight.
   Classificacao: CONTRATO VIGENTE
   Fonte: `docs/CONSTITUICAO_CONTRATOS_SIM.md:120-130`.

10. Legado morto nao pode voltar como runtime e rotas antigas nao podem reaparecer como caminho escondido.
    Classificacao: CONTRATO VIGENTE
    Fonte: `/root/sim-work/sim-api/docs/migracao-sim-nv/CLASSIFICACAO_DE_LEGADOS_E_ESPELHOS.md:30-39`.

## 8. Pendencias e riscos

1. Documentos inventariados mas nao lidos individualmente nesta microfase.
   Classificacao: RISCO/PENDENCIA
   Motivo: fonte insuficiente para classificacao individual.
   Evidencia temporaria de inventario: `/tmp/sim_scroll_docs.txt`, `/tmp/sim_api_docs.txt`.
   Risco se usado errado: obedecer documento antigo, relatorio fechado ou comparativo como se fosse norma vigente.
   Pode governar SIM Game? nao, ate leitura e classificacao especifica.
   Observacao: se uma fase futura depender de algum desses documentos, deve le-lo e classifica-lo com fonte local.

2. Microdeck padrao 3 cartas.
   Classificacao: RISCO/PENDENCIA e PROPOSTA FUTURA
   Motivo: pedido nesta microfase, mas sem fonte normativa vigente local que aprove o numero como contrato atual.
   Fonte: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:254-281`.
   Risco se usado errado: declarar aceito sem teste, custo ou autorizacao.
   Pode governar SIM Game? parcial, somente apos fase propria.
   Observacao: deve ser tratado como direcao futura, nao norma vigente.

3. Online-first do SIM Game.
   Classificacao: RISCO/PENDENCIA e PROPOSTA FUTURA
   Motivo: conflita potencialmente com documentos antigos offline-first; nao ha atualizacao normativa vigente neste arquivo.
   Fonte: `/root/sim-work/sim-api/docs/docs/fase-zero/sim-nv/CONJUNTO_C_ESPECIFICACAO_SIM_NV.md:66-85`.
   Fonte: `docs/SIM_GAME_ENGINE_FASE1_CONTRATOS_CONGELADOS.md:416-438`.
   Risco se usado errado: revogar cache/offline atual ou gastar online sem gate.
   Pode governar SIM Game? parcial, somente apos autorizacao explicita.
   Observacao: nao muda o app atual.
