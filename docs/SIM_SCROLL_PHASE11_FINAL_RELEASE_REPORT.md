# DOCUMENTO HISTORICO. NAO E AUTORIDADE DE RUNTIME OU PUBLICACAO.

Este relatorio registra um APK antigo de continuidade/teste. Para publicacao
Google Play, a autoridade vigente e `docs/GOOGLE_PLAY_RELEASE_READINESS.md` com
package `com.aulasonline.sim`, HTTPS obrigatorio e release signing oficial.

# SIM Scroll - Fase 11 - Relatorio final de release

Data: 2026-07-03

## Decisao principal

A Fase 11 foi executada como limpeza final segura, sem remover `AulaLabScreen` e sem remover os widgets reutilizaveis antigos.

Motivo: a propria planta construtiva define:

- "limpeza somente depois de B";
- "remover cards antigos apenas se aprovado";
- "Nao apagar antes da prova";
- "So remover tela antiga depois de duas versoes release funcionando no celular real";
- "O antigo layout deve existir ate o chat provar superioridade funcional".

Portanto, a tela chat ja esta ativa por default, mas a tela antiga continua no codigo como rollback tecnico.

## Estado da migracao

- `SIM_SCROLL_AULA_CHAT` esta ligado por default.
- A rota real `/cyber/aula` abre `ChatAulaScreen` por default.
- `AulaLabScreen` continua disponivel no codigo.
- Rollback continua possivel via `--dart-define=SIM_SCROLL_AULA_CHAT=false`.
- T00 nao foi alterado.
- T02 nao foi alterado.
- `StudentLearningState` nao foi alterado.
- API/servidor nao foi alterado.
- SimWeb nao foi alterado.

## Identidade Android

O APK continua usando o mesmo `applicationId` do SIM original local:

`com.example.sim_mobile`

O `versionCode` foi atualizado de `3` para `4` em `pubspec.yaml`:

`version: 1.0.0+4`

Isso permite que o Android trate o APK como atualizacao da versao anterior instalada, desde que a assinatura seja a mesma.

## Rollback

Se o chat falhar em teste manual no celular real, gerar uma build com:

`--dart-define=SIM_SCROLL_AULA_CHAT=false`

Esse rollback volta a rota `/cyber/aula` para `AulaLabScreen`, sem alterar T00/T02, estado, imagem, audio, creditos, backup ou sync.

## Provas obrigatorias

Comandos esperados para esta fase:

- `flutter analyze`
- `flutter test`
- `scripts/build-sim-scroll-production-apk.sh`

## Correcao de servidor da build

O APK `1.0.0+3` foi gerado sem `SIM_SERVER_URL`, portanto usou o default do codigo:

`https://gemini-aid-pal.lovable.app`

Esse dominio serve tambem a aplicacao Web/Lovable. A rota `/api/bootstrap-t00` desse dominio recusou o Bearer enviado pelo app com:

`HTTP 401 {"error":"Unauthorized","reason":"invalid token"}`

Isso indica token presente, mas nao aceito pela rota publica chamada.

A build correta do Scroll deve apontar explicitamente para o servidor SIM/API:

`http://167.179.109.137:3000`

Como esse servidor ainda esta em HTTP, a build de teste usa tambem:

`SIM_ALLOW_HTTP_IN_PRODUCTION=true`

Script canonico:

`scripts/build-sim-scroll-production-apk.sh`

## Resultado

Comandos executados:

- `flutter analyze` — PASSOU
- `flutter test` — PASSOU, 290 testes
- `scripts/build-sim-scroll-production-apk.sh` — PASSOU

APK gerado:

- Arquivo local: `build/app/outputs/flutter-apk/app-release.apk`
- Arquivo publicado: `sim-production-latest.apk`
- Link publico: `http://167.179.109.137:3000/downloads/sim-production-latest.apk`
- SHA256: `b8a633d7ffe37139a19d229a02b4c84793605cab56d18bc8461b48a197a5f712`
- Tamanho: `65,653,692 bytes`

Identidade conferida via `aapt`:

- `packageName`: `com.example.sim_mobile`
- `versionCode`: `4`
- `versionName`: `1.0.0`

Servidor conferido no binario do APK:

- `SIM_SERVER_URL`: `http://167.179.109.137:3000`
- T00: `/api/bootstrap-t00`

Assinatura conferida via `apksigner`:

- Signer SHA-256: `4fde4acf28c19c0cb71c62e3cbab7ebf2f4fd7b3f14b4f68d3ec21e44eba0f0b`

Observacao importante:

O Android so reconhece este APK como atualizacao se o app instalado no telefone tiver o mesmo `applicationId` e tiver sido assinado pela mesma chave. O pacote e `com.example.sim_mobile`; a assinatura gerada nesta build e a assinatura debug Android usada pela configuracao atual do projeto.
