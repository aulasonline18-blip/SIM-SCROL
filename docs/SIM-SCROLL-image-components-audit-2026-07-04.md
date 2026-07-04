# SIM Scroll - Auditoria do funil de imagem e componentes relacionados

Data: 2026-07-04
Repositorio: `/root/SIM-SCROL`
Escopo: SIM Flutter Scroll, funil de imagem gratuito/pago, renderizacao, cache, credito, UI e API.

## Regra de execucao aplicada

Nenhum prompt, T00, T02 ou adendo foi alterado.

Arquivos proibidos nesta missao:

- `/root/sim-work/sim-api/prompts/t00.txt`
- `/root/sim-work/sim-api/prompts/t02.txt`
- `/root/sim-work/sim-api/prompts/adendo_*.txt`

Quando um item depende de instrucao dentro desses arquivos, a classificacao usada foi `BLOQUEADO_PROMPT_PROIBIDO`, com observacao de que deve ser tratado em fase separada.

## Referencias comprovadas

- REF-WEB-ROUTER: `/root/sim-work/sim-web/src/lib/visual-router.functions.ts`
- REF-WEB-IMAGE: `/root/sim-work/sim-web/src/lib/gemini-image.functions.ts`
- REF-WEB-BLUEPRINT: `/root/sim-work/sim-web/src/cyber/blueprint-prompt.ts`
- REF-WEB-ORCH: `/root/sim-work/sim-web/src/cyber/lesson-orchestrator.impl.ts`
- REF-WEB-MEDIA: `/root/sim-work/sim-web/src/sim/lesson/studentLessonMediaService.ts`
- REF-WEB-OFFER: `/root/sim-work/sim-web/src/cyber/aula/useLessonPaidImageOffer.ts`
- REF-API-IMAGE: `/root/sim-work/sim-api/src/media/image-controller.js`
- REF-API-VISUAL: `/root/sim-work/sim-api/src/media/visual-route-controller.js`
- REF-API-VT: `/root/sim-work/sim-api/src/t02/visual-trigger-normalizer.js`
- REF-SCROLL-PIPELINE: `lib/sim/media/lesson_visual_pipeline.dart`
- REF-SCROLL-N2: `lib/sim/media/visual_router_n2.dart`
- REF-SCROLL-N3: `lib/sim/media/visual_router_n3.dart`
- REF-SCROLL-RENDER: `lib/sim/media/software_render_catalog.dart`
- REF-SCROLL-MATH: `lib/sim/media/math_templates/*`
- REF-SCROLL-ORCH: `lib/sim/lesson/lesson_orchestrator.dart`
- REF-SCROLL-LAB: `lib/features/session/lab_session.dart`
- REF-SCROLL-UI: `lib/features/classroom/aula_widgets.dart`, `lib/features/classroom/chat_aula_widgets.dart`, `lib/features/classroom/chat_aula_timeline_builder.dart`
- REF-SCROLL-CLIENT: `lib/sim/external_ai/sim_server_ai_clients.dart`
- REF-SCROLL-MEDIA: `lib/sim/media/student_lesson_media_service.dart`
- REF-TESTES: `test/media_phase_test.dart`, `test/first_lesson_ready_window_test.dart`, `test/external_ai_clients_test.dart`, `test/chat_aula_widgets_test.dart`, `test/finish_phase_test.dart`

## Resumo executivo

O funil vivo atual do SIM Flutter Scroll esta centralizado em:

`LessonOrchestrator -> LessonVisualPipeline -> LessonEventBus -> LabSession -> UI da aula`.

O caminho pago so gera imagem quando existe oferta real e aceite explicito. O caminho gratuito tenta SVG inline, math template, software render local e N2/N3 antes de publicar oferta paga. A UI nao inventa oferta paga por conta propria.

Alteracoes de codigo nesta rodada: 0.

Motivo: a auditoria nao encontrou correcao segura autorizada pela lei de referencia fora da area proibida de prompts. Itens de prompt/adendo foram registrados como bloqueados.

## Matriz de auditoria

