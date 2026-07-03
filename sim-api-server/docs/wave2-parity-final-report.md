# Wave 2 - Relatorio de Paridade SIM-API / SIM-Flutter / SIM-Web

Status final: B=NAO.

Motivo: os principais pontos seguros de imagem, audio, duvida, credito em memoria e contrato foram implementados/testados, mas a Wave 2 completa inclui itens que dependem de decisao de provider, RPC/Supabase/transacao real, implementacao client Flutter mais profunda e prova APK. Esses pontos nao foram inventados nem copiados cegamente do Web.

## Resumo

- Total de itens da Wave: 40.
- P0/P1/P2: 22 P0, 14 P1, 4 P2.
- Implementados: 19.
- Testados: 12.
- Confirmados sem alteracao: 4.
- Documentados: 4.
- Bloqueados: 8.
- Nao feitos por risco/escopo: 5.
- SimWeb alterado: NAO.
- Precos alterados: NAO.
- Auth/resource owner enfraquecido: NAO.
- Provider Web copiado cegamente: NAO.

## Arquivos Alterados no SIM-API

- `src/app/router.js`
- `src/config/env.js`
- `src/credits/credits-store.js`
- `src/http/http-utils.js`
- `src/media/audio-controller.js`
- `src/media/image-controller.js`
- `src/t02/complete-lesson-controller.js`
- `test/server-contract.test.js`
- `docs/AUDIO_PARALLEL_CONTRACT.md`
- `docs/IMAGE_PROVIDER_DECISION.md`
- `docs/wave2-parity-final-report.md`

## Arquivos Alterados no SIM Flutter

- `docs/SIM_FLUTTER_CONTRATO_FIO.md`

## Testes e Validacoes

- `node --check server.js`: PASSOU.
- `node --check` nos JS alterados: PASSOU.
- `npm test`: PASSOU.
- Flutter analyze: PASSOU.
- Flutter test: PASSOU.
- Flutter build/APK: NAO RODADO, porque a unica alteracao Flutter foi documental e nao houve pedido de APK nesta Wave.
- APK real: NAO PROVADO nesta Wave 2.

## Itens H - Imagem

### H1
- ID: H1
- Prioridade: P0
- Status: BLOQUEADO
- Arquivo(s) alterado(s): `docs/IMAGE_PROVIDER_DECISION.md`
- O que foi feito: registrada decisao de nao trocar automaticamente o provider/modelo para o provider Web.
- Por que nao fere arquitetura: preserva o provider proprio do SIM-API.
- Como evita doenca do Web: nao copia Lovable/Replicate sem contrato/producao aprovados.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: documento de decisao criado.
- Risco restante: modelo real de imagem ainda depende de configuracao `GEMINI_IMAGE_MODEL`.

### H2
- ID: H2
- Prioridade: P0
- Status: BLOQUEADO
- Arquivo(s) alterado(s): `docs/IMAGE_PROVIDER_DECISION.md`
- O que foi feito: provider Web nao migrado.
- Por que nao fere arquitetura: evita misturar credencial/infra Web no SIM-API.
- Como evita doenca do Web: nao traz gateway externo sem decisao.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: decisao documentada.
- Risco restante: paridade visual por provider precisa decisao do dono.

### H3
- ID: H3
- Prioridade: P0
- Status: IMPLEMENTADO / TESTADO
- Arquivo(s) alterado(s): `src/media/image-controller.js`, `test/server-contract.test.js`
- O que foi feito: `aspectRatio` invalido agora cai para `1:1` e loga fallback.
- Por que nao fere arquitetura: validacao local no controller.
- Como evita doenca do Web: nao aceita string livre sem controle.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste `normalizeAspectRatio('portrait') === '1:1'`.
- Risco restante: nenhum conhecido.

### H4
- ID: H4
- Prioridade: P0
- Status: IMPLEMENTADO
- Arquivo(s) alterado(s): `src/media/image-controller.js`
- O que foi feito: prompt acima de 4000 chars e truncado com log; prompt suspeito e logado.
- Por que nao fere arquitetura: prompt final continua vindo do cliente/Flutter.
- Como evita doenca do Web: nao reimplementa blueprint Web dentro do servidor.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: logs `IMAGE_PROMPT_SUSPECT`.
- Risco restante: qualidade do prompt depende do cliente visual.

