# Contrato Sync, Offline E Cache

Este contrato governa sincronizacao, cache local e fila offline do app SIM.

## Autoridade

- O estado local rico do aluno e a trilha de eventos canonicos sao a autoridade operacional imediata do app.
- Remoto e cache sao fontes auxiliares. Eles nao podem apagar progresso, eventos, material pronto valido ou identificadores locais mais fortes.
- Rejeicao remota nao autoriza `acceptServerAuthority: true`. O app deve reconciliar por contrato local e re-enfileirar quando houver conflito.
- Cache de aula nunca altera progresso, rota, creditos, billing ou decisao de avanco.

## Merge

- Merge remoto usa regra anti-regressao e preserva o estado local quando ele e mais rico.
- Pontuacao remota maior nao e verdade absoluta: material local, curriculo completo, eventos e marcador coerente continuam protegidos.
- Estado remoto corrompido, vazio ou incompleto deve falhar fechado ou ser tratado como fonte auxiliar.

## Cache

- Aula so pode entrar como pronta se houver material real: explicacao, pergunta e opcoes A/B/C nao vazias.
- `localFallback` e cache frio sao indice de continuidade, nao prova de aula pronta.
- Cache hit deve casar com `lessonLocalId`, chave local da aula e metadados de item/marcador.
- Midia antiga nao pode ser reaproveitada quando marcador, camada ou aula local nao batem.

## Retencao E Autolimpeza

- Limpeza por aula remove estado local, eventos canonicos, material de aula, indices frios e item relacionado da fila offline.
- Entrada expirada deve ser removida de fato. Ela nao pode apenas virar `cold`.
- LRU pode remover midia pesada antes de texto, mas nao pode remover a aula ativa primeiro.

## Fila Offline

- A fila deve ser persistente no storage local de producao.
- Cada item tem id estavel, operacao, tentativa, proxima execucao, status e ultimo codigo seguro de falha.
- Hash de idempotencia deve usar JSON canonico com chaves ordenadas, nunca `json.toString()`.
- Ao exceder tentativas, o item entra em estado bloqueado seguro e nao agenda loop infinito.

## Falha E Corrupcao

- JSON corrompido da fila ou indice de hash e erro auditavel. Nao pode virar fila vazia silenciosamente.
- Falha de persistencia local deve gerar codigo seguro como `SYNC_LOCAL_PERSIST_FAILED`.
- Erro salvo em estado/sync deve ser codigo publico, como `SYNC_REMOTE_UNAVAILABLE`, sem `error.toString()`.

## Logs E Debug

Campos proibidos em logs, eventos e `debugSnapshot` comum:

- tokens, URLs assinadas, headers e payloads de rede;
- stack trace e mensagem bruta de excecao;
- prompt, corpo de provedor ou resposta bruta;
- `lessonLocalId` em snapshot debug comum de fila;
- conteudo integral de aula, anexos e dados pessoais.

Snapshots debug devem expor apenas id redigido, operacao, tentativas, status, proxima execucao e codigo seguro de falha.
