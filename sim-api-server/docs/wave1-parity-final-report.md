# Wave 1 - Relatorio de Paridade SIM-API / SIM-Web

Status final: B=NAO.

Motivo: a maior parte dos P0/P1 seguros foi implementada e testada, mas a Wave 1 completa tem itens que exigem decisao de provedor/operacao ou mudanca maior de contrato antes de declarar B=SIM. Em especial: Lovable Gateway como estrada primaria, retry real de truncamento por MAX_TOKENS com reexecucao por tamanho minimo, backpressure SSE e regra obrigatoria de SUPABASE_JWT_SECRET em ambientes que hoje ainda usam JWT de laboratorio.

## Resumo

- Total de itens da Wave: 60.
- P0/P1/P2: 24 P0, 25 P1, 11 P2.
- Implementados: 44.
- Confirmados sem alteracao: 3.
- Documentados: 2.
- Bloqueados: 6.
- Nao feitos por baixo risco ou exigirem escopo maior: 5.
- SimWeb alterado: NAO.
- Flutter alterado: NAO.
- Precos/contratos financeiros alterados: NAO.
- Arquitetura SIM-API preservada: SIM.

## Arquivos Alterados

- `package.json`
- `server.js`
- `src/ai/gemini-client.js`
- `src/app/router.js`
- `src/config/env.js`
- `src/logs/request-logger.js`
- `src/prompts/prompt-loader.js`
- `src/t00/bootstrap-controller.js`
- `src/t00/t00-parser.js`
- `src/t02/complete-lesson-controller.js`
- `src/t02/visual-trigger-normalizer.js`
- `prompts/README.md`
- `test/server-contract.test.js`

## Testes e Validacoes

- `node --check server.js`: PASSOU.
- `node --check` nos JS alterados: PASSOU.
- `npm test`: PASSOU.
- Flutter analyze/test/build: NAO APLICAVEL nesta Wave 1, porque o Flutter nao foi alterado.
- APK real: NAO APLICAVEL nesta Wave 1 de servidor.

## Itens