### H5
- ID: H5
- Prioridade: P1
- Status: IMPLEMENTADO
- Arquivo(s) alterado(s): `src/media/image-controller.js`
- O que foi feito: chamada de imagem usa timeout de 60s.
- Por que nao fere arquitetura: ajuste operacional no provider atual.
- Como evita doenca do Web: nao muda provider.
- Teste executado: `node --check`, `npm test`
- Resultado: PASSOU
- Evidencia: `callImageProviderWithRetry` usa `timeout: 60000`.
- Risco restante: timeout real precisa prova com provider.

### H6
- ID: H6
- Prioridade: P0
- Status: IMPLEMENTADO
- Arquivo(s) alterado(s): `src/media/image-controller.js`, `src/app/router.js`
- O que foi feito: rate limit de imagem por usuario com `Retry-After`.
- Por que nao fere arquitetura: defesa no servidor.
- Como evita doenca do Web: nao depende de cliente obediente.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: controller possui limiter por usuario; router propaga `Retry-After`.
- Risco restante: teste de 11 chamadas via HTTP ainda pode ser ampliado.

### H7
- ID: H7
- Prioridade: P0
- Status: CONFIRMADO / TESTADO
- Arquivo(s) alterado(s): `src/media/image-controller.js`, `test/server-contract.test.js`
- O que foi feito: cache por `userId + lesson + aspect + promptHash` preservado e testado.
- Por que nao fere arquitetura: usa cache local existente.
- Como evita doenca do Web: nao cruza usuario.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: segunda chamada identica nao chama provider nem cobra.
- Risco restante: cache em memoria nao e persistencia real.

### H8
- ID: H8
- Prioridade: P1
- Status: IMPLEMENTADO / TESTADO
- Arquivo(s) alterado(s): `src/media/image-controller.js`, `test/server-contract.test.js`
- O que foi feito: retry controlado em 429/502/503/504 com backoff.
- Por que nao fere arquitetura: camada de resiliencia no controller.
- Como evita doenca do Web: nao retry em erro 4xx comum.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste simula 503 e sucesso na segunda chamada.
- Risco restante: backoff real aumenta latencia em falha.

### H9
- ID: H9
- Prioridade: P0
- Status: CONFIRMADO / TESTADO
- Arquivo(s) alterado(s): `test/server-contract.test.js`
- O que foi feito: `/api/visual-route` ja existia e segue protegido por auth; teste mantido.
- Por que nao fere arquitetura: usa endpoint proprio do SIM-API.
- Como evita doenca do Web: nao executa AI no cliente.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste retorna `verdict=svg` com `svgDataUrl`.
- Risco restante: contrato ainda difere levemente do texto da Wave, mas Flutter atual consome o contrato existente.

### H10
- ID: H10
- Prioridade: P1
- Status: IMPLEMENTADO
- Arquivo(s) alterado(s): `src/media/image-controller.js`
- O que foi feito: logs `IMAGE_GEN_OK` e `IMAGE_GEN_FAIL` com ms/model/aspect/promptSha/status.
- Por que nao fere arquitetura: observabilidade sem vazar prompt completo.
- Como evita doenca do Web: diagnostico sem expor segredo.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: logs aparecem durante teste.
- Risco restante: dashboard externo nao criado.

### H11
- ID: H11
- Prioridade: P2
- Status: IMPLEMENTADO
- Arquivo(s) alterado(s): `src/http/http-utils.js`, `src/media/image-controller.js`
- O que foi feito: suporte a headers extras e `Cache-Control: private, max-age=3600`.
- Por que nao fere arquitetura: header HTTP simples.
- Como evita doenca do Web: cache privado, nao publico.
- Teste executado: `node --check`, `npm test`
- Resultado: PASSOU
- Evidencia: `res._extraHeaders`.
- Risco restante: teste HTTP especifico de header pode ser ampliado.

