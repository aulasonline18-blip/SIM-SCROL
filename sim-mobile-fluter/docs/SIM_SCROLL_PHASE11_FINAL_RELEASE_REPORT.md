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

O `versionCode` foi atualizado de `2` para `3` em `pubspec.yaml`:

`version: 1.0.0+3`

Isso permite que o Android trate o APK como atualizacao da versao anterior instalada, desde que a assinatura seja a mesma.

## Rollback

Se o chat falhar em teste manual no celular real, gerar uma build com:

`--dart-define=SIM_SCROLL_AULA_CHAT=false`

Esse rollback volta a rota `/cyber/aula` para `AulaLabScreen`, sem alterar T00/T02, estado, imagem, audio, creditos, backup ou sync.

## Provas obrigatorias

Comandos esperados para esta fase:

- `flutter analyze`
- `flutter test`
- `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production`

## Resultado

Comandos executados:

- `flutter analyze` — PASSOU
- `flutter test` — PASSOU, 290 testes
- `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production` — PASSOU

APK gerado:

- Arquivo local: `build/app/outputs/flutter-apk/app-release.apk`
- Arquivo publicado: `sim-production-latest.apk`
- Link publico: `http://167.179.109.137:3000/downloads/sim-production-latest.apk`
- SHA256: `7d351c195a94576676850db6a2ef4b5e43a68b28b73c5862d813f2009cc461f8`
- Tamanho: `65,653,692 bytes`

Identidade conferida via `aapt`:

- `packageName`: `com.example.sim_mobile`
- `versionCode`: `3`
- `versionName`: `1.0.0`

Assinatura conferida via `apksigner`:

- Signer SHA-256: `4fde4acf28c19c0cb71c62e3cbab7ebf2f4fd7b3f14b4f68d3ec21e44eba0f0b`

Observacao importante:

O Android so reconhece este APK como atualizacao se o app instalado no telefone tiver o mesmo `applicationId` e tiver sido assinado pela mesma chave. O pacote e `com.example.sim_mobile`; a assinatura gerada nesta build e a assinatura debug Android usada pela configuracao atual do projeto.
