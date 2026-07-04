# Checklist Google Play — SIM-SCROL

Base oficial consultada em 04/07/2026:

1. Google Play Data Safety: https://support.google.com/googleplay/android-developer/answer/10787469
2. Google Play account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
3. Target API level: https://developer.android.com/google/play/requirements/target-sdk
4. Google Play Developer Policy Center: https://play.google/developer-content-policy/

## Gates obrigatorios antes de publicar

| Gate | Status | Prova |
|---|---|---|
| Package id real configuravel | FEITO | `SIM_ANDROID_APPLICATION_ID` no Gradle |
| Assinatura release configuravel | FEITO | `android/key.properties` ou `SIM_ANDROID_*` |
| Falhar se assinatura Play faltar | FEITO | `SIM_REQUIRE_RELEASE_SIGNING=true` |
| Cleartext off no manifest main | FEITO | main manifest sem `usesCleartextTraffic=true` |
| Privacy policy publica | PARCIAL | Documento criado; falta publicar URL final |
| Account deletion publica | PARCIAL | Documento criado; falta publicar URL final |
| Delete account in-app | PARCIAL | App chama endpoint; servidor precisa executar exclusao real |
| Auth gate para conta/creditos | FEITO | Guard no roteador central |
| Role gate para `/pai` | PARCIAL | App exige role em metadata/claim; servidor precisa emitir role |
| Observabilidade | PARCIAL | ErrorWidget/FlutterError existem; falta Sentry/Crashlytics real |
| Billing Play | BLOQUEADO | Requer decisao e configuracao Google Play Billing |
| API level 35+ | A VERIFICAR | Depende do Flutter/Android Gradle instalado no build |

## Comando Play release esperado

Use HTTPS e assinatura release:

```bash
flutter build appbundle --release \
  --dart-define=FLUTTER_APP_MODE=production \
  --dart-define=SIM_SERVER_URL=https://SEU-DOMINIO-API \
  --dart-define=SIM_CHECKOUT_RETURN_ORIGIN=https://SEU-DOMINIO-APP \
  -PSIM_ANDROID_APPLICATION_ID=com.aulasonline.sim \
  -PSIM_REQUIRE_RELEASE_SIGNING=true
```

## O que nao fazer

1. Nao publicar build Play apontando para HTTP.
2. Nao publicar build Play com `com.example.sim_mobile`.
3. Nao publicar build Play assinado com debug.
4. Nao publicar pagamentos Stripe para bens digitais consumidos no Android sem decisao legal/politica.
5. Nao declarar exclusao real se o servidor apenas registra solicitacao.