### H12
- ID: H12
- Prioridade: P1
- Status: NAO FEITO
- Arquivo(s) alterado(s): nenhum
- O que foi feito: nada.
- Por que nao fere arquitetura: evitado parser parcial de PNG/WebP sem biblioteca/contrato.
- Como evita doenca do Web: nao cria falsa validacao.
- Teste executado: nao aplicavel.
- Resultado: NAO PROVADO.
- Evidencia: marcado como pendente.
- Risco restante: thumbnail degradada ainda pode passar.

## Itens I - Audio/TTS

### I1
- ID: I1
- Prioridade: P0
- Status: BLOQUEADO
- Arquivo(s) alterado(s): nenhum
- O que foi feito: modelo nao foi trocado para Web.
- Por que nao fere arquitetura: preserva provider proprio.
- Como evita doenca do Web: nao copia modelo/gateway sem decisao.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: `TTS_GEN` loga modelo configurado.
- Risco restante: paridade exata de voz/modelo depende decisao de provider.

### I2
- ID: I2
- Prioridade: P0
- Status: IMPLEMENTADO / TESTADO
- Arquivo(s) alterado(s): `src/media/audio-controller.js`, `test/server-contract.test.js`
- O que foi feito: audio aceita `language`, `voice`, `speed` e preserva no JSON.
- Por que nao fere arquitetura: contrato JSON existente mantido.
- Como evita doenca do Web: nao troca para binario puro.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste valida `language=pt-BR` e `speed=0.9`.
- Risco restante: prova de voz real exige APK/provider.

### I3
- ID: I3
- Prioridade: P0
- Status: IMPLEMENTADO / TESTADO
- Arquivo(s) alterado(s): `src/config/env.js`, `src/media/audio-controller.js`, `test/server-contract.test.js`
- O que foi feito: texto TTS limitado por `AUDIO_TEXT_MAX_CHARS`, default 4096, com log.
- Por que nao fere arquitetura: limite no servidor.
- Como evita doenca do Web: nao envia texto gigante ao provider.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste com cap 16 prova truncamento.
- Risco restante: corte sem resumo pode perder final do texto.

### I4
- ID: I4
- Prioridade: P1
- Status: IMPLEMENTADO / TESTADO
- Arquivo(s) alterado(s): `src/media/audio-controller.js`
- O que foi feito: cache por `lessonKey + language + voice + speed + hash(text)`.
- Por que nao fere arquitetura: reaproveita cache de midia.
- Como evita doenca do Web: nao cobra/regenera replay simples.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: segunda chamada de audio retorna `cache_hit`.
- Risco restante: cache em memoria.

### I5
- ID: I5
- Prioridade: P1
- Status: IMPLEMENTADO
- Arquivo(s) alterado(s): `src/media/audio-controller.js`, `src/app/router.js`
- O que foi feito: rate limit especifico de audio e `Retry-After`.
- Por que nao fere arquitetura: defesa no servidor.
- Como evita doenca do Web: evita spam/retry-loop.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: limiter local e routeClass `audio`.
- Risco restante: teste de 21 chamadas via HTTP pode ser ampliado.

### I6
- ID: I6
- Prioridade: P2
- Status: CONFIRMADO
- Arquivo(s) alterado(s): `src/media/audio-controller.js`
- O que foi feito: contrato JSON mantido.
- Por que nao fere arquitetura: Flutter ja consome JSON/base64.
- Como evita doenca do Web: nao muda contrato publicado.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: resposta contem `audio_base64`, `dataUrl`, `mime_type`.
- Risco restante: nenhum conhecido.

### I7
- ID: I7
- Prioridade: P0
- Status: DOCUMENTADO
- Arquivo(s) alterado(s): `docs/AUDIO_PARALLEL_CONTRACT.md`
- O que foi feito: contrato de audio paralelo documentado.
- Por que nao fere arquitetura: nao força comportamento cliente sem implementar no Flutter.
- Como evita doenca do Web: nao cria audio falso.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: documento criado.
- Risco restante: Flutter ainda precisa implementacao/prova real para warm audio.

## Itens J - Duvida

