# Fase 13 - Owner Check

## Implementado agora

O servidor valida JWT antes de qualquer endpoint protegido e usa `token.sub` como a unica identidade confiavel.

O servidor nao aceita `user_id`, `userId`, `owner_id`, `ownerId`, `student_user_id` ou metadata de usuario como verdade. Se esses campos aparecem no body e divergem de `token.sub`, a API retorna `403 Forbidden`.

Foi adicionado um registro persistido local em:

```text
/root/sim-work/sim-api/.data/resource-owners.json
```

Esse registro guarda ownership por:

- `lessons`
- `media`
- `attachments`
- `doubts`
- `credits`
- `snapshots`

Quando um recurso novo e criado, o owner gravado e sempre `token.sub`.

Quando um recurso existente e acessado, o owner salvo precisa bater com `token.sub`; caso contrario, a API retorna `403 Forbidden`.

## Endpoints com owner check real no estado do servidor

- `POST /api/bootstrap-t00`
  - registra/valida owner de `lessonLocalId` quando existir no payload.

- `POST /api/complete-lesson`
  - registra/valida owner de `lessonLocalId`, `lesson_local_id`, `lessonKey`, `lesson_id` ou `cacheKey`.

- `POST /api/doubt`
  - registra/valida owner da aula.
  - registra/valida owner da duvida usando `doubtId`, `requestId` ou hash da duvida.

- `POST /api/review`
  - registra/valida owner da aula.

- `POST /api/recovery`
  - registra/valida owner da aula.

- `POST /api/generate-lesson-image`
  - registra/valida owner da aula.
  - registra/valida owner da midia por cacheKey de imagem.

- `POST /api/generate-lesson-audio`
  - registra/valida owner da aula.
  - registra/valida owner da midia por cacheKey de audio.

- `POST /api/process-attachment`
  - registra/valida owner da aula quando `x-lesson-local-id` ou `x-lesson-id` e enviado.
  - registra/valida owner do anexo por `x-attachment-id` ou hash tecnico do arquivo.

- Creditos em modo laboratorio
  - o ledger em memoria usa sempre `auth.userId`.
  - o owner da conta de credito e registrado como `token.sub`.

## Endpoints publicos

- `GET /api/health`
  - publico, sem JWT.
  - ainda passa por rate limit leve por IP.

## Ainda nao implementado como banco Supabase

Este `sim-api` ainda nao tem `SUPABASE_SERVICE_ROLE`, client Supabase administrativo, nem schema/tabelas de ownership configurados no servidor.

Portanto, o owner check de recursos do servidor e real e persistido no estado local do servidor, mas ainda nao consulta uma tabela Supabase definitiva.

Para virar owner check 100% banco, falta adicionar no servidor:

- Supabase service client somente no backend;
- tabelas/policies para `student_states`, aulas, anexos, midias, creditos e transacoes;
- leitura do recurso por id antes de permitir acesso;
- gravacao do owner em banco no momento de criacao;
- bloqueio por RLS e tambem por validacao server-side.

## Garantias atuais

- Nenhum segredo foi colocado no Flutter.
- Nenhum JWT secret foi colocado no Flutter.
- O servidor nao grava token completo em log.
- O servidor nao usa `user_id` vindo do client como verdade.
- Requisicoes sem JWT para endpoints protegidos retornam `401`.
- Requisicoes com JWT invalido retornam `401`.
- Requisicoes com resource owner divergente retornam `403`.

