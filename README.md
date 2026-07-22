# SIM-SCROL

Aplicativo Flutter do SIM NV. O app conversa com o servidor oficial SIM API e mantem a experiencia de aula, cache local, fila offline, billing e midia sob os contratos vivos do projeto.

Servidor operacional:

- Repositorio: `/root/sim-work/sim-api`
- Contrato de rotas: `/root/sim-work/sim-api/src/routes/route-definitions.json`
- API operacional atual de teste: `http://167.179.109.137:3000`

## Dependencias

```bash
flutter pub get
```

## Validacao local

```bash
flutter analyze
flutter test
flutter test test/guardas_antigasto_sentinel_test.dart
```

## APK de teste operacional

Este build e apenas operacional/teste externo com servidor HTTP atual. Ele nao e build publicavel na Play Store.

```bash
flutter build apk --profile \
  --dart-define=FLUTTER_APP_MODE=development \
  --dart-define=SIM_DEV_SERVER_URL=http://167.179.109.137:3000 \
  --dart-define=SIM_ALLOW_HTTP_IN_DEVELOPMENT=true \
  -PSIM_REQUIRE_RELEASE_SIGNING=false
```

## Build Play Store/producao

Use o script oficial:

```bash
scripts/build-sim-scroll-production-apk.sh
```

Requisitos: `SIM_SERVER_URL` HTTPS real, assinatura release persistente e configuracao de producao. HTTP operacional nao e permitido para build publicavel.

## Coverage

```bash
bash scripts/coverage.sh
```

O script gera `coverage/lcov.info`. Se `genhtml` existir, tambem gera HTML em `coverage/html`.

## Integration test

```bash
bash scripts/run-integration-tests.sh
```

Esse comando exige emulador/dispositivo conectado. A existencia do teste nao prova execucao em dispositivo real.

## Proveniencia

```bash
bash scripts/create-release-manifest.sh --help
bash scripts/verify-provenance.sh
```

Os scripts registram ou verificam manifestos de release sem gerar APK nesta fase.

## Documentos vivos

- `docs/INDEX.md`
- `docs/CONSTITUICAO_CONTRATOS_SIM.md`
- `docs/AUTORIDADES_CONSTITUCIONAIS_SIM_APP.md`
- `docs/LEI_PROTECAO_TRAVAS_ANTI_LOOP_SIM_NV.md`
- `/root/sim-work/sim-api/docs/LEI_GUARDAS_ANTIGASTO_SIM.md`
- `/root/sim-work/sim-api/docs/INVENTARIO_GUARDAS_ANTIGASTO.md`

## Regras protegidas

Nao tocar, mover, resumir, compactar ou reescrever prompts T00/T02, adendos, contrato N3 ou textos pedagogicos enviados para IA nesta linha de trabalho.

Guardas antigasto sao protegidos por manifest/testes no servidor e por `test/guardas_antigasto_sentinel_test.dart` no app.