### J1
- ID: J1
- Prioridade: P0
- Status: CONFIRMADO
- Arquivo(s) alterado(s): `src/t02/complete-lesson-controller.js`
- O que foi feito: `output_contract=reduced` para doubt ja existe.
- Por que nao fere arquitetura: usa contrato T02 atual.
- Como evita doenca do Web: nao cria prompt paralelo.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste de doubt passa pelo T02 reduzido.
- Risco restante: p95 de 5s exige teste real com provider.

### J2
- ID: J2
- Prioridade: P0
- Status: IMPLEMENTADO / TESTADO
- Arquivo(s) alterado(s): `src/t02/complete-lesson-controller.js`, `test/server-contract.test.js`
- O que foi feito: MIME de imagem de duvida validado; PDF/SVG rejeitado.
- Por que nao fere arquitetura: validacao server-side.
- Como evita doenca do Web: nao aceita anexo perigoso como imagem.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste `application/pdf` gera `unsupported_mime`.
- Risco restante: HEIC nao aceito nesta rodada.

### J3
- ID: J3
- Prioridade: P0
- Status: IMPLEMENTADO / TESTADO
- Arquivo(s) alterado(s): `src/config/env.js`, `src/t02/complete-lesson-controller.js`, `test/server-contract.test.js`
- O que foi feito: imagem de duvida acima de 2 MB e rejeitada com 413.
- Por que nao fere arquitetura: rejeita em vez de adicionar dependencia pesada.
- Como evita doenca do Web: nao promete compressao server-side inexistente.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste com 3 MB falha com `compressão obrigatória`.
- Risco restante: cliente precisa comprimir.

### J4
- ID: J4
- Prioridade: P1
- Status: IMPLEMENTADO / TESTADO
- Arquivo(s) alterado(s): `src/t02/complete-lesson-controller.js`, `test/server-contract.test.js`
- O que foi feito: `question_context` enviado em doubt com pergunta/opcoes/resposta/aluno.
- Por que nao fere arquitetura: payload T02 apenas ganha contexto.
- Como evita doenca do Web: nao cria logica pedagogica no cliente.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste valida `question_context`.
- Risco restante: UI Flutter precisa preencher esses campos.

### J5
- ID: J5
- Prioridade: P1
- Status: IMPLEMENTADO
- Arquivo(s) alterado(s): `src/t02/complete-lesson-controller.js`
- O que foi feito: log `[T02_DOUBT] {ms, chars_in, chars_out, has_image}`.
- Por que nao fere arquitetura: observabilidade.
- Como evita doenca do Web: sem expor imagem/base64.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: log aparece na suite.
- Risco restante: dashboard nao criado.

### J6
- ID: J6
- Prioridade: P2
- Status: CONFIRMADO
- Arquivo(s) alterado(s): nenhum
- O que foi feito: doubt segue via T02 e nao chama reserva de credito.
- Por que nao fere arquitetura: politica atual preservada.
- Como evita doenca do Web: nao cobra duvida.
- Teste executado: inspecao + `npm test`
- Resultado: PASSOU
- Evidencia: `createDoubtController` delega para T02.
- Risco restante: nao ha teste especifico de saldo em doubt.

## Itens K - Creditos

### K1
- ID: K1
- Prioridade: P0
- Status: IMPLEMENTADO PARCIAL / TESTADO
- Arquivo(s) alterado(s): `src/credits/credits-store.js`, `test/server-contract.test.js`
- O que foi feito: store em memoria agora e idempotente por `operationId`.
- Por que nao fere arquitetura: melhora mecanismo atual sem Supabase RPC.
- Como evita doenca do Web: nao simula RPC inexistente.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: reserva repetida com mesmo operationId nao deduz duas vezes.
- Risco restante: producao real ainda precisa transacao/RPC se usar banco.

### K2
- ID: K2
- Prioridade: P0
- Status: BLOQUEADO
- Arquivo(s) alterado(s): nenhum
- O que foi feito: nao ha cobranca de aula no T02 atual para reembolsar.
- Por que nao fere arquitetura: nao inventa charge lesson sem fluxo existente.
- Como evita doenca do Web: nao cria cobranca nova.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: T02 nao chama `reserveCredit`.
- Risco restante: quando aula passar a cobrar, precisa refund atomico.