| ID | Componente | Evidencia Scroll/API | Referencia | Status | Acao |
|---:|---|---|---|---|---|
| 1 | decisao se a questao precisa de imagem | `LessonVisualTrigger.needsImage`; `resolveVisual` faz skip se falso | REF-SCROLL-PIPELINE; REF-API-VT | OK | Preservado |
| 2 | classificacao pedagogica da necessidade | `pedagogicalNeed`; skip quando `none` | REF-SCROLL-PIPELINE; REF-API-VT | OK | Preservado |
| 3 | classificacao da complexidade visual | `complexity` enviado ao N3 | REF-SCROLL-PIPELINE; REF-SCROLL-N3 | OK | Preservado |
| 4 | classificacao do tipo de imagem | `visualType` + N2/N3 | REF-SCROLL-N2; REF-API-VISUAL | OK | Preservado |
| 5 | classificacao do dominio da imagem | `_lockedSvgSubjects`, `_organicHints` | REF-SCROLL-N2; REF-WEB-ROUTER | OK | Preservado |
| 6 | classificacao do assunto | `topic`, `imagePrompt`, enriquecimento com texto da aula | REF-SCROLL-ORCH | OK | Preservado |
| 7 | classificacao do nivel do aluno | `stableLang`, `academic` no contexto da aula; nivel entra pelo T02 | REF-SCROLL-ORCH | OK | Preservado |
| 8 | decisao entre SVG e IA | `VisualVerdict.svg/ai/ambiguous/noImage` | REF-SCROLL-N2; REF-SCROLL-N3 | OK | Preservado |
| 9 | decisao entre template e software | `math_template` antes de `SoftwareRenderCatalog` | REF-SCROLL-PIPELINE | OK | Preservado |
| 10 | decisao entre software e imagem pronta | local software antes de N3/IA; cache publica `CompleteLesson.imagem` | REF-SCROLL-PIPELINE; REF-SCROLL-ORCH | OK | Preservado |
| 11 | decisao entre imagem gratuita e paga | `allowPaidImages` + `acceptedOfferId` obrigatorio | REF-SCROLL-PIPELINE; REF-API-IMAGE | OK | Preservado |
| 12 | decisao entre geracao local e servidor | SVG/template/local no app; IA paga no servidor | REF-SCROLL-PIPELINE; REF-API-IMAGE | OK | Preservado |
| 13 | decisao entre reutilizar cache ou gerar | `LessonMaterialCache`, cache server por user/hash/aspect/prompt | REF-SCROLL-ORCH; REF-API-IMAGE | OK | Preservado |
| 14 | decisao de pre-geracao | `_scheduleImage`, `_imageQueue`, background sem cobrar pago | REF-SCROLL-ORCH | OK | Preservado |
| 15 | decisao de geracao sob demanda | `acceptPaidImageOffer` gera so apos aceite | REF-SCROLL-ORCH; REF-WEB-OFFER | OK | Preservado |
| 16 | selecao do template | `tryRenderMathTemplate`, aliases | REF-SCROLL-MATH | OK | Preservado |
| 17 | selecao do SVG | SVG inline, math, local software, N3 SVG | REF-SCROLL-PIPELINE | OK | Preservado |
| 18 | selecao do blueprint | `buildPromptForTrigger`/`buildNaturalImagePrompt` | REF-SCROLL-PIPELINE; REF-WEB-BLUEPRINT | OK | Preservado |
| 19 | selecao do estilo visual | `buildNaturalImagePrompt` no codigo; prompts T02 proibidos | REF-SCROLL-PIPELINE; REF-WEB-BLUEPRINT | OK/BLOQUEADO_PROMPT_PROIBIDO | Codigo preservado; prompt nao tocado |
| 20 | selecao da paleta | `colorLegend` validado e passado como sugestao | REF-SCROLL-PIPELINE; REF-WEB-BLUEPRINT | OK | Preservado |
| 21 | selecao da proporcao | `GenerateLessonImageRequest.normalizedAspectRatio` | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 22 | selecao da resolucao | servidor/provedor decide; app comprime lado maximo | REF-SCROLL-CLIENT; REF-SCROLL-MEDIA | EQUIVALENTE_MOBILE | Preservado |
| 23 | selecao do formato | servidor retorna mime; app aceita png/jpeg/webp/svg e comprime raster para JPEG | REF-API-IMAGE; REF-SCROLL-MEDIA | OK | Preservado |
| 24 | selecao do provedor de IA | servidor usa config/modelo; app nao carrega segredo | REF-API-IMAGE | OK | Preservado |
| 25 | selecao do modelo de IA | `lessonImageModelPath`; `GEMINI_IMAGE_MODEL` no servidor | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 26 | construcao do blueprint | `blueprint_prompt.dart` | REF-WEB-BLUEPRINT | OK | Preservado |
| 27 | construcao do prompt | builder de codigo permitido; prompts oficiais proibidos | REF-SCROLL-PIPELINE; REF-WEB-BLUEPRINT | OK/BLOQUEADO_PROMPT_PROIBIDO | Codigo preservado; prompt nao tocado |
| 28 | enriquecimento do prompt | `_enrichVisualTrigger` soma item, explicacao, pergunta e alternativas | REF-SCROLL-ORCH | OK | Preservado |
| 29 | normalizacao do prompt | `GenerateLessonImageRequest.normalized`, API `validatePayload` | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 30 | sanitizacao do prompt | truncamento e limpeza no cliente/API; prompt oficial proibido | REF-SCROLL-CLIENT; REF-API-IMAGE | OK/BLOQUEADO_PROMPT_PROIBIDO | Preservado |
| 31 | validacao do prompt | minimo 12 chars e aceite obrigatorio no servidor | REF-API-IMAGE | OK | Preservado |
| 32 | compressao do prompt | truncamento 4000 chars | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 33 | hash do prompt | `hashKey(validated.prompt)` no servidor | REF-API-IMAGE | OK | Preservado |
| 34 | deduplicacao do prompt | cacheKey e operationId incluem promptHash | REF-API-IMAGE | OK | Preservado |
| 35 | assinatura do prompt | idempotency/operationId; sem assinatura criptografica no Web | REF-API-IMAGE | EQUIVALENTE | Preservado |
| 36 | envio do prompt | `SimServerLessonImageClient.generateLessonImageResponse` | REF-SCROLL-CLIENT | OK | Preservado |
| 37 | autenticacao da requisicao | `config.jsonHeaders()` com bearer; servidor exige auth | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 38 | autorizacao da requisicao | `assertResourceOwner` por user/cacheKey | REF-API-IMAGE | OK | Preservado |
| 39 | rate limit | `createWindowLimiter` por userId | REF-API-IMAGE | OK | Preservado |
| 40 | retry | retry de provedor 1s/3s/7s | REF-API-IMAGE | OK | Preservado |
| 41 | timeout | cliente 125s; servidor/provedor timeout | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 42 | fallback de provedor | nao ha fallback multi-provedor; Web tambem usa provedor configurado | REF-WEB-IMAGE; REF-API-IMAGE | EQUIVALENTE | Preservado |
| 43 | fallback de modelo | nao ha fallback multi-modelo; retry usa mesmo modelo | REF-WEB-IMAGE; REF-API-IMAGE | EQUIVALENTE | Preservado |
| 44 | fallback para SVG | N2/N3/local antes de pago | REF-SCROLL-PIPELINE | OK | Preservado |
| 45 | fallback para software | `SoftwareRenderCatalog` antes de N3/IA | REF-SCROLL-RENDER | OK | Preservado |
| 46 | fallback para placeholder | UI mostra indisponivel sem bloquear aula | REF-SCROLL-UI | EQUIVALENTE_MOBILE | Preservado |
| 47 | geracao pelo software | renderizadores locais | REF-SCROLL-RENDER | OK | Preservado |
| 48 | geracao por SVG | `sanitizeAndEncodeSvg` | REF-SCROLL-PIPELINE | OK | Preservado |
| 49 | geracao por template | `math_templates` | REF-SCROLL-MATH | OK | Preservado |
| 50 | geracao por IA | `/api/generate-lesson-image` | REF-API-IMAGE | OK | Preservado |
| 51 | geracao hibrida | N2/N3 + software + IA paga | REF-SCROLL-PIPELINE | OK | Preservado |
| 52 | geracao incremental | nao existe streaming de imagem no Web/app; nao requerido | REF-WEB-IMAGE | NAO_APLICAVEL | Nenhuma |
| 53 | geracao assincrona | `_imageQueue`, background e event bus | REF-SCROLL-ORCH | OK | Preservado |
| 54 | fila de geracao | `_imageQueue`, `_imageInflight`, `_paidInflight` | REF-SCROLL-ORCH | OK | Preservado |
| 55 | cancelamento da geracao | botao trava UI; cancelamento HTTP real nao existe no Web | REF-WEB-OFFER; REF-SCROLL-LAB | EQUIVALENTE | Preservado |
| 56 | progresso da geracao | `imageStatus=loading`; sem progresso percentual real | REF-SCROLL-LAB; REF-SCROLL-UI | EQUIVALENTE | Preservado |
| 57 | resposta parcial | nao ha resposta parcial de imagem | REF-WEB-IMAGE | NAO_APLICAVEL | Nenhuma |
| 58 | resposta final | dataUrl final | REF-API-IMAGE; REF-SCROLL-CLIENT | OK | Preservado |
| 59 | download da imagem | servidor converte inline provider para dataUrl | REF-API-IMAGE | OK | Preservado |
| 60 | validacao do arquivo recebido | `isUsableImageDataUrl`, compressao raster | REF-SCROLL-PIPELINE; REF-SCROLL-MEDIA | OK | Preservado |
| 61 | validacao das dimensoes | decode de imagem na compressao; sem rejeicao por dimensao | REF-SCROLL-MEDIA | EQUIVALENTE_MOBILE | Preservado |
| 62 | validacao da proporcao | aspect ratio normalizado antes do envio | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 63 | validacao da qualidade | `ImagePedagogicalCritic` para SVG; provider para raster | REF-SCROLL-PIPELINE | OK | Preservado |
| 64 | validacao do MIME | regex dataUrl e inlineData `image/` | REF-SCROLL-MEDIA; REF-API-IMAGE | OK | Preservado |
| 65 | validacao da integridade | base64 decode/compressao; SVG sanitizado | REF-SCROLL-MEDIA; REF-SCROLL-PIPELINE | OK | Preservado |
| 66 | conversao para Data URL | API e SVG sanitizer | REF-API-IMAGE; REF-SCROLL-PIPELINE | OK | Preservado |
| 67 | conversao para bytes | `base64Decode` na compressao | REF-SCROLL-MEDIA | OK | Preservado |
| 68 | conversao para memoria | decode image em memoria | REF-SCROLL-MEDIA | OK | Preservado |
| 69 | armazenamento temporario | cache app/API em memoria | REF-SCROLL-ORCH; REF-API-IMAGE | OK | Preservado |
| 70 | armazenamento permanente | app nao persiste imagem pesada por saude mobile | REF-SCROLL-MEDIA | EQUIVALENTE_MOBILE | Preservado |
| 71 | cache em memoria | `LessonMaterialCache`; `media-cache.js` | REF-SCROLL-ORCH; REF-API-IMAGE | OK | Preservado |
| 72 | cache em disco | nao usado para imagem pesada | REF-SCROLL-MEDIA | EQUIVALENTE_MOBILE | Preservado |
| 73 | invalidacao do cache | LRU no app/API | REF-SCROLL-ORCH; REF-API-IMAGE | OK | Preservado |
| 74 | sincronizacao com cloud | eventos de midia no StudentLearningState; nao envia imagem completa | REF-SCROLL-MEDIA | EQUIVALENTE_MOBILE | Preservado |
| 75 | restauracao da imagem | aula/cache/event bus reaplicam `CompleteLesson.imagem` | REF-SCROLL-ORCH; REF-SCROLL-LAB | OK | Preservado |
| 76 | associacao da imagem a aula | `lessonKeyFor(params)` | REF-SCROLL-ORCH | OK | Preservado |
| 77 | associacao da imagem ao item | `LessonMediaPosition.itemMarker` | REF-SCROLL-MEDIA | OK | Preservado |
| 78 | associacao da imagem a pergunta | `_enrichVisualTrigger` inclui pergunta e alternativas | REF-SCROLL-ORCH | OK | Preservado |
| 79 | associacao da imagem ao runtime | `applyLessonUpdateForKey` e snapshot | REF-SCROLL-LAB | OK | Preservado |
| 80 | associacao ao StudentLearningState | `IMAGE_STARTED/READY/FAILED` | REF-SCROLL-MEDIA | OK | Preservado |
| 81 | transporte servidor-app | `/api/generate-lesson-image` JSON/dataUrl | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 82 | transporte entre modulos | event bus por key | REF-SCROLL-ORCH; REF-SCROLL-LAB | OK | Preservado |
| 83 | serializacao da imagem | dataUrl string | REF-SCROLL-CLIENT | OK | Preservado |
| 84 | desserializacao da imagem | renderizador aceita dataUrl/SVG/raster | REF-SCROLL-UI | OK | Preservado |
| 85 | renderizacao da imagem | painel/bolha de imagem | REF-SCROLL-UI | OK | Preservado |
| 86 | rebuild da imagem na UI | listener do event bus atualiza snapshot | REF-SCROLL-LAB | OK | Preservado |
| 87 | atualizacao dinamica da imagem | `bus.notify` + `notifyListeners` | REF-SCROLL-ORCH; REF-SCROLL-LAB | OK | Preservado |
| 88 | placeholder durante carregamento | `imageStatus=loading` | REF-SCROLL-UI | OK | Preservado |
| 89 | indicador de carregamento | CircularProgressIndicator | REF-SCROLL-UI | OK | Preservado |
| 90 | erro de carregamento | mensagem nao bloqueante | REF-SCROLL-LAB; REF-SCROLL-UI | OK | Preservado |
| 91 | botao tentar novamente | retry de aula/erro de engine; imagem paga reaceita via oferta | REF-SCROLL-UI | EQUIVALENTE | Preservado |
| 92 | descarte de imagem antiga | `_resetActiveLessonMedia` e `advanceAulaVisual` | REF-SCROLL-LAB; REF-SCROLL-UI | OK | Preservado |
| 93 | troca de imagem | publish por lessonKey substitui cache/snapshot | REF-SCROLL-ORCH | OK | Preservado |
| 94 | animacao de entrada da imagem | UI preserva layout; animacao nao essencial | REF-SCROLL-UI | EQUIVALENTE_MOBILE | Preservado |
| 95 | zoom da imagem | inspeção/zoom cobertos em testes existentes | REF-SCROLL-UI; REF-TESTES | OK | Preservado |
| 96 | pan da imagem | inspeção mobile equivalente | REF-SCROLL-UI | EQUIVALENTE_MOBILE | Preservado |
| 97 | adaptacao ao tamanho da tela | painel e chat usam constraints | REF-SCROLL-UI | OK | Preservado |
| 98 | acessibilidade da imagem | labels de estado; sem texto tecnico cru | REF-SCROLL-UI | OK | Preservado |
| 99 | telemetria/logs do funil | `VisualFunnelTelemetry`, logs N2/N3/pipeline | REF-SCROLL-PIPELINE | OK | Preservado |
| 100 | cobranca de creditos | servidor reserva/captura credito | REF-API-IMAGE | OK | Preservado |
| 101 | verificacao de saldo | credits gateway/controlador e servidor | REF-WEB-OFFER; REF-API-IMAGE | OK | Preservado |
| 102 | reserva de creditos | `reserveCredit` | REF-API-IMAGE | OK | Preservado |
| 103 | confirmacao da cobranca | `captureCredit`; response `charged` | REF-API-IMAGE | OK | Preservado |
| 104 | refund em falha | `releaseCredit` se nao capturado | REF-API-IMAGE | OK | Preservado |
| 105 | aceite antes da geracao paga | `acceptedOfferId` obrigatorio | REF-SCROLL-ORCH; REF-API-IMAGE | OK | Preservado |
| 106 | bloqueio sem permissao | 401/403/409 no servidor | REF-API-IMAGE | OK | Preservado |
| 107 | persistencia do aceite | idempotencyKey/operationId por offer | REF-SCROLL-ORCH; REF-API-IMAGE | OK | Preservado |
| 108 | reutilizacao de imagem comprada | cache hit/idempotent replay sem nova cobranca | REF-API-IMAGE | OK | Preservado |
| 109 | auditoria de custo | logs `cost`, `charged`, `operationId` | REF-API-IMAGE | OK | Preservado |
| 110 | metricas de tempo | servidor loga `ms`; app nao exibe | REF-API-IMAGE | OK_SERVIDOR | Preservado |
| 111 | metricas de cache hit | servidor retorna/cache loga; client parseia `cacheHit` | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 112 | metricas de falha | servidor loga fail; app guarda requestId/retryable em erro | REF-SCROLL-LAB; REF-API-IMAGE | OK | Preservado |
| 113 | metricas de retry | servidor usa retry e retorna retryable em erro | REF-API-IMAGE | OK | Preservado |
| 114 | integracao com timeline | imagem vira mensagem no chat | REF-SCROLL-UI | OK | Preservado |
| 115 | integracao com resposta | imagem aparece antes da pergunta/opcoes | REF-SCROLL-UI | OK | Preservado |
| 116 | integracao com A/B/C | imagem nao bloqueia alternativas | REF-SCROLL-UI; REF-TESTES | OK | Preservado |
| 117 | integracao com feedback | imagem nao esconde feedback | REF-SCROLL-UI; REF-TESTES | OK | Preservado |
| 118 | integracao com revisao | visual trigger preservado em review | REF-TESTES | OK | Preservado |
| 119 | integracao com recuperacao | visual trigger preservado em recovery | REF-TESTES | OK | Preservado |
| 120 | limpeza completa do ciclo de vida | reset media, clear offer, dispose listener | REF-SCROLL-LAB | OK | Preservado |
| 121 | LessonVisualTrigger | modelo vivo | REF-SCROLL-PIPELINE | OK | Preservado |
| 122 | campo needsImage | parse `needs_image`/`needsImage` | REF-SCROLL-PIPELINE | OK | Preservado |
| 123 | campo pedagogicalNeed | parse/skip | REF-SCROLL-PIPELINE | OK | Preservado |
| 124 | campo visualType | parse e N2/N3 | REF-SCROLL-PIPELINE | OK | Preservado |
| 125 | campo complexity | enviado N3 | REF-SCROLL-N3 | OK | Preservado |
| 126 | campo renderStrategy | software/ai | REF-SCROLL-PIPELINE | OK | Preservado |
| 127 | campo mathTemplate | render template | REF-SCROLL-MATH | OK | Preservado |
| 128 | campo imagePrompt | prompt natural | REF-SCROLL-PIPELINE | OK | Preservado |
| 129 | campo highlightFocus | enviado N3 | REF-SCROLL-N3 | OK | Preservado |
| 130 | campo keyElements | enviado N3 | REF-SCROLL-N3 | OK | Preservado |
| 131 | campo colorLegend | parse + prompt | REF-SCROLL-PIPELINE | OK | Preservado |
| 132 | BlueprintColorLegendItem | modelo vivo | REF-WEB-BLUEPRINT | OK | Preservado |
| 133 | validacao de legenda de cores | `_isHexColor`, `hasUsableColorLegend` | REF-SCROLL-PIPELINE | OK | Preservado |
| 134 | colorLegendFromJson | parse seguro | REF-SCROLL-PIPELINE | OK | Preservado |
| 135 | colorLegendToJson | serializacao | REF-SCROLL-PIPELINE | OK | Preservado |
| 136 | buildNaturalImagePrompt | builder de codigo permitido | REF-WEB-BLUEPRINT | OK | Preservado |
| 137 | buildSoftwareVisualPrompt | nao ha funcao com esse nome; papel coberto por render local | REF-SCROLL-RENDER | EQUIVALENTE | Preservado |
| 138 | _langNames | diretiva multilingue | REF-WEB-BLUEPRINT | OK | Preservado |
| 139 | VisualVerdict.svg | enum vivo | REF-SCROLL-N2 | OK | Preservado |
| 140 | VisualVerdict.ai | enum vivo | REF-SCROLL-N2 | OK | Preservado |
| 141 | VisualVerdict.ambiguous | enum vivo | REF-SCROLL-N2 | OK | Preservado |
| 142 | VisualVerdict.noImage | enum vivo | REF-SCROLL-N2 | OK | Preservado |
| 143 | VisualN2Result | modelo vivo | REF-SCROLL-N2 | OK | Preservado |
| 144 | matched do N2 | lista de hits | REF-SCROLL-N2 | OK | Preservado |
| 145 | confidence do N2 | campo vivo | REF-SCROLL-N2 | OK | Preservado |
| 146 | reason do N2 | campo vivo | REF-SCROLL-N2 | OK | Preservado |
| 147 | classifyVisualByKeywords | N2 deterministico | REF-WEB-ROUTER; REF-SCROLL-N2 | OK | Preservado |
| 148 | _confidenceForHits | calculo de confianca | REF-SCROLL-N2 | OK | Preservado |
| 149 | _negatesPhotoRealism | evita falso realismo | REF-SCROLL-N2 | OK | Preservado |
| 150 | _isPhotoRealismHint | filtro de realismo | REF-SCROLL-N2 | OK | Preservado |
| 151 | _matchesHint | matching deterministico | REF-SCROLL-N2 | OK | Preservado |
| 152 | VisualN3Result | modelo vivo | REF-SCROLL-N3 | OK | Preservado |
| 153 | transportFailed do N3 | falha explicita | REF-SCROLL-N3 | OK | Preservado |
| 154 | LessonVisualRouterClient | interface viva | REF-SCROLL-N3 | OK | Preservado |
| 155 | routeVisualCheapN3 | N3 barato | REF-SCROLL-N3; REF-API-VISUAL | OK | Preservado |
| 156 | _shortVisualN3Error | sanitiza erro | REF-SCROLL-N3 | OK | Preservado |
| 157 | endpoint /api/visual-route | servidor vivo | REF-API-VISUAL | OK | Preservado |
| 158 | buildVisualRoutePayload | normaliza payload | REF-API-VISUAL | OK | Preservado |
| 159 | sanitizeAndEncodeSvg | app/API sanitizam SVG | REF-SCROLL-PIPELINE; REF-API-VISUAL | OK | Preservado |
| 160 | extractSvg | servidor extrai SVG de resposta N3 | REF-API-VISUAL | OK | Preservado |
| 161 | parseRouterJson | servidor parseia JSON/fence | REF-API-VISUAL | OK | Preservado |
| 162 | cleanInput | servidor limita texto | REF-API-VISUAL | OK | Preservado |
| 163 | cleanList | servidor limita listas | REF-API-VISUAL | OK | Preservado |
| 164 | cleanN2 | servidor limpa N2 | REF-API-VISUAL | OK | Preservado |
| 165 | retorno svgDataUrl | servidor e app preservam | REF-API-VISUAL; REF-SCROLL-N3 | OK | Preservado |
| 166 | retorno templateName | nao usado no contrato atual | REF-API-VISUAL | NAO_APLICAVEL | Nenhuma |
| 167 | retorno pedagogicalRole | preservado | REF-SCROLL-N3; REF-API-VISUAL | OK | Preservado |
| 168 | retorno confidence | preservado | REF-SCROLL-N3; REF-API-VISUAL | OK | Preservado |
| 169 | visual-trigger-normalizer.js | normalizador API | REF-API-VT | OK | Preservado |
| 170 | normalizeVisualTrigger | normaliza campos | REF-API-VT | OK | Preservado |
| 171 | GenerateLessonImageRequest | contrato app | REF-SCROLL-CLIENT | OK | Preservado |
| 172 | GenerateLessonImageResponse | contrato app | REF-SCROLL-CLIENT | OK | Preservado |
| 173 | lessonImageModelPath | constante sem segredo | REF-SCROLL-CLIENT | OK | Preservado |
| 174 | lessonImageRequestTimeoutMs | constante | REF-SCROLL-CLIENT | OK | Preservado |
| 175 | lessonImageRateLimitWindowMs | constante espelha servidor | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 176 | lessonImageRateLimitMaxPerWindow | constante espelha servidor | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 177 | lessonImageCircuitFailThreshold | constante ainda nao governa circuito app | REF-SCROLL-CLIENT | DOCUMENTADO | Sem alteracao segura |
| 178 | lessonImageCircuitOpenMs | constante ainda nao governa circuito app | REF-SCROLL-CLIENT | DOCUMENTADO | Sem alteracao segura |
| 179 | LessonPaidImageOfferController | controlador isolado testado | REF-SCROLL-LAB | OK | Preservado |
| 180 | PaidImageOfferStatus.pending | service isolado | REF-SCROLL-LAB | OK | Preservado |
| 181 | PaidImageOfferStatus.accepted | service isolado | REF-SCROLL-LAB | OK | Preservado |
| 182 | PaidImageOfferStatus.declined | service isolado | REF-SCROLL-LAB | OK | Preservado |
| 183 | PaidImageOfferStatus.consumed | service isolado | REF-SCROLL-LAB | OK | Preservado |
| 184 | PaidImageOfferStatus.failed | service isolado | REF-SCROLL-LAB | OK | Preservado |
| 185 | PaidImageServiceOffer.offerId | stable id | REF-SCROLL-LAB | OK | Preservado |
| 186 | PaidImageServiceOffer.lessonKey | key por aula | REF-SCROLL-LAB | OK | Preservado |
| 187 | PaidImageServiceOffer.prompt | prompt aprovado | REF-SCROLL-LAB | OK | Preservado |
| 188 | PaidImageServiceOffer.creditCost | custo explicito | REF-SCROLL-LAB | OK | Preservado |
| 189 | PaidImageFetcher | fetcher injetado | REF-SCROLL-LAB | OK | Preservado |
| 190 | _stableOfferId | hash estavel | REF-SCROLL-LAB | OK | Preservado |
| 191 | _stableHash | hash deterministico | REF-SCROLL-LAB | OK | Preservado |
| 192 | offerStream | stream isolado | REF-SCROLL-LAB | OK | Preservado |
| 193 | consume | gera so apos aceite | REF-SCROLL-LAB | OK | Preservado |
| 194 | decline | recusa sem debito | REF-SCROLL-LAB | OK | Preservado |
| 195 | getOffer | consulta status | REF-SCROLL-LAB | OK | Preservado |
| 196 | SoftwareVisualRequest | request render local | REF-SCROLL-RENDER | OK | Preservado |
| 197 | SoftwareRenderResult | retorno render local | REF-SCROLL-RENDER | OK | Preservado |
| 198 | SoftwareRenderCatalog | catalogo vivo | REF-SCROLL-RENDER | OK | Preservado |
| 199 | _QuadraticRenderer | parabola/formula | REF-SCROLL-RENDER; REF-SCROLL-MATH | OK | Preservado |
| 200 | _LinearRenderer | reta/linear | REF-SCROLL-RENDER | OK | Preservado |
| 201 | _UnitCircleRenderer | circulo unitario | REF-SCROLL-RENDER | OK | Preservado |
| 202 | _TimelineRenderer | linha do tempo | REF-SCROLL-RENDER | OK | Preservado |
| 203 | _FlowchartRenderer | fluxograma | REF-SCROLL-RENDER | OK | Preservado |
| 204 | _ComparisonRenderer | comparacao | REF-SCROLL-RENDER | OK | Preservado |
| 205 | _CycleRenderer | ciclo | REF-SCROLL-RENDER | OK | Preservado |
| 206 | _TableRenderer | tabela | REF-SCROLL-RENDER | OK | Preservado |
| 207 | _ConceptMapRenderer | mapa conceitual | REF-SCROLL-RENDER | OK | Preservado |
| 208 | _ForceDiagramRenderer | forcas | REF-SCROLL-RENDER | OK | Preservado |
| 209 | _CircuitRenderer | circuito | REF-SCROLL-RENDER | OK | Preservado |
| 210 | _SyntaxTreeRenderer | arvore sintatica | REF-SCROLL-RENDER | OK | Preservado |
| 211 | _FoodChainRenderer | cadeia alimentar | REF-SCROLL-RENDER | OK | Preservado |
| 212 | _extractFormula | aceita `f(x)=...` | REF-SCROLL-RENDER; REF-SCROLL-MATH | OK | Preservado |
| 213 | _bestTitle | titulo curto | REF-SCROLL-RENDER | OK | Preservado |
| 214 | _escapeSvgLabel | escapa texto SVG | REF-SCROLL-RENDER | OK | Preservado |
| 215 | renderLocalVisualFallback | papel coberto por `SoftwareRenderCatalog` | REF-SCROLL-RENDER | EQUIVALENTE | Preservado |
| 216 | ImagePedagogicalCritic | critica SVG | REF-SCROLL-PIPELINE | OK | Preservado |
| 217 | ImagePedagogicalCritique.accepted | retorno critico | REF-SCROLL-PIPELINE | OK | Preservado |
| 218 | ImagePedagogicalCritique.reason | motivo critico | REF-SCROLL-PIPELINE | OK | Preservado |
| 219 | ImagePedagogicalCritique.textNodeCount | contagem texto | REF-SCROLL-PIPELINE | OK | Preservado |
| 220 | ImagePedagogicalCritique.hasGarbageText | campo nao existe; coberto por unsafe/text limit | REF-SCROLL-PIPELINE | EQUIVALENTE | Preservado |
| 221 | LessonImageClient | interface viva | REF-SCROLL-PIPELINE | OK | Preservado |
| 222 | generateLessonImage | metodo compat | REF-SCROLL-CLIENT | OK | Preservado |
| 223 | parametro lessonKey | enviado e validado | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 224 | parametro acceptedOfferId | obrigatorio para pago | REF-SCROLL-CLIENT; REF-API-IMAGE | OK | Preservado |
| 225 | parametro lessonContext | enviado ao servidor | REF-SCROLL-CLIENT | OK | Preservado |
| 226 | LessonVisualResult | modelo vivo | REF-SCROLL-PIPELINE | OK | Preservado |
| 227 | LessonVisualResult.source | diagnostico | REF-SCROLL-PIPELINE | OK | Preservado |
| 228 | LessonVisualResult.hasImage | helper | REF-SCROLL-PIPELINE | OK | Preservado |
| 229 | LessonVisualResult.displayUrl | helper | REF-SCROLL-PIPELINE | OK | Preservado |
| 230 | source skip | sem imagem | REF-SCROLL-PIPELINE | OK | Preservado |
| 231 | source svg_payload | hoje `svg_inline`; equivalente | REF-SCROLL-PIPELINE | EQUIVALENTE | Preservado |
| 232 | source math_template | vivo | REF-SCROLL-PIPELINE | OK | Preservado |
| 233 | source software_render | hoje `local_software`; equivalente | REF-SCROLL-PIPELINE | EQUIVALENTE | Preservado |
| 234 | source n3_svg | hoje `n3_software`; equivalente | REF-SCROLL-PIPELINE | EQUIVALENTE | Preservado |
| 235 | source ai_paid | hoje `ai_blueprint`; equivalente | REF-SCROLL-PIPELINE | EQUIVALENTE | Preservado |
| 236 | resolveVisual | funil central | REF-SCROLL-PIPELINE | OK | Preservado |
| 237 | tryMathTemplate | helper | REF-SCROLL-PIPELINE | OK | Preservado |
| 238 | _acceptSoftwareSvg | critica antes de aceitar | REF-SCROLL-PIPELINE | OK | Preservado |
| 239 | fetchPaidLessonImage | pago exige aceite e dataUrl usavel | REF-SCROLL-PIPELINE | OK | Preservado |
| 240 | buildPromptForTrigger | construtor permitido; prompts proibidos | REF-SCROLL-PIPELINE | OK/BLOQUEADO_PROMPT_PROIBIDO | Preservado |
| 241 | _visualLog | log debug | REF-SCROLL-PIPELINE | OK | Preservado |
| 242 | _recordOutcome | telemetria funil | REF-SCROLL-PIPELINE | OK | Preservado |
| 243 | _mathTemplateName | diagnostico | REF-SCROLL-PIPELINE | OK | Preservado |
| 244 | _shortVisualText | sanitiza log | REF-SCROLL-PIPELINE | OK | Preservado |
| 245 | VisualFunnelEvent | evento | REF-SCROLL-PIPELINE | OK | Preservado |
| 246 | VisualFunnelSnapshot | snapshot | REF-SCROLL-PIPELINE | OK | Preservado |
| 247 | VisualFunnelTelemetry.record | record | REF-SCROLL-PIPELINE | OK | Preservado |
| 248 | VisualFunnelTelemetry.snapshot | snapshot | REF-SCROLL-PIPELINE | OK | Preservado |
| 249 | contagem softwareSvg | `software` | REF-SCROLL-PIPELINE | OK | Preservado |
| 250 | contagem n3Svg | fonte `n3_software` dentro outcome software | REF-SCROLL-PIPELINE | EQUIVALENTE | Preservado |
| 251 | contagem paidOffer | `paid_offer` | REF-SCROLL-PIPELINE | OK | Preservado |
| 252 | contagem aiGenerated | `paid_ready` | REF-SCROLL-PIPELINE | OK | Preservado |
| 253 | contagem noImage | `no_image` | REF-SCROLL-PIPELINE | OK | Preservado |
| 254 | contagem failed | `failed` | REF-SCROLL-PIPELINE | OK | Preservado |
| 255 | markLessonImageReady | evento state | REF-SCROLL-MEDIA; REF-WEB-MEDIA | OK | Preservado |
| 256 | markLessonImageStarted | evento state | REF-SCROLL-MEDIA; REF-WEB-MEDIA | OK | Preservado |
| 257 | markLessonImageFailed | evento state | REF-SCROLL-MEDIA; REF-WEB-MEDIA | OK | Preservado |
| 258 | LessonMediaPosition | posicao midia | REF-SCROLL-MEDIA | OK | Preservado |
| 259 | position.lessonLocalId | chave da aula | REF-SCROLL-MEDIA | OK | Preservado |
| 260 | position.itemId | no Scroll chama `itemMarker`; equivalente | REF-SCROLL-MEDIA | EQUIVALENTE | Preservado |
| 261 | position.layer | camada | REF-SCROLL-MEDIA | OK | Preservado |
| 262 | evento image_started | `IMAGE_STARTED` | REF-SCROLL-MEDIA | OK | Preservado |
| 263 | evento image_ready | `IMAGE_READY` | REF-SCROLL-MEDIA | OK | Preservado |
| 264 | evento image_failed | `IMAGE_FAILED` | REF-SCROLL-MEDIA | OK | Preservado |
| 265 | compressImageDataUrl | compressao raster | REF-SCROLL-MEDIA | OK | Preservado |
| 266 | defaultMaxImageSide | 1280 | REF-SCROLL-MEDIA | OK | Preservado |
| 267 | conversao raster para JPEG | `encodeJpg` | REF-SCROLL-MEDIA | OK | Preservado |
| 268 | renderAxes | dentro templates compartilhados | REF-SCROLL-MATH | OK | Preservado |
| 269 | wrapSvg | dentro templates compartilhados | REF-SCROLL-MATH | OK | Preservado |
| 270 | CompleteLesson.copyWith limpa imagem antiga | teste de regressao existente | REF-TESTES | OK | Preservado |

## Itens bloqueados por regra de prompt

Estes itens podem ter parte da solucao dentro dos prompts T00/T02/adendos, mas nao foram tocados:

- 19. selecao do estilo visual, quando determinada por T02.
- 27. construcao do prompt, quando determinada por `prompts/t02.txt`.
- 30. sanitizacao do prompt, quando depender de texto dentro de prompt.
- 240. `buildPromptForTrigger`, somente na parte que poderia exigir mudanca de instrucao T02.

## Validacao executada

Executar apos esta auditoria:

- `flutter analyze`
- `flutter test test/media_phase_test.dart test/first_lesson_ready_window_test.dart test/external_ai_clients_test.dart test/chat_aula_widgets_test.dart test/finish_phase_test.dart`
- `flutter test`

## Resultado

- Total de itens auditados: 270.
- Codigo alterado: nao.
- Prompts alterados: nao.
- Itens bloqueados por prompt: 4.
- Itens com correcao autorizada fora de prompt: 0.
- Estado do funil fora dos prompts: funcionalmente alinhado com SIM Web/API e preservado.