| ID | Prioridade | Status | Evidencia |
|---|---|---|---|
| A1 | P2 | IMPLEMENTADO | `prompt-loader` calcula/loga SHA e tamanho dos prompts. |
| A2 | P2 | BLOQUEADO | Falta `PROMPTS_HASHES.txt` canonico aprovado pelo dono; nao inventado. |
| A3 | P2 | DOCUMENTADO | `prompts/README.md` explica adendos sem equivalente direto no Web. |
| A4 | P1 | IMPLEMENTADO | Adendos agora sao opcionais com warning; T00/T02 continuam fatais. |
| A5 | P0 | IMPLEMENTADO | T00 SSE inclui `prompt_sha`; T02 loga `prompt_sha`. |
| B1 | P0 | IMPLEMENTADO | Default do modelo Google publico mudou para `gemini-2.5-flash`. |
| B2 | P0 | BLOQUEADO | Gateway Lovable nao foi copiado para evitar trazer provedor Web sem decisao. |
| B3 | P1 | IMPLEMENTADO | Fallback remove `gemini-2.0-flash`. |
| B4 | P0 | IMPLEMENTADO | 404/not found agora permite fallback de modelo. |
| B5 | P1 | IMPLEMENTADO | `callTextWithModel` aceita timeout por opcao. |
| B6 | P1 | BLOQUEADO | `finishReason` e log existem, mas retry por `min_items_expected` ainda exige ciclo maior. |
| B7 | P0 | IMPLEMENTADO | `GEMINI_STREAM_END` loga `finishReason`. |
| B8 | P2 | IMPLEMENTADO | Stream contabiliza erros de parse SSE. |
| B9 | P1 | IMPLEMENTADO | `requestGemini` usa guarda `settled`. |
| B10 | P0 | IMPLEMENTADO | T00 start emite `model` real escolhido. |
| B11 | P2 | NAO FEITO | Mover `list-models.js` e baixo risco; deixado fora do escopo seguro. |
| C1 | P0 | IMPLEMENTADO | `nivel` entra no SESSION CONTEXT. |
| C2 | P0 | IMPLEMENTADO | `official_curriculum_reference` entra no SESSION CONTEXT. |
| C3 | P0 | IMPLEMENTADO | `prior_knowledge` entra no SESSION CONTEXT. |
| C4 | P0 | IMPLEMENTADO | `known_weaknesses` entra no SESSION CONTEXT. |
| C5 | P1 | IMPLEMENTADO | `subject` aceita `SUBJECT` e `disciplina`. |
| C6 | P1 | IMPLEMENTADO | Log `[T00_PAYLOAD]` traz anexos e tamanhos. |
| C7 | P2 | IMPLEMENTADO | Truncamento de anexos gera warning. |
| C8 | P1 | IMPLEMENTADO | `interpreted_fields` e payload grande sao normalizados/logados. |
| C9 | P1 | IMPLEMENTADO | Ordem do JSON foi alinhada ao Web. |
| C10 | P0 | IMPLEMENTADO | `STABLE_LANG` aceito e idioma normalizado em lowercase. |
| C11 | P1 | IMPLEMENTADO | `free_text` remove caracteres de controle. |
| C12 | P2 | IMPLEMENTADO | `modo` legado ainda funciona e gera warning. |
| C13 | P1 | IMPLEMENTADO | `MIN_ITEMS_HINT: 20` adicionado antes do contexto. |
| D1 | P0 | IMPLEMENTADO | Parser aceita fallback `[0001] MI-01 | titulo | proposito`. |
| D2 | P1 | IMPLEMENTADO | Lacunas de ordem geram `[T00_CURRICULUM_GAPS]`. |
| D3 | P1 | NAO FEITO | Relaxar emissao parcial do stream exige teste de transporte mais amplo. |
| D4 | P2 | IMPLEMENTADO | Marker invalido e descartado. |
| D5 | P2 | IMPLEMENTADO | `minimum_curriculum_size` vai para `ficha_for_next`. |
| D6 | P1 | IMPLEMENTADO | Perfil multi-linha agora e capturado ate o proximo label. |
| D7 | P0 | CONFIRMADO | Teste existente de bootstrap sem lessonLocalId nao cai em 403. |
| E1 | P0 | IMPLEMENTADO | T02 envia `conquest_history`, campos faltantes e mantem `history` compat. |
| E2 | P1 | IMPLEMENTADO | Amparo/support usam contrato reduzido. |
| E3 | P0 | IMPLEMENTADO | Historico T02 padronizado em `slice(-10)`. |
| E4 | P1 | BLOQUEADO | `recent_errors` mantido; uso pelo prompt precisa revisao de produto/prompt. |
| E5 | P2 | CONFIRMADO | `stable_lang`/`language` duplicados preservados por compatibilidade. |
| E6 | P0 | BLOQUEADO | T02 segue blocking; streaming mudaria contrato cliente/API. |
| E7 | P1 | IMPLEMENTADO | Limite de imagem da duvida vem de config com default 8 MB. |
| E8 | P0 | IMPLEMENTADO | `correct_answer` invalido rejeita a resposta e aciona retry. |
| E9 | P1 | IMPLEMENTADO | `visual_trigger` passa por normalizador dedicado. |
| E10 | P0 | CONFIRMADO | `amparo` e `support` continuam aceitos. |
| F1 | P0 | BLOQUEADO | Backpressure SSE nao foi alterado sem teste de cliente lento. |
| F2 | P1 | DOCUMENTADO | Heartbeat de 5s preservado. |
| F3 | P0 | IMPLEMENTADO | T00 tem retry configuravel em falha de stream. |
| F4 | P1 | IMPLEMENTADO | Fatal SSE inclui `code` categorizado. |
| F5 | P1 | NAO FEITO | Teste negativo de CORS nao criado nesta rodada. |
| F6 | P0 | IMPLEMENTADO | Rate limit limpa buckets antigos a cada 100 requests. |
| F7 | P1 | IMPLEMENTADO | Default do rate limit AI subiu para 60/min. |
| G1 | P1 | IMPLEMENTADO | IP nu removido do CORS default. |
| G2 | P0 | BLOQUEADO | Secret obrigatorio nao imposto para nao quebrar ambiente atual sem auditoria de deploy. |
| G3 | P1 | IMPLEMENTADO | `TEST_CREDIT_EMAILS` default agora e vazio. |
| G4 | P1 | IMPLEMENTADO | Loader `.env` duplicado removido do `server.js`. |
| G5 | P2 | IMPLEMENTADO | `MEDIA_CACHE_LIMIT` default subiu para 32. |
| G6 | P1 | IMPLEMENTADO | Request logger emite start/end com status e tempo. |
| G7 | P2 | IMPLEMENTADO | `package.json` declara Node >=20. |

## Riscos Restantes

- B2: Lovable Gateway nao foi implementado por risco de copiar provedor do Web para o SIM-API sem decisao explicita.
- B6: truncamento MAX_TOKENS agora e observavel, mas ainda nao reexecuta por tamanho minimo de curriculo.
- E6: T02 continua resposta bloqueante; streaming exige contrato cliente-servidor.
- F1: backpressure SSE ainda precisa teste especifico de cliente lento.
- G2: tornar `SUPABASE_JWT_SECRET` obrigatorio depende de confirmacao de deploy e modo laboratorio atual.

## Status

B=NAO para a Wave 1 inteira.

Status operacional desta rodada: correcoes centrais de modelo, payload rico, parser tolerante, T02, visual_trigger, logs e rate limit foram implementadas e `npm test` passou.