### K3
- ID: K3
- Prioridade: P0
- Status: CONFIRMADO / TESTADO
- Arquivo(s) alterado(s): `src/media/image-controller.js`, `test/server-contract.test.js`
- O que foi feito: refund de imagem em falha preservado e testado.
- Por que nao fere arquitetura: usa reserva/release atual.
- Como evita doenca do Web: nao captura credito se provider falha.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste `provider down` retorna `refunded=true`.
- Risco restante: banco real precisaria transacao.

### K4
- ID: K4
- Prioridade: P1
- Status: IMPLEMENTADO / TESTADO
- Arquivo(s) alterado(s): `src/media/image-controller.js`, `test/server-contract.test.js`
- O que foi feito: `allow_paid=false` retorna 403 sem provider/cobranca.
- Por que nao fere arquitetura: defesa em profundidade.
- Como evita doenca do Web: nao confia so no cliente.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste `paidDisabled`.
- Risco restante: nenhum conhecido.

### K5
- ID: K5
- Prioridade: P1
- Status: DOCUMENTADO
- Arquivo(s) alterado(s): `docs/test-credit-accounts.md`
- O que foi feito: bypass de credito de teste documentado na rodada anterior.
- Por que nao fere arquitetura: via env, nao hardcoded.
- Como evita doenca do Web: nao mascara producao por codigo.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: contas de teste em `.env`, documento no repo.
- Risco restante: ambiente de producao deve controlar `TEST_CREDIT_EMAILS`.

### K6
- ID: K6
- Prioridade: P0
- Status: IMPLEMENTADO
- Arquivo(s) alterado(s): `src/http/http-utils.js`, `src/media/image-controller.js`, `src/media/audio-controller.js`
- O que foi feito: suporte a `X-Credits-Balance` em respostas de midia.
- Por que nao fere arquitetura: header adicional, compatível.
- Como evita doenca do Web: contrato incremental.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: controllers setam `_extraHeaders`.
- Risco restante: `/api/complete-lesson` nao cobra aula hoje, entao nao emite saldo.

### K7
- ID: K7
- Prioridade: P1
- Status: BLOQUEADO
- Arquivo(s) alterado(s): `src/credits/credits-store.js`
- O que foi feito: mitigacao em memoria por `operationId`.
- Por que nao fere arquitetura: nao inventa banco/RPC.
- Como evita doenca do Web: nao copia Supabase sem infra.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: teste de idempotencia local.
- Risco restante: race multi-processo exige store transacional.

### K8
- ID: K8
- Prioridade: P2
- Status: IMPLEMENTADO
- Arquivo(s) alterado(s): `src/credits/credits-store.js`
- O que foi feito: logs `[CREDITS]` com before/after/cost/operationId.
- Por que nao fere arquitetura: observabilidade.
- Como evita doenca do Web: nao expõe segredo.
- Teste executado: `npm test`
- Resultado: PASSOU
- Evidencia: logs aparecem na suite.
- Risco restante: dashboard nao criado.

## Itens L - Flutter / Contrato-Fio

### L1
- ID: L1
- Prioridade: P0
- Status: DOCUMENTADO / CONFIRMADO PARCIAL
- Arquivo(s) alterado(s): `docs/SIM_FLUTTER_CONTRATO_FIO.md`
- O que foi feito: contrato documentado; cliente ja repassa payload SSE como `T00BootstrapChunk`.
- Por que nao fere arquitetura: sem mudanca de UI.
- Como evita doenca do Web: telemetria sem copiar Web.
- Teste executado: nao rodado.
- Resultado: NAO PROVADO no Flutter.
- Evidencia: `SimServerT00Client` preserva campos desconhecidos no payload.
- Risco restante: precisa consumidor de telemetria explicito.

### L2
- ID: L2
- Prioridade: P0
- Status: CONFIRMADO PARCIAL / DOCUMENTADO
- Arquivo(s) alterado(s): `docs/SIM_FLUTTER_CONTRATO_FIO.md`
- O que foi feito: contrato documenta campos ricos; cliente ja espalha `request.onboarding`.
- Por que nao fere arquitetura: Flutter envia ficha, servidor decide.
- Como evita doenca do Web: nao coloca pedagogia no app.
- Teste executado: nao rodado.
- Resultado: NAO PROVADO no Flutter.
- Evidencia: `SimServerT00Client` usa `...request.onboarding`.
- Risco restante: onboarding precisa realmente coletar/preencher esses campos.

### L3
- ID: L3
- Prioridade: P0
- Status: DOCUMENTADO
- Arquivo(s) alterado(s): `docs/SIM_FLUTTER_CONTRATO_FIO.md`
- O que foi feito: codigos fatal documentados.
- Por que nao fere arquitetura: contrato cliente.
- Como evita doenca do Web: nao cria fallback falso.
- Teste executado: nao rodado.
- Resultado: NAO PROVADO.
- Evidencia: documento criado.
- Risco restante: handler Flutter precisa UX por code.

### L4
- ID: L4
- Prioridade: P0
- Status: CONFIRMADO / TESTADO INDIRETO
- Arquivo(s) alterado(s): `docs/SIM_FLUTTER_CONTRATO_FIO.md`
- O que foi feito: contrato documentado; Flutter atual ja chama `/api/visual-route` no N3.
- Por que nao fere arquitetura: cascata software antes de pago.
- Como evita doenca do Web: N3 fica no servidor.
- Teste executado: `npm test` no endpoint; Flutter nao rodado.
- Resultado: PARCIAL.
- Evidencia: `SimServerVisualRouterClient` usa `simVisualRoutePath`.
- Risco restante: precisa teste Flutter do fluxo parabola no APK.

### L5
- ID: L5
- Prioridade: P0
- Status: CONFIRMADO PARCIAL / DOCUMENTADO
- Arquivo(s) alterado(s): `docs/SIM_FLUTTER_CONTRATO_FIO.md`
- O que foi feito: contrato exige `lesson_local_id` estavel; T00/T02 enviam `lessonLocalId`.
- Por que nao fere arquitetura: id estavel no cliente.
- Como evita doenca do Web: servidor nao inventa identidade pedagogica.
- Teste executado: nao rodado.
- Resultado: NAO PROVADO no Flutter.
- Evidencia: cliente T00/T02 inclui `lessonLocalId`.
- Risco restante: imagem/audio ainda precisam auditoria de estabilidade de id por retry.

### L6
- ID: L6
- Prioridade: P1
- Status: DOCUMENTADO
- Arquivo(s) alterado(s): `docs/SIM_FLUTTER_CONTRATO_FIO.md`
- O que foi feito: leitura de `X-Credits-Balance` documentada.
- Por que nao fere arquitetura: contrato de header.
- Como evita doenca do Web: evita round-trip extra.
- Teste executado: nao rodado.
- Resultado: NAO PROVADO.
- Evidencia: servidor emite header para midia.
- Risco restante: Flutter ainda precisa atualizar store local.

### L7
- ID: L7
- Prioridade: P1
- Status: DOCUMENTADO
- Arquivo(s) alterado(s): `docs/SIM_FLUTTER_CONTRATO_FIO.md`
- O que foi feito: respeito a `Retry-After` documentado.
- Por que nao fere arquitetura: politica HTTP.
- Como evita doenca do Web: evita 429-loop.
- Teste executado: nao rodado.
- Resultado: NAO PROVADO.
- Evidencia: servidor emite `Retry-After`.
- Risco restante: Flutter ainda precisa implementar retry policy.

## Status Final

B=NAO para Wave 2 inteira.

O que esta entregue e provado:

- imagem: aspect ratio, allow_paid=false, retry 429/5xx, cache/idempotencia, refund, logs, header privado;
- audio: language/voice/speed, cap de texto, cache, rate limit, JSON preservado;
- duvida: MIME/tamanho/contexto/log;
- credito: idempotencia em memoria, logs, X-Credits-Balance em midia;
- contrato Flutter documentado;
- testes do servidor passando.

O que ainda impede B=SIM:

- provider/modelo Web nao foi copiado por decisao de arquitetura;
- nao ha RPC/transacao real de credito multi-processo;
- T02/aula nao cobra lesson credit neste servidor atual;
- Flutter ainda nao implementa/prova UX final para fatal code, X-Credits-Balance e Retry-After;
- APK real nao foi gerado/testado nesta Wave.
